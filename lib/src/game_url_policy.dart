// 游戏地址只允许 HTTP/HTTPS，避免 WebView 被喂入 javascript:/file: 等输入。
bool isAllowedGameUri(Uri? uri) =>
    uri != null &&
    uri.host.isNotEmpty &&
    (uri.scheme == 'http' || uri.scheme == 'https');

/// 展示日志/状态前过滤 token 与 JWT。
String redactGameSecrets(String text) => text
    .replaceAllMapped(
      RegExp(r'(token(?:=|%3[dD]))[^\s&#"<>]+', caseSensitive: false),
      (match) => '${match[1]}[redacted]',
    )
    .replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
      '[redacted-jwt]',
    );
