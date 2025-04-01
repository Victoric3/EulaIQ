import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserRepository {
  final SharedPreferences prefs;
  static const String userKey = 'user_data';

  UserRepository({required this.prefs});

  Future<UserModel?> fetchAndCacheUserData() async {
    try {
      final response = await DioConfig.dio?.get('/auth/private');
      
      // First check if response itself is not null
      if (response == null) {
        print('API response is null');
        return null;
      }

      // Then check response status
      if (response.statusCode != 200) {
        print('API returned status code: ${response.statusCode}');
        return null;
      }

      // Check if response data exists
      final responseData = response.data;
      if (responseData == null) {
        print('API response body is null');
        return null;
      }
      
      // Determine the correct data structure
      Map<String, dynamic>? userData;
      
      if (responseData is Map<String, dynamic>) {
        // Check if data is nested in a "user" field (matching backend response structure)
        if (responseData.containsKey('user')) {
          final userField = responseData['user'];
          if (userField is Map<String, dynamic>) {
            userData = userField;
          } else if (userField == null) {
            print('API response user field is null');
            return null;
          } else {
            print('API response user field is not an object: ${userField.runtimeType}');
            return null;
          }
        } else {
          // Try direct response as fallback
          userData = responseData;
        }
      } else {
        print('API response is not a JSON object: ${responseData.runtimeType}');
        return null;
      }
      
      final userModel = UserModel.fromJson(userData);
      await cacheUserData(userModel);
      return userModel;
          
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> cacheUserData(UserModel user) async {
    await prefs.setString(userKey, user.toJsonString());
  }

  UserModel? getCachedUser() {
    final userStr = prefs.getString(userKey);
    if (userStr != null && userStr.isNotEmpty) {
      try {
        return UserModel.fromJsonString(userStr);
      } catch (e) {
        print('Error parsing cached user data: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> clearUserData() async {
    await prefs.remove(userKey);
  }
}