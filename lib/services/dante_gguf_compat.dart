import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Il GGUF di Dante dichiara il pre-tokenizer `dante-bpe`, che esiste solo
/// nella build patchata usata per convertirlo. llama.cpp sul telefono non lo
/// conosce e rifiuta il file anche se i byte ci sono tutti.
///
/// Si riscrive solo l'intestazione: il pre-tokenizer diventa `gemma4` (stessa
/// forma SPM, spazi come ▁, niente byte-encode) e i due header di ruolo
/// tornano token normali, perché nel training non sono speciali se incollati
/// alla parola che segue. I pesi non si spostano.
class DanteGgufCompat {
  static const _preFrom = 'dante-bpe';
  static const _preTo = 'gemma4';
  static const _headerStart = '<|start_header|>';
  static const _headerEnd = '<|end_header|>';
  static const _templateNeedle = "'<|start_header|>system";
  static const _templateReplacement = "' <|start_header|>system";

  /// True se il file è stato modificato.
  static Future<bool> ensureLoadable(String path) async {
    final prefix = await _readPrefix(File(path));
    final rebuilt = _rebuild(prefix);
    if (rebuilt == null) return false;
    await _overwriteStart(path, rebuilt);
    return true;
  }

  static Future<_Prefix> _readPrefix(File file) async {
    final raf = await file.open();
    try {
      final header = await raf.read(24);
      if (header.length < 24) throw StateError('GGUF troncato');
      final data = ByteData.sublistView(header);
      if (data.getUint32(0, Endian.little) != 0x46554747) {
        throw StateError('Non è un GGUF');
      }
      if (data.getUint32(4, Endian.little) < 2) {
        throw StateError('Versione GGUF non supportata');
      }
      final nTensors = data.getUint64(8, Endian.little);
      final nKv = data.getUint64(16, Endian.little);
      final reader = _Reader(raf, 24);
      var alignment = 32;
      for (var i = 0; i < nKv; i++) {
        final key = await reader.readString();
        final type = await reader.u32();
        if (key == 'general.alignment' && type == 4) {
          alignment = await reader.u32();
          continue;
        }
        await reader.skipValue(type);
      }
      for (var i = 0; i < nTensors; i++) {
        await reader.readString();
        final nDims = await reader.u32();
        await reader.skip(8 * nDims);
        await reader.skip(4);
        await reader.u64();
      }
      final infoEnd = await raf.position();
      final dataOffset = _alignUp(infoEnd, alignment);
      final bytes = Uint8List(dataOffset);
      await raf.setPosition(0);
      var filled = 0;
      while (filled < dataOffset) {
        final chunk = await raf.read(dataOffset - filled);
        if (chunk.isEmpty) throw StateError('GGUF più corto del previsto');
        bytes.setRange(filled, filled + chunk.length, chunk);
        filled += chunk.length;
      }
      return _Prefix(bytes, infoEnd, dataOffset, alignment);
    } finally {
      await raf.close();
    }
  }

  static Uint8List? _rebuild(_Prefix prefix) {
    final src = prefix.bytes;
    final reader = _Mem(src);
    reader.skip(4);
    reader.u32();
    reader.u64();
    final nKv = reader.u64();
    final out = BytesBuilder(copy: false);
    out.add(src.sublist(0, 24));

    final headerIds = _headerTokenIds(src);
    final headerStartId = headerIds.$1;
    final headerEndId = headerIds.$2;
    var changed = false;

    for (var i = 0; i < nKv; i++) {
      final keyStart = reader.pos;
      final key = reader.string();
      final type = reader.u32();
      final valueStart = reader.pos;

      if (key == 'tokenizer.ggml.pre' && type == 8) {
        final value = reader.string();
        final next = value == _preFrom ? _preTo : value;
        if (next != value) changed = true;
        out.add(src.sublist(keyStart, valueStart));
        _writeString(out, next);
        continue;
      }

      if (key == 'tokenizer.ggml.tokens' && type == 9) {
        final elem = reader.u32();
        final count = reader.u64();
        reader.skipArrayBody(elem, count);
        out.add(src.sublist(keyStart, reader.pos));
        continue;
      }

      if (key == 'tokenizer.ggml.token_type' && type == 9) {
        final elem = reader.u32();
        final count = reader.u64();
        if (elem == 5) {
          final raw = reader.bytes(count * 4);
          final patched = Uint8List.fromList(raw);
          final view = ByteData.sublistView(patched);
          for (final id in [headerStartId, headerEndId]) {
            if (id == null || id < 0 || id >= count) continue;
            if (view.getInt32(id * 4, Endian.little) == 3) {
              view.setInt32(id * 4, 1, Endian.little);
              changed = true;
            }
          }
          out.add(src.sublist(keyStart, valueStart + 4 + 8));
          out.add(patched);
          continue;
        }
        reader.skipArrayBody(elem, count);
        out.add(src.sublist(keyStart, reader.pos));
        continue;
      }

      if (key == 'tokenizer.chat_template' && type == 8) {
        final value = reader.string();
        final next = value.contains(_templateReplacement) || !value.contains(_templateNeedle)
            ? value
            : value.replaceFirst(_templateNeedle, _templateReplacement);
        if (next != value) changed = true;
        out.add(src.sublist(keyStart, valueStart));
        _writeString(out, next);
        continue;
      }

      reader.skipValue(type);
      out.add(src.sublist(keyStart, reader.pos));
    }

    if (reader.pos > prefix.infoEnd) {
      throw StateError('Intestazione GGUF letta in modo incompleto');
    }
    out.add(src.sublist(reader.pos, prefix.infoEnd));
    if (!changed) return null;

    final built = out.toBytes();
    if (_alignUp(built.length, prefix.alignment) != prefix.dataOffset) {
      throw StateError('La correzione sposterebbe i pesi del GGUF');
    }
    final padded = Uint8List(prefix.dataOffset);
    padded.setRange(0, built.length, built);
    return padded;
  }

