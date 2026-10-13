import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_webview_component/game_webview_component.dart';

void main() {
  // 游戏进程（GameWebViewActivity）把初始路由设为 gameRouteName；
  // 主进程默认路由运行 Demo 主页。
  WidgetsFlutterBinding.ensureInitialized();
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  runApp(route == gameRouteName ? const GameApp() : const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '游戏组件 Demo',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff15675c),
      useMaterial3: true,
    ),
    home: const DemoHomePage(),
  );
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});
  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final url = TextEditingController();
  String? error;
  bool opening = false;

  @override
  void initState() {
    super.initState();
    // 请求提前初始化游戏进程；打开时若没有预热引擎，则创建新引擎。
    unawaited(GameWebViewComponent.prewarm());
  }

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> openGame() async {
    final text = url.text.trim();
    if (!isAllowedGameUri(Uri.tryParse(text))) {
      setState(() => error = '请输入有效的 HTTP/HTTPS 地址');
      return;
    }
    setState(() {
      error = null;
      opening = true;
    });
    try {
      await GameWebViewComponent.open(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '打开失败：$e');
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('游戏组件 Demo')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            decoration: InputDecoration(
              errorText: error,
              border: const OutlineInputBorder(),
              hintText: '输入游戏地址（HTTP/HTTPS）',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: opening ? null : openGame,
            child: const Text('打开游戏'),
          ),
          const SizedBox(height: 12),
          const Text(
            '游戏将在独立进程 :game_webview 中打开；返回即关闭。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
