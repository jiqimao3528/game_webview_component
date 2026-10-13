import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../game_webview_component.dart';

/// 默认游戏页，包含返回按钮、加载进度和错误提示。
class GameWebViewPage extends StatefulWidget {
  const GameWebViewPage({super.key, required this.uri});
  final Uri uri;
  @override
  State<GameWebViewPage> createState() => _GameWebViewPageState();
}

class _GameWebViewPageState extends State<GameWebViewPage> {
  late final GameWebViewCore core;

  @override
  void initState() {
    super.initState();
    core = GameWebViewCore(uri: widget.uri)
      ..onChanged = () {
        if (mounted) setState(() {});
      };
    unawaited(core.initialize());
  }

  Future<void> leave() async {
    if (core.closing) return;
    await core.leave();
    await GameWebViewComponent.close();
  }

  @override
  void dispose() {
    core.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(leave());
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.uri.host),
        leading: IconButton(
          tooltip: '返回',
          onPressed: core.closing ? null : leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (core.loading)
              LinearProgressIndicator(
                value: core.progress > 0 ? core.progress / 100 : null,
              ),
            if (core.failed)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          core.status,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: leave, child: const Text('返回')),
                      ],
                    ),
                  ),
                ),
              )
            else if (core.controller != null)
              Expanded(child: WebViewWidget(controller: core.controller!))
            else
              const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    ),
  );
}
