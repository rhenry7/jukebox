import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/services/app_update/app_update_service.dart';

void main() {
  group('isNewerBuild', () {
    test('a different live build is newer', () {
      expect(isNewerBuild(current: 'abc-1', live: 'def-2'), isTrue);
    });

    test('the same build is not', () {
      expect(isNewerBuild(current: 'abc-1', live: 'abc-1'), isFalse);
    });

    test('unknown live build or a local run never update', () {
      expect(isNewerBuild(current: 'abc-1', live: null), isFalse);
      expect(isNewerBuild(current: 'abc-1', live: ''), isFalse);
      expect(isNewerBuild(current: '', live: 'def-2'), isFalse);
    });
  });

  test('local runs and tests have no build id, so never check', () async {
    expect(AppUpdateService.enabled, isFalse);
    expect(await AppUpdateService.newerBuildId(), isNull);
  });
}
