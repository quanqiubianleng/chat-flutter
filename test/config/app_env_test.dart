// 环境配置与常量校验
import 'package:education/config/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnv', () {
    test('currentEnv returns valid config', () {
      final env = currentEnv;
      expect(env.wsUrl, isNotEmpty);
      expect(env.reqUrl, isNotEmpty);
      expect(env.agreeUrl, isNotEmpty);
      expect(env.privacyUrl, isNotEmpty);
    });

    test('EnvConfig dev has debug true', () {
      expect(EnvConfig.dev.isDebug, isTrue);
    });

    test('EnvConfig prod has debug false', () {
      expect(EnvConfig.prod.isDebug, isFalse);
    });
  });
}
