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
  static Future<void> open(String url) => _channel.invokeMethod('open', url);

  /// 预热 :game_webview 进程（可选）：提前拉起进程、预建 FlutterEngine 并
  /// 初始化 WebView 运行时，减少下一次 [open] 的初始化工作。
  ///
  /// 建议在宿主合适的空闲时机调用（如 App 启动后、进入游戏入口页时）。
  /// 预热不生效（进程被系统回收、后台启动受限等）时 [open] 自动回退冷启动。
  /// 需在宿主处于前台时调用，否则系统可能拒绝拉起进程。
  static Future<void> prewarm() => _channel.invokeMethod('prewarm');

  /// 游戏进程内使用：取当前游戏地址（由 Activity intent 提供）。
  static Future<String?> currentGameUrl() =>
      _channel.invokeMethod<String>('getUrl');

  /// 游戏进程内使用：结束游戏 Activity，整个游戏进程随后可被系统回收。
  static Future<void> close() => _channel.invokeMethod('close');
}
