import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/router/app_router.dart';

/// A singleton to hold the app router instance for global access
class AppRouterInstance {
  static StackRouter? _router;
  
  /// Set the router instance (call this in MyApp)
  static void setRouter(StackRouter router) {
    _router = router;
  }
  
  /// Get the router instance
  static StackRouter? getRouter() {
    return _router;
  }
  
  /// Navigate to intro/login route
  static void navigateToIntro() {
    _router?.replaceAll([const IntroRoute()]);
  }
}