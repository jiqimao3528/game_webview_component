import 'package:flutter_test/flutter_test.dart';
import 'package:game_webview_component/game_webview_component.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  late _FakeWebViewPlatform platform;
  late GameWebViewCore core;

  setUp(() {
    platform = _FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    core = GameWebViewCore(uri: Uri.parse('https://example.com/start'));
  });
  tearDown(() => core.dispose());

  for (final useNavigationRequest in [false, true]) {
    test(
      'detects redirected HTTP failure (navigation: $useNavigationRequest)',
      () async {
        await core.initialize();
        expect(core.failed, isFalse);
        const redirected = 'https://example.com/game';
        if (useNavigationRequest) {
          expect(
            await platform.navigation.onNavigationRequest(
              const NavigationRequest(url: redirected, isMainFrame: true),
            ),
            NavigationDecision.navigate,
          );
        } else {
          platform.navigation.onPageStarted(redirected);
        }
        platform.navigation.onHttpError(_httpError(redirected, 503));
        platform.navigation.onPageFinished(redirected);

        expect(core.failed, isTrue);
        expect(core.loading, isFalse);
        expect(core.status, contains('503'));
      },
    );
  }

  test('resource HTTP errors do not replace the page with an error', () async {
    await core.initialize();
    const frame = 'https://example.com/frame';
    await platform.navigation.onNavigationRequest(
      const NavigationRequest(url: frame, isMainFrame: false),
    );
    platform.navigation.onHttpError(_httpError(frame, 404));
    platform.navigation.onPageFinished(core.uri.toString());

    expect(core.failed, isFalse);
    expect(core.loading, isFalse);
    expect(core.logs.single, contains('404'));
  });

  test('retry resets the tracked document to the original URL', () async {
    await core.initialize();
    platform.navigation.onPageStarted('https://example.com/redirect');
    await core.load();
    platform.navigation.onHttpError(_httpError(core.uri.toString(), 500));
    expect(core.failed, isTrue);
  });

  test(
    'logs notify only log listeners and retain a bounded, redacted history',
    () {
      var stateUpdates = 0;
      var logUpdates = 0;
      core.onChanged = () => stateUpdates++;
      core.onLogChanged = () => logUpdates++;

      for (var i = 0; i < 35; i++) {
        core.addLog('entry=$i token=test-secret ${'x' * 600}');
      }
      expect(stateUpdates, 0);
      expect(logUpdates, 35);
      expect(core.logs, hasLength(30));
      expect(core.logs.first, startsWith('entry=5'));
      expect(core.logs.every((line) => line.length <= 500), isTrue);
      expect(core.logs.any((line) => line.contains('test-secret')), isFalse);

      core.dispose();
      core.addLog('late message');
      expect(core.logs, isEmpty);
      expect(logUpdates, 35);
      expect(core.onChanged, isNull);
      expect(core.onLogChanged, isNull);
    },
  );
}

HttpResponseError _httpError(String url, int status) => HttpResponseError(
  request: WebResourceRequest(uri: Uri.parse(url)),
  response: WebResourceResponse(uri: Uri.parse(url), statusCode: status),
);

class _FakeWebViewPlatform extends WebViewPlatform {
  late _FakeNavigationDelegate navigation;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => navigation = _FakeNavigationDelegate(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage) onConsoleMessage,
  ) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  late NavigationRequestCallback onNavigationRequest;
  late PageEventCallback onPageStarted;
  late PageEventCallback onPageFinished;
  late HttpResponseErrorCallback onHttpError;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    onNavigationRequest = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    onPageStarted = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    onPageFinished = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    onHttpError = callback;
  }

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}
