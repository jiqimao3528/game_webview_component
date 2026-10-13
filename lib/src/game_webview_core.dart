import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'game_url_policy.dart';

/// 游戏 WebView 的核心状态与行为：加载、导航策略、超时、关闭清理。
/// 供 GameWebViewPage 和自定义页面使用。
class GameWebViewCore {
  GameWebViewCore({required this.uri}) : _mainFrameUri = uri;

  final Uri uri;
  final logs = <String>[];
  WebViewController? controller;
  Timer? _timeout;
  Uri _mainFrameUri;
  String status = '正在准备 WebView';
  bool loading = true;
  bool failed = false;
  bool closing = false;
  int progress = 0;

  /// 状态变化回调（页面据此 setState）。
  void Function()? onChanged;

  /// 新日志回调。默认页面不监听日志，避免控制台输出触发页面重建。
  void Function()? onLogChanged;

  void _notify() {
    onChanged?.call();
  }

  void _setStatus(String message) {
    if (closing) return;
    status = redactGameSecrets(message);
    _notify();
  }

  Future<void> initialize() async {
    try {
      final next = WebViewController();
      // 以下几项设置互不依赖，并行下发，省掉串行平台通道往返的等待。
      await Future.wait([
        next.setJavaScriptMode(JavaScriptMode.unrestricted),
        // 允许 Android WebView 在没有用户手势时播放媒体。
        if (next.platform is AndroidWebViewController)
          (next.platform as AndroidWebViewController)
              .setMediaPlaybackRequiresUserGesture(false),
        // Unity 模板通过该桥回传消息；Android 侧等价于 addJavascriptInterface。
        next.addJavaScriptChannel(
          'MessageFromUnityWebGL',
          onMessageReceived: (message) => addLog('Unity: ${message.message}'),
        ),
        next.setOnConsoleMessage(
          (message) => addLog('${message.level.name}: ${message.message}'),
        ),
        next.setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (closing && request.url == 'about:blank') {
                return NavigationDecision.navigate;
              }
              if (isAllowedGameUri(Uri.tryParse(request.url))) {
                if (request.isMainFrame) {
                  _mainFrameUri = Uri.parse(request.url);
                }
                return NavigationDecision.navigate;
              }
              // 默认拦截非 HTTP/HTTPS 导航。
              if (request.isMainFrame) fail('跳转被拦截：仅支持 HTTP/HTTPS 地址');
              return NavigationDecision.prevent;
            },
            onPageStarted: (url) {
              if (closing) return;
              _mainFrameUri = Uri.tryParse(url) ?? _mainFrameUri;
              loading = true;
              progress = 0;
              _setStatus('正在载入网页');
            },
            onProgress: (value) {
              if (closing) return;
              progress = value;
              _notify();
            },
            onPageFinished: (_) {
              if (closing || failed) return;
              _timeout?.cancel();
              loading = false;
              _setStatus('网页已载入；Unity 资源准备状态以游戏界面为准');
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true) {
                fail('载入失败：${error.description}；可重试或返回');
              } else {
                addLog('资源错误：${error.description}');
              }
            },
            onHttpError: (error) {
              if (error.request?.uri == _mainFrameUri) {
                fail('服务器返回 HTTP ${error.response?.statusCode}；可重试或返回');
              } else {
                addLog('资源 HTTP ${error.response?.statusCode}');
              }
            },
          ),
        ),
      ]);
      if (closing) return;
      controller = next;
      _notify();
      await load();
    } catch (error) {
      fail('WebView 初始化失败：$error');
    }
  }

  void addLog(String message) {
    if (closing) return;
    final text = redactGameSecrets(message);
    logs.add(text.length > 500 ? text.substring(0, 500) : text);
    if (logs.length > 30) logs.removeAt(0);
    onLogChanged?.call();
  }

  void fail(String message) {
    if (closing) return;
    _timeout?.cancel();
    failed = true;
    loading = false;
    _setStatus(message);
  }

  Future<void> load({bool clearCacheFirst = false}) async {
    final current = controller;
    if (current == null || closing) return;
    _mainFrameUri = uri;
    _timeout?.cancel();
    loading = true;
    failed = false;
    progress = 0;
    _setStatus('正在载入网页');
    _timeout = Timer(
      const Duration(seconds: 60),
      () => fail('网页载入超过 60 秒，可重试或返回；尚未确定兼容性'),
    );
    try {
      if (clearCacheFirst) {
        // 按调用方要求清理 HTTP 缓存，用于排查缓存导致的加载问题。
        await current.clearCache();
      }
      await current.loadRequest(uri);
    } catch (error) {
      fail('载入失败：$error');
    }
  }

  /// 关闭游戏：有界调用模板的 unloadUnity()，再把文档置为 about:blank。
  /// 调用方负责随后结束页面/Activity。
  Future<void> leave() async {
    if (closing) return;
    closing = true;
    _timeout?.cancel();
    final current = controller;
    if (current != null) {
      try {
        await current
            .runJavaScript('''
          window.__gameQuitDone = false;
          try {
            var quit = typeof window.unloadUnity === 'function' ? window.unloadUnity() : null;
            Promise.resolve(quit).then(function(){window.__gameQuitDone=true;},function(){window.__gameQuitDone=true;});
          } catch (_) { window.__gameQuitDone = true; }
        ''')
            .timeout(const Duration(seconds: 1));
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          final done = await current
              .runJavaScriptReturningResult('window.__gameQuitDone === true')
              .timeout(const Duration(milliseconds: 400));
          if (done == true || done == 'true') break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } catch (_) {
        /* 页面可能已失败或渲染进程已丢失。 */
      }
      try {
        await current
            .loadRequest(Uri.parse('about:blank'))
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
    _notify();
  }

  void dispose() {
    closing = true;
    _timeout?.cancel();
    logs.clear();
    onChanged = null;
    onLogChanged = null;
  }
}
