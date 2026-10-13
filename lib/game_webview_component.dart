/// 游戏专用 WebView 容器（独立进程 :game_webview）。
///
/// 用法：宿主 main() 按初始路由分发（默认路由运行宿主 App，[gameRouteName]
/// 运行 [GameApp]），打开游戏调用 [GameWebViewComponent.open]。
library;

import 'package:flutter/services.dart';

export 'src/game_app.dart';
export 'src/game_url_policy.dart';
export 'src/game_webview_core.dart';
export 'src/game_webview_page.dart';

/// 游戏进程的初始路由名（原生侧 GameWebViewActivity.getInitialRoute 返回它）。
const gameRouteName = 'game';

class GameWebViewComponent {
  static const _channel = MethodChannel('dev.game_webview_component/channel');

  /// 打开游戏：在独立进程 :game_webview 中拉起游戏页。
  /// 返回表示原生启动调用已完成，不等待游戏加载或关闭。
  static Future<void> open(String url) => _channel.invokeMethod('open', url);

  /// 请求预热 :game_webview 进程：预建 FlutterEngine，并尝试初始化 WebView。
  /// 返回不表示跨进程预热已完成，也不等待游戏资源加载。
  ///
  /// 建议在宿主合适的空闲时机调用（如 App 启动后、进入游戏入口页时）。
  /// [open] 在没有缓存的预热引擎时创建新引擎。
  /// 需在宿主处于前台时调用，否则系统可能拒绝拉起进程。
  /// 手动调用可选；当前实现也会在游戏 Activity 正常结束时再次尝试预热。
  static Future<void> prewarm() => _channel.invokeMethod('prewarm');

  /// 游戏进程内使用：取当前游戏地址（由 Activity intent 提供）。
  static Future<String?> currentGameUrl() =>
      _channel.invokeMethod<String>('getUrl');

  /// 游戏进程内使用：请求结束当前 Activity。
  /// 不执行 WebView 清理；默认页面会先调用 GameWebViewCore.leave() 再调用本方法。
  static Future<void> close() => _channel.invokeMethod('close');
}
