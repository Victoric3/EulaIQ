import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:eulaiq/src/features/comments/data/models/comment_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommentRepository {
  final Ref ref;
  
  CommentRepository(this.ref);
  
  // Get current user ID for like status checks
  String? get _currentUserId => ref.read(userProvider).valueOrNull?.id;

  // Get all top-level comments for a story/ebook
  Future<Map<String, dynamic>> getAllComments(String storyId, {int page = 1}) async {
    try {
      final response = await DioConfig.dio?.get(
        '/comment/$storyId/getAllComment',
        queryParameters: {'page': page},
      );
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        final List<CommentModel> comments = (response?.data['data'] as List?)
            ?.map((json) => CommentModel.fromJson(json, currentUserId: _currentUserId))
            .toList() ?? [];
            
        final pagination = CommentPaginationModel.fromJson({
          ...response?.data['pagination'] ?? {},
          'count': response?.data['count'] ?? 0,
        });
        
        return {
          'comments': comments,
          'pagination': pagination,
        };
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to fetch comments');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching comments: $e');
    }
  }
  
  // Get replies for a specific comment
  Future<Map<String, dynamic>> getReplies(String commentId, {int page = 1, int? pageSize}) async {
    try {
      final response = await DioConfig.dio?.get(
        '/comment/$commentId/replies',
        queryParameters: {
          'page': page,
          'pageSize': pageSize ?? 3, // Default to 3 for TikTok-style (was 15)
        },
      );
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        final List<CommentModel> replies = (response?.data['data'] as List?)
            ?.map((json) => CommentModel.fromJson(json, currentUserId: _currentUserId))
            .toList() ?? [];
            
        final pagination = CommentPaginationModel.fromJson(
          response?.data['pagination'] ?? {}
        );
        
        return {
          'replies': replies,
          'pagination': pagination,
        };
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to fetch replies');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching replies: $e');
    }
  }
  
  // Add a new comment or reply
  Future<CommentModel> addComment(String storyId, String content, {String? parentCommentId}) async {
    try {
      final response = await DioConfig.dio?.post(
        '/comment/$storyId/addComment',
        data: {
          'content': content,
          'parentCommentId': parentCommentId,
        },
      );
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        return CommentModel.fromJson(
          response?.data['data'], 
          currentUserId: _currentUserId
        );
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to add comment');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error adding comment: $e');
    }
  }
  
  // Like/unlike a comment
  Future<Map<String, dynamic>> toggleCommentLike(String commentId) async {
    try {
      final response = await DioConfig.dio?.post('/comment/$commentId/like');
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        return {
          'likeStatus': response?.data['likeStatus'] ?? false,
          'data': response?.data['data'],
        };
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to like comment');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error liking comment: $e');
    }
  }
  
  // Check if user has liked a comment
  Future<bool> getCommentLikeStatus(String commentId) async {
    try {
      final response = await DioConfig.dio?.post('/comment/$commentId/getCommentLikeStatus');
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        return response?.data['likeStatus'] ?? false;
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to get like status');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting like status: $e');
    }
  }
}

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository(ref);
});