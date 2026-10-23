import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamjam/pages/home_page.dart';
import 'package:hamjam/pages/session_page.dart';
import 'package:hamjam/session.dart';
import 'package:hamjam/theme.dart';

/// Renders the real screens at phone sizes; Flutter throws on any layout overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> status({
    String role = '',
    int guests = 0,
    List<Map>? chat,
  }) => {
    'role': role,
    'state': role.isEmpty
        ? 'idle'
        : (role == 'host' ? 'capturing' : 'listening'),
    'code': role.isEmpty ? '' : 'K7M2QX',
    'guests': guests,
    'playing': true,
    'swapIn': '',
    'swapOut': false,
    'chat': chat ?? [],
  };

  void mockNative(Map<String, dynamic> Function() status) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('hamjam/native'), (
      call,
    ) async {
      return call.method == 'status' ? status() : null;
    });
    // EventChannel: accept listen/cancel
    messenger.setMockMethodCallHandler(
      const MethodChannel('hamjam/events'),
      (call) async => null,
    );
  }

  Future<void> pump(
    WidgetTester t,
    Widget page,
    Size size, {
    double keyboard = 0,
  }) async {
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    t.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: page));
    await t.pump(const Duration(milliseconds: 400));
  }

  const phones = [Size(360, 780), Size(320, 568), Size(412, 915)];

  for (final size in phones) {
    testWidgets('home fits ${size.width.toInt()}x${size.height.toInt()}', (
      t,
    ) async {
      mockNative(() => status());
      await pump(t, const HomePage(), size);
      expect(find.text('Start hosting'), findsOneWidget);
      if (find.text('Join a jam').evaluate().isEmpty) {
        // below the fold on small phones: the page scrolls
        await t.scrollUntilVisible(
          find.text('Join a jam'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      expect(find.text('Join a jam'), findsOneWidget);
      expect(tester(t), isNull);
    });

    testWidgets(
      'host session fits ${size.width.toInt()}x${size.height.toInt()}',
      (t) async {
        final chat = [
          {'from': 'guest', 'text': 'Hey! Can you hear it?'},
          {'from': 'host', 'text': 'Yes, loud and clear. ' * 4},
          {'from': 'host', 'text': 'Playing your favourite next'},
        ];
        mockNative(() => status(role: 'host', guests: 1, chat: chat));
        await Session.instance.refresh();
        await pump(t, const SessionPage(), size);
        expect(find.text('K7M2QX'), findsOneWidget);
        expect(find.text('Hosting'), findsOneWidget);
      },
    );

    testWidgets(
      'guest session fits ${size.width.toInt()}x${size.height.toInt()} with keyboard',
      (t) async {
        mockNative(() => status(role: 'guest'));
        await Session.instance.refresh();
        await pump(t, const SessionPage(), size, keyboard: 300);
        expect(find.text('Listening'), findsOneWidget);
      },
    );
  }
}

// helper so a failed render surfaces as the test's exception
Object? tester(WidgetTester t) => t.takeException();
