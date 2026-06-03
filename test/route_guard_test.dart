import 'package:flutter_test/flutter_test.dart';
import 'package:roadrescue/routes/app_routes.dart';
import 'package:roadrescue/routes/route_guard.dart';

void main() {
  test('public routes do not require role', () {
    expect(RouteGuard.isPublicRoute(AppRoutes.signUpLoginScreen), isTrue);
    expect(RouteGuard.isPublicRoute(AppRoutes.faqTosScreen), isTrue);
    expect(RouteGuard.isPublicRoute(AppRoutes.initial), isTrue);
  });

  test('provider route is not public', () {
    expect(RouteGuard.isPublicRoute(AppRoutes.providerDocumentsScreen), isFalse);
  });
}
