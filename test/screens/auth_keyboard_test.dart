import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignIn.dart';
import 'package:flutter_test_project/ui/screens/Profile/ProfileSignUpWidget.dart';

/// The app shell around a page: a top bar, then the page; the shell does
/// not resize for the keyboard (MainNav), the page does.
Widget _shell(Widget page) => MaterialApp(
  home: Scaffold(
    resizeToAvoidBottomInset: false,
    body: Column(
      children: [
        const SizedBox(height: 70),
        Expanded(child: page),
      ],
    ),
  ),
);

const _keyboard = 340.0;
const _screen = Size(390, 844);

Future<void> _phoneWithKeyboard(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_shell(page));
  await tester.pump();
}

/// Like a phone: tap the first field, the keyboard slides up, then Next
/// through the rest with the keyboard staying up. Each field must end up
/// fully above the keyboard.
Future<void> _tapThenNextThrough(WidgetTester tester, int count) async {
  final fields = find.byType(TextField);
  await tester.showKeyboard(fields.first);
  await tester.pump();
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  await tester.pump(const Duration(milliseconds: 400));
  _expectAboveKeyboard(tester, fields.first);
  for (var i = 1; i < count; i++) {
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    _expectAboveKeyboard(tester, fields.at(i));
  }
}

/// [field] is fully on screen above the keyboard.
void _expectAboveKeyboard(WidgetTester tester, Finder field) {
  final r = tester.getRect(field);
  expect(r.top, greaterThanOrEqualTo(0));
  expect(r.bottom, lessThanOrEqualTo(_screen.height - _keyboard));
}

void main() {
  testWidgets('sign in: focused fields stay above the keyboard', (
    tester,
  ) async {
    await _phoneWithKeyboard(tester, const SignInScreen());
    await _tapThenNextThrough(tester, 2);
  });

  testWidgets('sign in: autofill, Next then Done, and Done tries to sign in', (
    tester,
  ) async {
    await _phoneWithKeyboard(tester, const SignInScreen());
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].autofillHints, [AutofillHints.email]);
    expect(fields[0].textInputAction, TextInputAction.next);
    expect(fields[1].autofillHints, [AutofillHints.password]);
    expect(fields[1].textInputAction, TextInputAction.done);

    // Done with empty fields: the sign-in check runs (and says what's missing).
    await tester.showKeyboard(find.byType(TextField).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Please enter both email and password'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('sign in: typed text shows; Sign In is the filled button', (
    tester,
  ) async {
    await _phoneWithKeyboard(tester, const SignInScreen());
    await tester.enterText(find.byType(TextField).first, 'me@example.com');
    await tester.pump();
    expect(find.text('me@example.com'), findsOneWidget);
    final style = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .style;
    expect(style.color, Colors.white, reason: 'typed text is visible');
    expect(find.widgetWithText(OutlinedButton, 'Sign Up'), findsOneWidget);
  });

  testWidgets(
    'sign up: Next through all four fields, each above the keyboard',
    (tester) async {
      await _phoneWithKeyboard(tester, const ProfileSignUp());
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      await _tapThenNextThrough(tester, 4);
      final last = tester.widget<TextField>(fields.at(3));
      expect(last.textInputAction, TextInputAction.done);
      expect(last.autofillHints, [AutofillHints.newPassword]);
    },
  );
}
