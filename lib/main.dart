import 'package:flutter/material.dart';
import 'screens/download_screen.dart';
import 'screens/chat_screen.dart';
import 'services/app_settings.dart';
import 'services/model_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const AirplaneApp());
}

class AirplaneApp extends StatelessWidget {
  const AirplaneApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirplaneAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2EC4A5)),
        useMaterial3: true,
      ),
      home: const Bootstrap(),
    );
  }
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  final ModelManager _mgr = ModelManager();
  bool _checking = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ready = await _mgr.isAllReady();
    setState(() {
      _ready = ready;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1D26),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2EC4A5))),
      );
    }
    if (_ready) {
      return ChatScreen(onModelMissing: () {
        setState(() => _ready = false);
      });
    }
    return DownloadScreen(onReady: () {
      setState(() => _ready = true);
    });
  }
}
