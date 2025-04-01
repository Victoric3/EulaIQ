import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Add this import

class LibraryRepository {
  final Ref ref; // Add this field
  
  // Add constructor to receive ref
  LibraryRepository(this.ref);

  Future<Map<String, dynamic>> fetchUserEbooks({
    int page = 1,
    int limit = 10,
    String? searchQuery,
    String? filterBy,
  }) async {
    try {
      // Build query parameters
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
      };
      
      // Add optional parameters if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }
      
      if (filterBy != null && filterBy != 'all' && filterBy.isNotEmpty) {
        queryParams['filter'] = filterBy;
      }
      
      // Make API call - POST is correct as confirmed
      final response = await DioConfig.dio?.post(
        '/ebook/foruser',
        queryParameters: queryParams,
      );

      if (response?.statusCode == 200) {
        // In the repository, add debug logging to see the actual response structure:
       
        
        // Safe parsing of the ebooks array with null check
        final dynamic ebooksData = response?.data['data'];
        final List<EbookModel> ebooks = ebooksData is List
            ? ebooksData.map((json) => EbookModel.fromJson(json)).toList()
            : []; // Return empty list if null or not a list

        // Safe parsing of pagination with null check
        final paginationData = response?.data['pagination'];
        final PaginationModel pagination = paginationData != null
            ? PaginationModel.fromJson(paginationData)
            : const PaginationModel(currentPage: 1, totalPages: 1, totalEbooks: 0, hasMore: false);

        return {
          'ebooks': ebooks,
          'pagination': pagination,
        };
      } else {
        throw Exception('Failed to fetch ebooks: ${response?.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching ebooks: $e');
    }
  }

