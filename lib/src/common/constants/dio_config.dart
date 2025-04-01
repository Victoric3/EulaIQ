import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:eulaiq/src/common/services/session_expiration_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eulaiq/src/common/common.dart';
import 'dart:io';

class DioConfig {
  static Dio? dio;
  static PersistCookieJar cookieJar = PersistCookieJar();

  static Future<void> setupDio() async {
    // Get the application documents directory

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = '${appDocDir.path}/.cookies';
    final dir = Directory(appDocPath);
    if (!await dir.exists()) {
      // Ensure the directory exists
      dir.createSync(recursive: true);
    }

    // Initialize PersistCookieJar with the directory path
    cookieJar = PersistCookieJar(storage: FileStorage(appDocPath));

    dio = Dio(
      BaseOptions(
        baseUrl: "$baseURL/$serverVersion",
      ),
    );
    dio?.interceptors.add(CookieManager(cookieJar));

    // Add interceptor for authentication errors
    dio?.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401) {
            print('401 Unauthorized detected: ${error.response?.data}');
            
            // Clear the cookies right away
            try {
              await cookieJar.deleteAll();
              print('🔴 Cookies cleared successfully');
            } catch (e) {
              print('🔴 Error clearing cookies: $e');
            }
            
            // Notify the app about session expiration
            // Use a slight delay to ensure the UI is ready
            Future.delayed(const Duration(milliseconds: 500), () {
              SessionExpirationHandler.notifySessionExpired();
            });
          }
          return handler.next(error);
        },
      ),
    );
  }
}