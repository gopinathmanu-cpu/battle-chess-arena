import 'package:battle_chess_arena/src/services/mobile_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/mobile_notifications');

  test(
    'mobile notification bridge forwards permission and scheduling',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'requestPermission' ? true : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = MobileNotificationService(
        channel: channel,
        platform: TargetPlatform.android,
      );
      expect(await service.requestPermission(), isTrue);
      final at = DateTime(2026, 9, 26, 18, 30);
      await service.schedule(
        id: 'scheduled-start:one',
        title: 'Scheduled game time',
        body: 'Your game is ready.',
        at: at,
      );
      await service.cancel('scheduled-start:one');
      expect(calls.map((call) => call.method), [
        'requestPermission',
        'schedule',
        'cancel',
      ]);
      expect((calls[1].arguments as Map)['at'], at.millisecondsSinceEpoch);
    },
  );
}