  Future<EbookModel> fetchEbookDetails({String? id, String? slug}) async {
    // Get the current user model
    final userModel = ref.read(userProvider).valueOrNull;
    final String? currentUserId = userModel?.id;

    try {
      if (id == null && slug == null) {
        throw Exception('Either ID or slug must be provided');
      }

      final String endpoint = id != null 
        ? '/ebook/${slug ?? "detail"}?id=$id' 
        : '/ebook/$slug';
      
      final response = await DioConfig.dio?.get(endpoint);
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        final dynamic ebookData = response?.data['data'];
        
        if (ebookData == null) {
          throw Exception('Ebook data not found');
        }
        
        // Create a copy of the ebook data to avoid modifying the original
        final Map<String, dynamic> processedData = Map<String, dynamic>.from(ebookData);
        
        // Check if the eBook is in the user's readList - server might already provide this,
        // but we'll add a manual check as a fallback
        if (userModel != null) {
          // If the API hasn't already populated isInReadingList
          if (processedData['isInReadingList'] == null) {
            // Check with backend to see if this book is in reading list
            try {
              final checkResponse = await DioConfig.dio?.get('/user/readList/check/$id');
              if (checkResponse?.statusCode == 200) {
                processedData['isInReadingList'] = checkResponse?.data['isInReadList'] ?? false;
              }
            } catch (e) {
              // Silently fail the check - we'll default to not in reading list
              print('Error checking reading list status: $e');
              processedData['isInReadingList'] = false;
            }
          }
        }
        
        return EbookModel.fromJson(processedData, currentUserId: currentUserId);
      } else {
        throw Exception(
          response?.data?['message'] ?? 'Failed to fetch ebook details: ${response?.statusCode}'
        );
      }
    } catch (e) {
      throw Exception('Error fetching ebook details: $e');
    }
  }

  Future<Map<String, dynamic>> likeEbook(String id) async {
    try {
      final response = await DioConfig.dio?.post('/ebook/$id/like');
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        return {
          'likeStatus': response?.data['likeStatus'] ?? false,
          'data': response?.data['data'] ?? {'likeCount': 0},
        };
      } else {
        throw Exception(response?.data?['errorMessage'] ?? 'Failed to like ebook');
      }
    } on DioException catch (e) {
      // Special handling for network errors to enable offline-first behavior
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        // Return optimistic data - we'll sync later
        return {
          'likeStatus': true, // Assume success for optimistic UI
          'data': {'likeCount': 0}, // This will be ignored by the provider
          'offline': true
        };
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error liking ebook: $e');
    }
  }

  Future<EbookModel> rateEbook(String id, int rating) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }
      
      final userModel = ref.read(userProvider).valueOrNull;
      final String? currentUserId = userModel?.id;
      
      final response = await DioConfig.dio?.put('/ebook/$id/rate', 
        data: {'rating': rating}
      );
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        // Create a minimal model with just the rating data
        final responseData = response?.data['data'];
        
        // Use the current ebook data from cache but update rating info
        return EbookModel.fromJson({
          '_id': id,
          'averageRating': responseData['averageRating'] ?? 0.0,
          'ratingCount': responseData['ratingCount'] ?? 0,
          // Add minimal required fields
          'title': '',
          'author': '',
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'complete',
        }, currentUserId: currentUserId);
      } else {
        throw Exception(response?.data?['message'] ?? 'Failed to rate ebook');
      }
    } on DioException catch (e) {
      // Handle offline behavior for rating too
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        // Return minimal model for optimistic UI
        return EbookModel.fromJson({
          '_id': id,
          'averageRating': 0.0, // Will be ignored
          'ratingCount': 0, // Will be ignored
          'title': '',
          'author': '',
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'complete',
        });
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error rating ebook: $e');
    }
  }

  // Add this method to the LibraryRepository class
  Future<bool> toggleReadingList(String ebookId) async {
    try {
      final response = await DioConfig.dio?.post('/user/$ebookId/addStoryToReadList');
      print("$response, the response");
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        return response?.data['status'] ?? false;
      } else {
        throw Exception('Failed to update reading list: ${response?.data['message']}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error updating reading list: $e');
    }
  }

  // Method to fetch user's favorites (liked stories)
  Future<Map<String, dynamic>> fetchUserFavorites({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Build query parameters
      final Map<String, dynamic> queryParams = {
        'page': page,
        'pageSize': limit, // Note: backend uses pageSize instead of limit
      };

      // Make API call to get user favorites
      final response = await DioConfig.dio?.get(
        '/user/favorites',
        queryParameters: queryParams,
      );

      if (response?.statusCode == 200) {
        // Parse the ebooks data
        final dynamic ebooksData = response?.data['data'];
        final List<EbookModel> ebooks = ebooksData is List
            ? ebooksData.map((json) => EbookModel.fromJson(json)).toList()
            : [];

        // Parse the pagination data
        final paginationData = response?.data['pagination'];
        final PaginationModel pagination = paginationData != null
            ? PaginationModel(
                currentPage: paginationData['currentPage'] ?? 1,
                totalPages: paginationData['totalPages'] ?? 1,
                totalEbooks: paginationData['totalItems'] ?? 0,
                hasMore: (paginationData['currentPage'] ?? 1) < (paginationData['totalPages'] ?? 1),
              )
            : const PaginationModel(currentPage: 1, totalPages: 1, totalEbooks: 0, hasMore: false);

        return {
          'ebooks': ebooks,
          'pagination': pagination,
        };
      } else {
        throw Exception('Failed to fetch favorites: ${response?.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching favorites: $e');
    }
  }

  // Method to fetch user's reading list
  Future<Map<String, dynamic>> fetchUserReadList({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Build query parameters
      final Map<String, dynamic> queryParams = {
        'page': page,
        'pageSize': limit, // Note: backend uses pageSize instead of limit
      };

      // Make API call to get user reading list
      final response = await DioConfig.dio?.get(
        '/user/readList',
        queryParameters: queryParams,
      );

      if (response?.statusCode == 200) {
        // Parse the ebooks data
        final dynamic ebooksData = response?.data['data'];
        final List<EbookModel> ebooks = ebooksData is List
            ? ebooksData.map((json) => EbookModel.fromJson(json)).toList()
            : [];

        // Parse the pagination data
        final paginationData = response?.data['pagination'];
        final PaginationModel pagination = paginationData != null
            ? PaginationModel(
                currentPage: paginationData['currentPage'] ?? 1,
                totalPages: paginationData['totalPages'] ?? 1,
                totalEbooks: paginationData['totalItems'] ?? 0,
                hasMore: (paginationData['currentPage'] ?? 1) < (paginationData['totalPages'] ?? 1),
              )
            : const PaginationModel(currentPage: 1, totalPages: 1, totalEbooks: 0, hasMore: false);

        return {
          'ebooks': ebooks,
          'pagination': pagination,
        };
      } else {
        throw Exception('Failed to fetch reading list: ${response?.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching reading list: $e');
    }
  }

  // Add this method to LibraryRepository class
  Future<Uint8List> fetchEbookFile(String fileUrl, {Function(double, int)? onProgress}) async {
    try {
      // Use Dio to download the file with query parameters and track progress
      final response = await DioConfig.dio?.get(
        '/ebook/ebookfile/fetch',
        queryParameters: {'fileUrl': fileUrl},
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            // Report both progress percentage and bytes received
            onProgress(received / total, received);
          }
        }
      );
      
      if (response?.statusCode == 200) {
        return response!.data as Uint8List;
      } else {
        throw Exception('Failed to fetch document: ${response?.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error while downloading document: ${e.message}');
    } catch (e) {
      throw Exception('Error accessing document: $e');
    }
  }
}