  static int _alignUp(int value, int alignment) {
    final mask = alignment - 1;
    return (value + mask) & ~mask;
  }

  static (int?, int?) _headerTokenIds(Uint8List src) {
    final reader = _Mem(src);
    reader.skip(4);
    reader.u32();
    reader.u64();
    final nKv = reader.u64();
    int? startId;
    int? endId;
    for (var i = 0; i < nKv; i++) {
      final key = reader.string();
      final type = reader.u32();
      if (key == 'tokenizer.ggml.tokens' && type == 9) {
        final elem = reader.u32();
        final count = reader.u64();
        if (elem == 8) {
          for (var t = 0; t < count; t++) {
            final token = reader.string();
            if (token == _headerStart) startId = t;
            if (token == _headerEnd) endId = t;
          }
        } else {
          reader.skipArrayBody(elem, count);
        }
        continue;
      }
      reader.skipValue(type);
    }
    return (startId, endId);
  }

  static void _writeString(BytesBuilder out, String value) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    final len = ByteData(8)..setUint64(0, bytes.length, Endian.little);
    out.add(len.buffer.asUint8List());
    out.add(bytes);
  }
}

class _Prefix {
  final Uint8List bytes;
  final int infoEnd;
  final int dataOffset;
  final int alignment;
  const _Prefix(this.bytes, this.infoEnd, this.dataOffset, this.alignment);
}

class _Mem {
  final Uint8List src;
  final ByteData view;
  int pos = 0;
  _Mem(this.src) : view = ByteData.sublistView(src);

  int u32() {
    final v = view.getUint32(pos, Endian.little);
    pos += 4;
    return v;
  }

  int u64() {
    final v = view.getUint64(pos, Endian.little);
    pos += 8;
    return v;
  }

  void skip(int n) => pos += n;

  Uint8List bytes(int n) {
    final out = Uint8List.sublistView(src, pos, pos + n);
    pos += n;
    return out;
  }

  String string() {
    final n = u64();
    return String.fromCharCodes(bytes(n));
  }

  void skipArrayBody(int elem, int count) {
    const sizes = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8};
    if (elem == 8) {
      for (var i = 0; i < count; i++) {
        string();
      }
      return;
    }
    final size = sizes[elem];
    if (size == null) throw StateError('Array GGUF non supportato');
    skip(size * count);
  }

  void skipValue(int type) {
    const sizes = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8};
    if (type == 8) {
      string();
      return;
    }
    if (type == 9) {
      final elem = u32();
      final count = u64();
      skipArrayBody(elem, count);
      return;
    }
    final size = sizes[type];
    if (size == null) throw StateError('Tipo GGUF non supportato');
    skip(size);
  }
}

class _Reader {
  final RandomAccessFile raf;
  int pos;
  _Reader(this.raf, this.pos);

  Future<Uint8List> _read(int n) async {
    await raf.setPosition(pos);
    final chunk = await raf.read(n);
    if (chunk.length != n) throw StateError('GGUF troncato');
    pos += n;
    return chunk;
  }

  Future<int> u32() async {
    final b = await _read(4);
    return ByteData.sublistView(b).getUint32(0, Endian.little);
  }

  Future<int> u64() async {
    final b = await _read(8);
    return ByteData.sublistView(b).getUint64(0, Endian.little);
  }

