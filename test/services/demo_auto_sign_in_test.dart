import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/demo_auto_sign_in.dart';

void main() {
  test('matches the demo email, ignoring case and spaces', () {
    expect(
        DemoAutoSignIn.isDemoEmail(' Demo@Example.com',
            demoEmail: 'demo@example.com'),
        isTrue);
  });

  test('other accounts are not the demo account', () {
    expect(
        DemoAutoSignIn.isDemoEmail('someone@example.com',
            demoEmail: 'demo@example.com'),
        isFalse);
    expect(DemoAutoSignIn.isDemoEmail(null, demoEmail: 'demo@example.com'),
        isFalse);
  });

  test('with no demo account configured, nobody is the demo user', () {
    expect(DemoAutoSignIn.isDemoEmail('', demoEmail: ''), isFalse);
    expect(DemoAutoSignIn.isDemoEmail('a@b.com', demoEmail: ''), isFalse);
  });
}
