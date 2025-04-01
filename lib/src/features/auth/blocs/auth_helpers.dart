// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus {
  authenticated,
  notAuthenticated,
  error,
}

Future<AuthStatus> checkTokenInCookie(WidgetRef ref) async {
  var cookiesLogin = await DioConfig.cookieJar.loadForRequest(Uri.parse('$baseURL/user/login'));
  var cookiesRegister = await DioConfig.cookieJar.loadForRequest(Uri.parse('$baseURL/user/register'));

  var tokenCookieLogin = cookiesLogin.firstWhere(
    (cookie) => cookie.name == 'token',
    orElse: () => Cookie('dummy', ''),
  );
  var tokenCookieRegister = cookiesRegister.firstWhere(
    (cookie) => cookie.name == 'token',
    orElse: () => Cookie('dummy', ''),
  );

  var tokenCookie = tokenCookieLogin.name == 'token' ? tokenCookieLogin : tokenCookieRegister;

  if (tokenCookie.name == 'token') {
    await fetchUserData(ref);
    return AuthStatus.authenticated;
  } else {
    print('Token not found in cookie');
    return AuthStatus.notAuthenticated;
  }
}

Future<AuthStatus> fetchUserData(WidgetRef ref) async {
  try {
    final response = await DioConfig.dio?.get("/user/private");

    if (response?.statusCode == 200) {
      ref.read(userProvider.notifier).state = response?.data['user'];
      print(response?.data['user']);
      return AuthStatus.authenticated;
    } else {
      return AuthStatus.notAuthenticated; // Handle other status codes if necessary
    }
  } on DioException catch (error) {
    if (error.response?.statusCode == 401 || error.response?.statusCode == 400) {
      print('Unauthorized: Redirecting to sign-in.');
      return AuthStatus.notAuthenticated;
    } else if (error.response?.statusCode == 500) {
      // Retry fetching user data in case of a server error
      return await fetchUserData(ref);
    } else {
      print('Error fetching user data: ${error.message}');
      return AuthStatus.error;
    }
  }
}
