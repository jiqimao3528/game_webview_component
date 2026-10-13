## 0.2.1

- 明确 HTTP/HTTPS 地址策略、预热调用返回时机和自动预热行为。
- 明确网页加载进度、内置 JS 日志通道、独立进程和页面清理的适用范围。
- 补充已内置的 Android WebView 音频播放设置及游戏侧音频行为边界。
- 本版本仅调整文档、注释和包描述，不改变运行行为。

## 0.2.0

- 最低 Android 版本统一为 API 28，插件清单声明联网权限。
- 修复 Activity 重建时预热引擎未销毁的问题。
- 避免页面销毁后异步回调继续更新界面。
- 跟踪当前主文档地址，依据请求地址识别主文档 HTTP 错误。
- 日志更新使用独立的 `onLogChanged` 回调，避免触发默认页面重建。
- 允许 Android WebView 在没有用户手势时播放媒体。
- 新增 `GameWebViewComponent.prewarm()`，预建游戏进程的 FlutterEngine 并初始化 WebView 运行时。
- 并行配置 WebView 初始化设置。
- Android 包名与内部通道统一为 `dev.game_webview_component`。直接引用原生类的接入方需更新导入路径。

## 0.1.0（开发阶段，未在 pub.dev 发布）

- 新增独立进程 `:game_webview` 游戏容器。
- 提供默认游戏页面、HTTP/HTTPS 地址校验和关闭清理。
- 提供 `MessageFromUnityWebGL` 消息通道。
- 在 API 28 及以上设置独立的 WebView 数据目录。
