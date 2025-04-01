import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) async {
    final container = ProviderContainer();
    
    try {
      // Wait for the AuthService to be initialized
      final authServiceAsync = await container.read(authServiceProvider.future);
      
      // Now we can use the AuthService instance
      final isAuth = await authServiceAsync.isAuthenticated();
      
      if (isAuth) {
        resolver.next(true);
      } else {
        // Use IntroRoute instead of a welcome page as it seems to be your entry point
        router.push(const IntroRoute());
        resolver.next(false);
      }
    } catch (e) {
      print('Auth error: $e'); // Add logging for debugging
      router.push(const IntroRoute());
      resolver.next(false);
    } finally {
      // Clean up the container when done
      container.dispose();
    }
  }
}