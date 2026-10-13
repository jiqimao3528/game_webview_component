# 示例应用

演示 `game_webview_component` 的入口路由分发、进程预热和游戏页面打开。

## 运行

在本目录执行：

```powershell
flutter pub get
flutter run
```

需要 Android 9（API 28）及以上的设备或模拟器。
输入 HTTP/HTTPS 游戏地址后点击“打开游戏”，使用页面返回按钮或系统返回操作关闭游戏。

## 配置

- 通过 `path: ../` 引用组件源码。
- 允许 HTTP 明文流量，便于本地调试。正式宿主应按需配置网络安全策略。
- Release 构建使用调试签名，仅用于验证组件。

```powershell
flutter build apk --release
```
