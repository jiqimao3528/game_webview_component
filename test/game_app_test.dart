import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_webview_component/game_webview_component.dart';

void main() {
  const channel = MethodChannel('dev.game_webview_component/channel');

  for (final failRequest in [false, true]) {
    testWidgets('ignores URL result after disposal (error: $failRequest)', (
      tester,
    ) async {
      final response = Completer<Object?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) {
        expect(call.method, 'getUrl');
        return response.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(const GameApp());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      if (failRequest) {
        response.completeError(PlatformException(code: 'STATE'));
      } else {
        response.complete('https://example.com/game');
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
