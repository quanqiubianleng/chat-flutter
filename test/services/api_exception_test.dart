// API 层异常与解析
import 'package:education/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiException', () {
    test('message is preserved', () {
      const msg = 'test error';
      final e = ApiException(msg);
      expect(e.message, msg);
      expect(e.toString(), contains(msg));
    });
  });
}
