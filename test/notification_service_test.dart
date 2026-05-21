import 'package:flutter_test/flutter_test.dart';
import 'package:roadrescue/services/notification_service.dart';

void main() {
  test('NotificationService is a singleton', () {
    expect(NotificationService.instance, same(NotificationService.instance));
  });
}
