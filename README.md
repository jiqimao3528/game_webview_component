# game_webview_component

A Flutter plugin for Android web games with a dedicated process, isolated WebView storage, and engine prewarming.

Android 游戏 WebView 容器，基于 [webview_flutter](https://pub.dev/packages/webview_flutter)。
游戏页面运行在独立的 `:game_webview` 进程中，并使用独立的 WebView 数据目录，
用于将游戏的 Cookie、LocalStorage 和 HTTP 缓存与宿主主进程中的 WebView 分开。

## 环境要求

- Flutter 3.47.0 及以上，Dart 3.13.4 及以上。
- Android 9（API 28）及以上，宿主应用的 `minSdk` 必须至少为 28。
- 仅提供 Android 实现。

## 接入

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  game_webview_component: ^0.2.1
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
默认页面的返回按钮和系统返回操作会先执行页面清理，再关闭游戏 Activity。
单独调用 `GameWebViewComponent.close()` 只请求原生 Activity 结束，不执行 WebView 清理。

## 预热

可在宿主处于前台时请求预热，提前预建 FlutterEngine，并尝试初始化游戏进程中的 WebView 运行时：

```dart
await GameWebViewComponent.prewarm();
```

`prewarm()` 返回表示宿主侧原生调用已返回，不表示游戏进程已完成预热。
预热会额外占用内存，启动耗时取决于设备、系统 WebView 和游戏资源。
打开页面时若没有缓存的预热引擎，Activity 会创建新引擎。
手动调用 `prewarm()` 是可选步骤；当前实现会在游戏 Activity 正常结束时自动再次尝试预热，
没有提供关闭这项自动预热的配置。

## 多进程接入注意事项

Activity、Service 和初始化 Provider 由插件清单合并到宿主应用。
宿主的 `Application.onCreate()` 也会在游戏进程执行；涉及第三方 SDK 初始化时，
需要检查其多进程支持情况，并按进程区分初始化逻辑。
WebView 数据目录必须在游戏进程首次使用 WebView 前设置。

数据目录隔离发生在宿主主进程与游戏进程之间。游戏进程中的多个游戏页面仍共享同一目录，
关闭页面不会清除 Cookie、LocalStorage 或 HTTP 缓存。

组件接受 HTTP 和 HTTPS 地址，不强制 HTTPS，也不自动改写地址。
HTTP 是否可以加载取决于宿主的 Android 网络安全配置。
示例应用允许明文流量，便于本地调试。

## 页面与交互

- 默认页面显示初始地址的域名、返回按钮、WebView 网页加载进度和错误信息。
  网页加载完成不表示 Unity 或其他游戏的资源已加载完成，组件不检测游戏就绪状态。
- 默认入口校验游戏地址，仅接受带主机名的 HTTP/HTTPS 地址。
  导航回调会拦截其他协议；关闭清理时允许内部导航到 `about:blank`。
- 默认页面关闭时，如果页面提供 `window.unloadUnity()`，会尝试调用并有界等待，
  随后尝试导航到 `about:blank`，再请求结束 Activity。清理异常或超时会继续关闭。
- `MessageFromUnityWebGL` 通道接收的消息与控制台消息保存在内存中，最多 30 条，每条最多 500 字符。
  内置通道只记录日志，不解析游戏指令，也不向宿主主进程转发消息。
  日志会过滤部分 token 参数和 JWT 格式文本，不会由组件写入日志文件。
  过滤规则不覆盖所有敏感数据，不要向日志发送凭据或其他敏感数据。

## WebGL 音频

`GameWebViewCore.initialize()` 已在加载游戏地址之前设置 Android WebView：

```dart
await androidController.setMediaPlaybackRequiresUserGesture(false);
```

以上代码展示组件内部已执行的设置，接入方不需要复制。
使用默认 `GameApp` / `GameWebViewPage`，或使用 `GameWebViewCore` 并调用 `initialize()`，
无需在宿主中重复配置这一自动播放选项。

这项设置取消 Android WebView 的媒体播放用户手势要求。
组件不会主动调用游戏的 `AudioContext.resume()`，也不修改游戏的音量、静音或音频启动逻辑。
实际能否发声仍取决于游戏的音频实现和设备的系统 WebView；组件不保证所有 WebGL 游戏自动发声。
如果自行创建 WebViewController 并绕过 `GameWebViewCore`，需要自行配置媒体播放选项。

自定义 Flutter 页面可使用 `GameWebViewCore` 处理加载、日志和关闭逻辑，
并参考 `GameWebViewPage` 组织界面。
状态更新通过 `onChanged` 通知，日志更新通过 `onLogChanged` 通知。
独立进程由 `open()` 启动的原生 Activity 提供；直接在宿主页面使用
`GameWebViewPage` 或 `GameWebViewCore` 不会自动创建独立进程。
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
