import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genz_exam_mobile/api/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('in.genziitian.quizlab/app_icon');
  final log = <MethodCall>[];
  String currentIcon = 'default';

  setUp(() {
    log.clear();
    currentIcon = 'default';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'getCurrentIcon') {
        return currentIcon;
      }
      if (methodCall.method == 'setIcon') {
        currentIcon = (methodCall.arguments as Map)['icon'] as String;
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('switches to pro icon when user is pro on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await AppIconService.syncIcon(isPro: true);

    expect(log.map((c) => c.method), contains('getCurrentIcon'));
    expect(log.map((c) => c.method), contains('setIcon'));
    expect(currentIcon, 'pro');
  });

  test('does not re-invoke setIcon if icon is already correct', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    currentIcon = 'pro';
    log.clear();

    await AppIconService.syncIcon(isPro: true);

    expect(log.map((c) => c.method), ['getCurrentIcon']);
    expect(currentIcon, 'pro');
  });

  test('switches back to default when isPro is false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    currentIcon = 'pro';
    log.clear();

    await AppIconService.syncIcon(isPro: false);

    expect(log.map((c) => c.method), contains('setIcon'));
    expect(currentIcon, 'default');
  });
}
