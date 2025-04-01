import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';

class QuizRepository {
  // Using DioConfig directly like auth_handler.dart and ebook_repository.dart
  Future<Map<String, dynamic>> getEbookQuizSummary(String ebookId) async {
    try {
      final response = await DioConfig.dio?.get('/question/$ebookId');
      
      if (response?.statusCode == 200) {
        // Fix: Dio Response uses 'data' not 'body'
        final responseData = response!.data;
        if (responseData['success'] == true) {
          return responseData['data'];
        } else {
          throw Exception(responseData['message'] ?? 'Failed to fetch quiz data');
        }
      } else {
        throw Exception('Failed to fetch quiz data: ${response?.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['errorMessage'] ?? 'Error fetching quiz data');
    } catch (e) {
      throw Exception('Error fetching quiz data: $e');
    }
  }
}