  Future<void> skip(int n) async {
    pos += n;
    await raf.setPosition(pos);
  }

  Future<String> readString() async {
    final n = await u64();
    return String.fromCharCodes(await _read(n));
  }

  Future<void> skipValue(int type) async {
    const sizes = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8};
    if (type == 8) {
      await readString();
      return;
    }
    if (type == 9) {
      final elem = await u32();
      final count = await u64();
      if (elem == 8) {
        for (var i = 0; i < count; i++) {
          await readString();
        }
        return;
      }
      final size = sizes[elem];
      if (size == null) throw StateError('Array GGUF non supportato');
      await skip(size * count);
      return;
    }
    final size = sizes[type];
    if (size == null) throw StateError('Tipo GGUF non supportato');
    await skip(size);
  }
}

Future<void> _overwriteStart(String path, Uint8List bytes) async {
  if (Platform.isWindows) {
    await _overwriteWindows(path, bytes);
    return;
  }
  await _overwritePosix(path, bytes);
}

Future<void> _overwriteWindows(String path, Uint8List bytes) async {
  final kernel = DynamicLibrary.open('kernel32.dll');
  final createFile = kernel.lookupFunction<
      IntPtr Function(Pointer<Utf16> name, Uint32 access, Uint32 share, Pointer<Void> sec, Uint32 disp, Uint32 flags, IntPtr template),
      int Function(Pointer<Utf16> name, int access, int share, Pointer<Void> sec, int disp, int flags, int template)>('CreateFileW');
  final writeFile = kernel.lookupFunction<
      Int32 Function(IntPtr handle, Pointer<Uint8> buf, Uint32 n, Pointer<Uint32> written, Pointer<Void> overlapped),
      int Function(int handle, Pointer<Uint8> buf, int n, Pointer<Uint32> written, Pointer<Void> overlapped)>('WriteFile');
  final setPointer = kernel.lookupFunction<
      Int32 Function(IntPtr handle, Int64 distance, Pointer<Int64> newPos, Uint32 method),
      int Function(int handle, int distance, Pointer<Int64> newPos, int method)>('SetFilePointerEx');
  final closeHandle = kernel.lookupFunction<Int32 Function(IntPtr handle), int Function(int handle)>('CloseHandle');

  final name = path.toNativeUtf16();
  final handle = createFile(name, 0x40000000, 1, nullptr, 3, 0x80, 0);
  calloc.free(name);
  if (handle == -1 || handle == 0) {
    throw StateError('Impossibile aprire il GGUF per la correzione');
  }
  try {
    if (setPointer(handle, 0, nullptr, 0) == 0) {
      throw StateError('Impossibile posizionarsi nel GGUF');
    }
    final buf = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      final ok = writeFile(handle, buf, bytes.length, written, nullptr);
      if (ok == 0 || written.value != bytes.length) {
        throw StateError('Scrittura intestazione GGUF incompleta');
      }
    } finally {
      calloc.free(buf);
      calloc.free(written);
    }
  } finally {
    closeHandle(handle);
  }
}

DynamicLibrary _openLibc() {
  for (final name in ['libc.so', 'libc.so.6']) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {}
  }
  return DynamicLibrary.process();
}

int Function(int fd, Pointer<Uint8> buf, int n, int offset) _lookupPwrite(DynamicLibrary libc) {
  for (final name in ['pwrite', 'pwrite64']) {
    try {
      return libc.lookupFunction<
          IntPtr Function(Int32 fd, Pointer<Uint8> buf, IntPtr n, Int64 offset),
          int Function(int fd, Pointer<Uint8> buf, int n, int offset)>(name);
    } catch (_) {}
  }
  throw StateError('pwrite non disponibile');
}

Future<void> _overwritePosix(String path, Uint8List bytes) async {
  final libc = _openLibc();
  final openFd = libc.lookupFunction<Int32 Function(Pointer<Utf8> path, Int32 flags), int Function(Pointer<Utf8> path, int flags)>('open');
  final pwrite = _lookupPwrite(libc);
  final closeFd = libc.lookupFunction<Int32 Function(Int32 fd), int Function(int fd)>('close');

  final cPath = path.toNativeUtf8();
  final fd = openFd(cPath, 2);
  calloc.free(cPath);
  if (fd < 0) throw StateError('Impossibile aprire il GGUF per la correzione');
  try {
    final buf = calloc<Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var done = 0;
      while (done < bytes.length) {
        final n = pwrite(fd, buf + done, bytes.length - done, done);
        if (n < 0) throw StateError('Scrittura intestazione GGUF fallita');
        done += n;
      }
    } finally {
      calloc.free(buf);
    }
  } finally {
    closeFd(fd);
  }
}
