import 'dart:io';
import 'dart:typed_data';

import 'package:airplane_ai/services/dante_gguf_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('riscrive dante-bpe in gemma4 senza spostare i pesi', () async {
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}dante-compat-test.gguf');
    final weights = Uint8List.fromList(List<int>.generate(16, (i) => 0xA0 + i));
    await file.writeAsBytes(_sample(weights));

    final changed = await DanteGgufCompat.ensureLoadable(file.path);
    expect(changed, isTrue);

    final after = await file.readAsBytes();
    expect(after.length, _sample(weights).length);
    expect(after.sublist(after.length - 16), weights);
    expect(String.fromCharCodes(after), contains('gemma4'));
    expect(String.fromCharCodes(after), isNot(contains('dante-bpe')));
    expect(String.fromCharCodes(after), contains("' <|start_header|>system"));

    final again = await DanteGgufCompat.ensureLoadable(file.path);
    expect(again, isFalse);
    expect(await file.readAsBytes(), after);
    await file.delete();
  });
}

Uint8List _sample(Uint8List weights) {
  final out = BytesBuilder();
  void u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void u64(int v) {
    final b = ByteData(8)..setUint64(0, v, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  void str(String s) {
    final bytes = s.codeUnits;
    u64(bytes.length);
    out.add(bytes);
  }

  void key(String name, int type) {
    str(name);
    u32(type);
  }

  u32(0x46554747);
  u32(3);
  u64(1);
  u64(5);

  key('general.alignment', 4);
  u32(32);

  key('tokenizer.ggml.pre', 8);
  str('dante-bpe');

  key('tokenizer.ggml.tokens', 9);
  u32(8);
  u64(8);
  for (final token in [
    '<|begin_of_text|>',
    '<|end_of_text|>',
    '<|pad|>',
    '<|unk|>',
    '<unused>',
    '<unused2>',
    '<|start_header|>',
    '<|end_header|>',
  ]) {
    str(token);
  }

  key('tokenizer.ggml.token_type', 9);
  u32(5);
  u64(8);
  for (var i = 0; i < 8; i++) {
    final b = ByteData(4)..setInt32(0, 3, Endian.little);
    out.add(b.buffer.asUint8List());
  }

  key('tokenizer.chat_template', 8);
  str("{{- '<|start_header|>system<|end_header|>' }}${'x' * 30}");

  str('weight');
  u32(1);
  u64(weights.length);
  u32(0);
  u64(0);

  final raw = out.toBytes();
  final align = 32;
  final pad = (align - (raw.length % align)) % align;
  final full = Uint8List(raw.length + pad + weights.length);
  full.setRange(0, raw.length, raw);
  full.setRange(full.length - weights.length, full.length, weights);
  return full;
}
