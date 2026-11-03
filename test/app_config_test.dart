import 'package:flutter_test/flutter_test.dart';
import 'package:itdmp/core/configuration/app_config.dart';

void main() {
  test('DEV config is complete', () {
    expect(AppConfig.dev.missingSettings, isEmpty);
  });

  test('environment name picks the config (case-insensitive, default DEV)', () {
    expect(AppConfig.forEnvironment('prod').environment, 'PROD');
    expect(AppConfig.forEnvironment('PROD').environment, 'PROD');
    expect(AppConfig.forEnvironment('DEV').environment, 'DEV');
    expect(AppConfig.forEnvironment('anything').environment, 'DEV');
  });

  test('PROD config reports empty IDs until they are filled in', () {
    if (AppConfig.prod.siteId.isEmpty) {
      expect(AppConfig.prod.missingSettings, contains('siteId'));
    } else {
      expect(AppConfig.prod.missingSettings, isEmpty);
    }
  });
}
