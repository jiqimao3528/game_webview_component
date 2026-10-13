import 'package:flutter/material.dart';

import '../game_webview_component.dart';

/// 游戏进程（:game_webview）里运行的 App：从原生侧读取地址并展示游戏页。
/// 宿主 main() 在 defaultRouteName == gameRouteName 时运行它（见 README）。
class GameApp extends StatefulWidget {
  const GameApp({super.key});
  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  Uri? uri;
  String? error;

  @override
  void initState() {
    super.initState();
    loadUrl();
  }

  Future<void> loadUrl() async {
    try {
      final raw = await GameWebViewComponent.currentGameUrl();
      if (!mounted) return;
      final parsed = Uri.tryParse((raw ?? '').trim());
      if (!isAllowedGameUri(parsed)) {
        setState(() => error = '游戏地址无效或缺失');
        return;
      }
      setState(() => uri = parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '读取游戏地址失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '游戏',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff15675c),
      useMaterial3: true,
    ),
    home: uri != null
        ? GameWebViewPage(uri: uri!)
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(error!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: GameWebViewComponent.close,
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
  );
}
