# game_webview_component

A Flutter plugin for Android web games, with a dedicated process, isolated WebView storage, and optional engine prewarming.

Android 游戏 WebView 容器，基于 [webview_flutter](https://pub.dev/packages/webview_flutter)。
游戏页面运行在独立的 `:game_webview` 进程中，并使用独立的 WebView 数据目录，
用于将游戏的 Cookie、LocalStorage 和 HTTP 缓存与宿主主进程中的 WebView 分开。

## 环境要求

- Flutter 3.47.0 及以上，Dart 3.13.4 及以上。
- Android 9（API 28）及以上，宿主应用的 `minSdk` 必须至少为 28。
- 仅提供 Android 实现。

## 接入

发布到 pub.dev 前可通过 Git 仓库引用组件（需要仓库已包含源码）：

```yaml
dependencies:
  game_webview_component:
    git:
      url: https://github.com/jiqimao3528/game_webview_component.git
```

插件清单会自动合并 `INTERNET` 权限。宿主需将 Android `minSdk` 设置为 28 或更高，
并在 Flutter `pubspec.yaml` 的 `flutter` 节点下启用 `uses-material-design: true`，
以显示默认页面的 Material 图标。

在宿主 `main()` 中根据初始路由选择入口。`MyApp` 表示宿主现有的应用组件：

```dart
import 'package:flutter/material.dart';
import 'package:game_webview_component/game_webview_component.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  runApp(route == gameRouteName ? const GameApp() : const MyApp());
}
```

打开游戏：

```dart
await GameWebViewComponent.open('https://example.com/game/index.html');
```

`open()` 在原生启动请求完成后返回，不等待游戏加载或关闭。
页面返回按钮和系统返回操作会关闭游戏 Activity。

## 预热

可在宿主处于前台时预建 FlutterEngine，并初始化游戏进程中的 WebView 运行时：

```dart
await GameWebViewComponent.prewarm();
```

预热会额外占用内存，启动耗时取决于设备、系统 WebView 和游戏资源。
预热失败或进程被系统回收后，下一次打开会走冷启动。
游戏 Activity 正常关闭后，组件会重新预热以供下次使用。

## 多进程接入注意事项

Activity、Service 和初始化 Provider 由插件清单合并到宿主应用。
宿主的 `Application.onCreate()` 也会在游戏进程执行；涉及第三方 SDK 初始化时，
需要检查其多进程支持情况，并按进程区分初始化逻辑。
WebView 数据目录必须在游戏进程首次使用 WebView 前设置。

数据目录隔离发生在宿主主进程与游戏进程之间。游戏进程中的多个游戏页面仍共享同一目录，
关闭页面不会清除 Cookie、LocalStorage 或 HTTP 缓存。

默认使用 HTTPS。需要加载 HTTP 地址时，由宿主配置 Android 网络安全策略。
示例应用允许明文流量，便于本地调试。

## 页面与交互

- 默认页面显示域名、返回按钮、加载进度和错误信息。
- 导航仅允许 HTTP/HTTPS 地址。
- Android WebView 已允许无需用户手势的媒体播放；实际音频行为仍需结合游戏验证。
- 关闭时尝试调用页面的 `unloadUnity()`，有界等待后导航到 `about:blank` 并结束 Activity。
- `MessageFromUnityWebGL` 通道接收的消息与控制台消息保存在内存中，最多 30 条，每条最多 500 字符。
  日志会过滤部分 token 参数和 JWT 格式文本；不要向日志发送凭据或其他敏感数据。

自定义 Flutter 页面可使用 `GameWebViewCore` 处理加载、日志和关闭逻辑，
并参考 `GameWebViewPage` 组织界面。
状态更新通过 `onChanged` 通知，日志更新通过 `onLogChanged` 通知。
如需替换原生启动页面，可继承 `GameWebViewActivity`、覆写 `getInitialRoute()`，
在宿主清单中声明该 Activity 并配置游戏进程，再从宿主原生代码启动。
默认 `open()` 始终启动组件提供的 Activity。

JS 与 Dart 交互可使用 `WebViewController.addJavaScriptChannel`、
`runJavaScript` 和 `runJavaScriptReturningResult`。

## 示例

```powershell
cd example
flutter pub get
flutter run
```

输入游戏地址后点击“打开游戏”。完整入口代码见 [example/lib/main.dart](example/lib/main.dart)。

## 开发检查

```powershell
flutter analyze
flutter test
```

游戏兼容性取决于设备的系统 WebView 版本和游戏对 WebGL、WebAssembly 等能力的要求。
发布前应在目标设备验证冷启动、预热、页面关闭和加载失败等场景。

## 许可证

[MIT](LICENSE) © 2026 Tengfanmiao.
