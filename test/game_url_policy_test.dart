import 'package:flutter_test/flutter_test.dart';
import 'package:game_webview_component/game_webview_component.dart';

void main() {
  test('allows any HTTP/HTTPS host', () {
    for (final value in [
      'http://192.0.2.1:8080?version=1&token=test-only',
      'http://198.51.100.1:9023/api',
      'http://example.com',
      'http://203.0.113.1/game',
      'https://example.com/game',
      'https://name:password@example.com',
    ]) {
      expect(isAllowedGameUri(Uri.parse(value)), isTrue, reason: value);
    }
  });
  test('rejects non-HTTP schemes and malformed input', () {
    for (final value in [
      'file:///android_asset/test',
      'javascript:alert(1)',
      '/relative',
      'not a url',
    ]) {
      expect(isAllowedGameUri(Uri.parse(value)), isFalse, reason: value);
    }
    expect(isAllowedGameUri(null), isFalse);
  });
  test('console filtering removes token values before display truncation', () {
    const input =
        'http://example.com?token=test-secret&page=6 raw eyJabc.abcdef.ghijkl';
    final output = redactGameSecrets(input);
    expect(output, isNot(contains('test-secret')));
    expect(output, isNot(contains('eyJabc')));
    expect(output, contains('page=6'));
    expect(redactGameSecrets('token%3Dencoded%26value'), 'token%3D[redacted]');
  });
}
