import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/providers/device_info_provider.dart';
import 'package:eulaiq/src/common/services/google_auth_service.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/auth/blocs/verify_code.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/constants/global_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';


class SignInState extends ChangeNotifier {
  final emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  String _email = '';
  String _password = '';
  String _firstname = '';
  String _lastname = '';
  final List<String> interests = [];
  bool _passwordVisible = false;
  bool _continue = false;

  bool get passwordVisibility => _passwordVisible;
  bool get continueButtonEnabled => _continue;


  void togglePasswordVisibility() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  void validateForm(String value, String fieldName) {
    if (fieldName == 'email') {
      _email = value;
    } else if (fieldName == 'password') {
      _password = value;
    }

    final bool isValidEmail = emailRegExp.hasMatch(_email);
    final bool isValidPassword = _password.isNotEmpty;

    _continue = isValidEmail && isValidPassword;
    notifyListeners();
  }

  void collectFormData(String value, String fieldName) {
    if (fieldName == 'firstname') {
      _firstname = value;
    } else if (fieldName == 'lastname') {
      _lastname = value;
    } else if (fieldName == "interests") {
      interests.add(value);
    }
    _continue = _firstname.isNotEmpty && _lastname.isNotEmpty;
    notifyListeners();
  }

  Future<void> signIn(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(loadingProvider.notifier).state = true;
      ref.read(email.notifier).state = _email;
      ref.read(statusCodeProvider.notifier).state = null;

      final deviceInfoService = ref.read(deviceInfoProvider);
      await deviceInfoService.initDeviceInfo();
      final notificationService = ref.read(notificationServiceProvider);

      final response = await DioConfig.dio?.post(
        '/auth/login',
        data: {
          'identity': _email.trim(),
          'password': _password.trim(),
          'ipAddress': deviceInfoService.ipAddress,
          'device': deviceInfoService.deviceInfo,
        },
      );

      final responseData = response?.data;
      if (response?.statusCode == 200) {
        ref.read(loadingProvider.notifier).state = false;
        ref.read(statusCodeProvider.notifier).state = 200;
        
        // Refresh user data after login
        await ref.read(userProvider.notifier).refreshUser();
        
        notificationService.showNotification(
          message: responseData['message'] as String? ?? 'Login successful',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );

        if (context.mounted) {
          context.router.replace(const SplashRoute());
        }
      }
    } on DioException catch (error) {
      ref.read(loadingProvider.notifier).state = false;
      final notificationService = ref.read(notificationServiceProvider);

      if (error.response?.statusCode == 403 &&
          error.response?.data['status'] == "verification_required") {
        notificationService.showNotification(
          message:
              error.response?.data['message'] as String? ??
              'Verification required',
          type: NotificationType.warning,
        );

        if (context.mounted) {
          context.router.push(
            VerificationCodeRoute(
              verificationType: VerificationType.unUsualSignIn,
            ),
          );
        }
      } else if (error.response?.statusCode == 400) {
        notificationService.showNotification(
          message:
              error.response?.data['errorMessage'] as String? ??
              'Invalid credentials',
          type: NotificationType.error,
        );
      } else if (error.response?.statusCode == 500) {
        notificationService.showNotification(
          message: 'Please ensure that your internet connection is stable',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> signUp(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(loadingProvider.notifier).state = true;
      final notificationService = ref.read(notificationServiceProvider);
      final deviceInfoService = ref.read(deviceInfoProvider);
      await deviceInfoService.initDeviceInfo();

      final response = await DioConfig.dio?.post(
        '/auth/register',
        data: {
          'firstname': _firstname,
          'lastname': _lastname,
          'email': _email.trim(),
          'password': _password.trim(),
          'ipAddress': deviceInfoService.ipAddress,
          'deviceInfo': deviceInfoService.deviceInfo,
          'anonymousId': null,
        },
      );

      if (response?.statusCode == 201) {
        ref.read(loadingProvider.notifier).state = false;
        notificationService.showNotification(
          message:
              response?.data['message'] as String? ?? 'Registration successful',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );

        if (context.mounted) {
          context.router.push(
            VerificationCodeRoute(verificationType: VerificationType.signUp),
          );
        }
      }
    } on DioException catch (error) {
      ref.read(loadingProvider.notifier).state = false;
      final notificationService = ref.read(notificationServiceProvider);

      if (error.response?.statusCode == 400) {
        notificationService.showNotification(
          message:
              error.response?.data['errorMessage'] as String? ??
              'Registration failed',
          type: NotificationType.error,
        );
      } else {
        notificationService.showNotification(
          message: 'An error occurred. Please try again.',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      ref.read(loadingProvider.notifier).state = false;
      ref
          .read(notificationServiceProvider)
          .showNotification(
            message: 'An unexpected error occurred',
            type: NotificationType.error,
          );
    }
  }

  Future<void> continueAsGuest(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(guestSignInLoadingProvider.notifier).state = true;
      final notificationService = ref.read(notificationServiceProvider);
      final deviceInfoService = ref.read(deviceInfoProvider);
      await deviceInfoService.initDeviceInfo();

      final response = await DioConfig.dio?.post(
        '/auth/anonymous',
        data: {
          'deviceInfo': deviceInfoService.deviceInfo,
          'ipAddress': deviceInfoService.ipAddress,
        },
      );

      if (response?.statusCode == 200) {
        ref.read(guestSignInLoadingProvider.notifier).state = false;
        
        // Refresh user data after login
        await ref.read(userProvider.notifier).refreshUser();
        
        notificationService.showNotification(
          message: response?.data['message'] as String? ?? 'Welcome!',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );

        if (context.mounted) {
          context.router.replace(const SplashRoute());
        }
      }
    } on DioException catch (error) {
      ref.read(guestSignInLoadingProvider.notifier).state = false;
      final notificationService = ref.read(notificationServiceProvider);

      if (error.response?.statusCode == 400) {
        notificationService.showNotification(
          message:
              error.response?.data['errorMessage'] as String? ??
              'Failed to continue as guest',
          type: NotificationType.error,
        );
      } else {
        notificationService.showNotification(
          message: 'An error occurred. Please try again.',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> signInWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(googleSignInLoadingProvider.notifier).state = true;
      final notificationService = ref.read(notificationServiceProvider);
      final deviceInfoService = ref.read(deviceInfoProvider);
      final googleAuthService = ref.read(googleAuthServiceProvider);

      print('Initiating Google Sign In...'); // Debug log
      final googleData = await googleAuthService.signInWithGoogle();

      if (googleData == null) {
        print('Google Sign In returned null'); // Debug log
        ref.read(googleSignInLoadingProvider.notifier).state = false;
        notificationService.showNotification(
          message: 'Google sign in was cancelled',
          type: NotificationType.warning,
        );
        return;
      }

      print('Got Google data, proceeding with backend auth...'); // Debug log
      await deviceInfoService.initDeviceInfo();

      final response = await DioConfig.dio?.post(
        '/auth/googleSignIn',
        data: {
          'idToken': googleData['idToken'],
          'deviceInfo': deviceInfoService.deviceInfo,
          'ipAddress': deviceInfoService.ipAddress,
        },
      );

      if (response?.statusCode == 200 || response?.statusCode == 201) {
        ref.read(googleSignInLoadingProvider.notifier).state = false;
        
        // Refresh user data after login
        await ref.read(userProvider.notifier).refreshUser();
        
        notificationService.showNotification(
          message: response?.data['message'] as String? ?? 'Welcome!',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );

        if (context.mounted) {
          context.router.replace(const SplashRoute());
        }
      }
    } on DioException catch (error) {
      ref.read(googleSignInLoadingProvider.notifier).state = false;
      final notificationService = ref.read(notificationServiceProvider);

      if (error.response?.statusCode == 403 &&
          error.response?.data['status'] == "verification_required") {
        notificationService.showNotification(
          message:
              error.response?.data['message'] as String? ??
              'Verification required',
          type: NotificationType.warning,
        );

        if (context.mounted) {
          context.router.push(
            VerificationCodeRoute(
              verificationType: VerificationType.unUsualSignIn,
            ),
          );
        }
      } else if (error.response?.statusCode == 400 &&
          error.response?.data['status'] == 'auth_method_mismatch') {
        notificationService.showNotification(
          message:
              error.response?.data['errorMessage'] as String? ??
              'Please sign in with your password',
          type: NotificationType.warning,
          duration: const Duration(seconds: 5),
        );
      } else if (error.response?.statusCode == 500) {
        notificationService.showNotification(
          message:
              error.response?.data['errorMessage'] as String? ??
              'Could not verify Google credentials',
          type: NotificationType.error,
        );
      } else {
        notificationService.showNotification(
          message: 'An error occurred. Please try again.',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      print('Unexpected error during Google Sign In: $e'); // Debug log
      ref.read(googleSignInLoadingProvider.notifier).state = false;
      ref
          .read(notificationServiceProvider)
          .showNotification(
            message: 'An unexpected error occurred during Google Sign In',
            type: NotificationType.error,
          );
    }
  }

  Future<void> signOut(BuildContext context, WidgetRef ref) async {
    try {
      // Call your API to invalidate token
      // final response = 
      await DioConfig.dio?.post('/auth/logout');
      
      // Clear user data locally
      await ref.read(userProvider.notifier).clearUser();
      
      if (context.mounted) {
        context.router.replace(const AuthRoute());
      }
    } catch (error) {
      // Handle error
    }
  }
}

// Define the provider
final signInProvider = ChangeNotifierProvider<SignInState>((ref) {
  return SignInState();
});
