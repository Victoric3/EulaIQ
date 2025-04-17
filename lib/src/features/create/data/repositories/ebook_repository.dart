import 'dart:async';
import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:file_picker/file_picker.dart';

enum ProcessingStatus {
  initial,
  uploading,
  processing,
  complete,
  error,
}

class EbookProcessingInfo {
  final String? ebookId;
  final double progress;
  final ProcessingStatus status;
  final String? errorMessage;

  EbookProcessingInfo({
    this.ebookId,
    this.progress = 0.0,
    this.status = ProcessingStatus.initial,
    this.errorMessage,
  });

  EbookProcessingInfo copyWith({
    String? ebookId,
    double? progress,
    ProcessingStatus? status,
    String? errorMessage,
  }) {
    return EbookProcessingInfo(
      ebookId: ebookId ?? this.ebookId,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EnhancedEbookProcessingInfo extends EbookProcessingInfo {
  final Map<String, dynamic>? fullEbookData;

  EnhancedEbookProcessingInfo({
    String? ebookId,
    double progress = 0.0,
    ProcessingStatus status = ProcessingStatus.initial,
    String? errorMessage,
    this.fullEbookData,
  }) : super(
          ebookId: ebookId,
          progress: progress,
          status: status,
          errorMessage: errorMessage,
        );

  @override
  EnhancedEbookProcessingInfo copyWith({
    String? ebookId,
    double? progress,
    ProcessingStatus? status,
    String? errorMessage,
    Map<String, dynamic>? fullEbookData,
  }) {
    return EnhancedEbookProcessingInfo(
      ebookId: ebookId ?? this.ebookId,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      fullEbookData: fullEbookData ?? this.fullEbookData,
    );
  }
}

class EbookRepository {
  // Upload file and start processing
  Future<EbookProcessingInfo> uploadEbook({
    required PlatformFile file,
    required Function(double) onProgressUpdate,
    CancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    try {
      // Create form data
      final formData = FormData();
      
      // Add file to form data
      if (file.bytes != null) {
        // Web platform (file.bytes available)
        formData.files.add(
          MapEntry(
            'file',
            MultipartFile.fromBytes(
              file.bytes!,
              filename: file.name,
            ),
          ),
        );
      } else if (file.path != null) {
        // Mobile/desktop platforms (file.path available)
        formData.files.add(
          MapEntry(
            'file',
            await MultipartFile.fromFile(
              file.path!,
              filename: file.name,
            ),
          ),
        );
      } else {
        throw Exception('Cannot read file data');
      }
      
      // Upload file with timeout
      final response = await DioConfig.dio?.post(
        '/ebook/handlegenerate',
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
        onSendProgress: (sent, total) {
          final progress = sent / total;
          onProgressUpdate(progress);
        },
      );
      
      // Properly handle API response with type safety
      if (response?.statusCode == 202 || response?.statusCode == 200) {
        // Extract ebookId with type safety
        String? ebookId;
        
        if (response?.data['ebookId'] is String) {
          ebookId = response?.data['ebookId'];
        } else if (response?.data['ebookId'] != null) {
          // Convert to string if it's not null but not a string
          ebookId = response?.data['ebookId'].toString();
        } else if (response?.data['ebook']?['id'] != null) {
          // Try to get from nested object
          ebookId = response?.data['ebook']['id'].toString();
        }
        
        // Safely check processing status
        String statusStr = 'processing';
        if (response?.data['status'] is String) {
          statusStr = response!.data['status'];
        } else if (response?.data['ebook']?['status'] is String) {
          statusStr = response!.data['ebook']['status'];
        }

        // Map string status to enum
        ProcessingStatus processingStatus;
        switch (statusStr.toLowerCase()) {
          case 'complete':
            processingStatus = ProcessingStatus.complete;
            break;
          case 'error':
            processingStatus = ProcessingStatus.error;
            break;
          default:
            processingStatus = ProcessingStatus.processing;
        }
        
        // Create an extended version of EbookProcessingInfo that includes the full response
        return EnhancedEbookProcessingInfo(
          ebookId: ebookId,
          progress: 1.0,  // Upload complete
          status: processingStatus,
          fullEbookData: response?.data, // Store the complete response
        );
      } else {
        return EbookProcessingInfo(
          status: ProcessingStatus.error,
          errorMessage: 'Upload failed with status: ${response?.statusCode}',
        );
      }
    } on DioException catch (e) {
      // Existing error handling code...
      if (e.type == DioExceptionType.cancel) {
        return EbookProcessingInfo(
          status: ProcessingStatus.error,
          errorMessage: 'Upload cancelled',
        );
      } else if (e.type == DioExceptionType.connectionTimeout || 
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        return EbookProcessingInfo(
          status: ProcessingStatus.error,
          errorMessage: 'Upload timed out. Please check your connection and try again.',
        );
      }
      
      return EbookProcessingInfo(
        status: ProcessingStatus.error,
        errorMessage: e.response?.data?['errorMessage'] ?? e.message ?? 'Upload failed',
      );
    } catch (e) {
      return EbookProcessingInfo(
        status: ProcessingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Check processing status - uses GET /ebook/:ebookId/status
  Future<Map<String, dynamic>> checkEbookStatus(String ebookId) async {
    try {
      final response = await DioConfig.dio?.get('/ebook/$ebookId/status');
      
      if (response?.data['status'] == 'success') {
        final data = response?.data['data'];
        
        // Safe handling for percent calculation
        double progressPercent = 0.0;
        try {
          if (data['progress']?['percent'] != null) {
            var percent = data['progress']['percent'];
            if (percent is int) {
              progressPercent = percent / 100.0;
            } else if (percent is double) {
              progressPercent = percent / 100.0;
            } else if (percent is String) {
              progressPercent = double.tryParse(percent)! / 100.0;
            }
          }
        } catch (_) {
          progressPercent = 0.0;
        }

        // Safe access with type conversion for other fields
        return {
          'status': data['status']?.toString() ?? 'processing',
          'progress': progressPercent,
          'currentStep': data['currentStep']?.toString(),
          'timeRemaining': _safelyParseInt(data['timeInfo']?['estimatedTimeRemaining']),
          'hasErrors': data['hasErrors'] == true,
          'ebook': data
        };
      } else {
        throw Exception('Failed to get status');
      }
    } catch (e) {
      throw Exception('Error checking status: $e');
    }
  }

  // Helper method to safely parse integers
  int? _safelyParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // Get processing logs - uses GET /ebook/:ebookId/logs
  Future<List<Map<String, dynamic>>> getProcessingLogs(String ebookId) async {
    try {
      // Using GET method as per the correct endpoint
      final response = await DioConfig.dio?.get('/ebook/$ebookId/logs');
      
      if (response?.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response?.data['data']['logs']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // DEPRECATED: Remove this method as it's redundant with checkEbookStatus
  // This method is kept for backward compatibility but should be removed
  @deprecated
  Future<EbookProcessingInfo> checkProcessingStatus(String ebookId) async {
    try {
      // Call the new method and map the response
      final statusData = await checkEbookStatus(ebookId);
      
      final status = statusData['status'] as String?;
      final progress = statusData['progress'] as double?;
      final hasErrors = statusData['hasErrors'] as bool?;
      
      if (status == 'complete') {
        return EbookProcessingInfo(
          ebookId: ebookId,
          progress: 1.0,
          status: ProcessingStatus.complete,
        );
      } else if (status == 'error') {
        return EbookProcessingInfo(
          ebookId: ebookId,
          status: ProcessingStatus.error,
          errorMessage: 'Processing failed',
        );
      } else {
        // Processing or other status
        return EbookProcessingInfo(
          ebookId: ebookId,
          progress: progress ?? 0.0,
          status: ProcessingStatus.processing,
          errorMessage: hasErrors == true ? 'Processing encountered some issues' : null,
        );
      }
    } catch (e) {
      // Don't report error here, just return current status
      return EbookProcessingInfo(
        ebookId: ebookId,
        status: ProcessingStatus.processing,
        errorMessage: e.toString(),
      );
    }
  }

  // Continue processing method uses the correct endpoint
  Future<EbookProcessingInfo> continueProcessing(String ebookId) async {
    print("triggered");
    try {
      // Updated to use the correct endpoint
      final response = await DioConfig.dio?.post('/ebook/$ebookId/continue');
      
      if (response?.statusCode == 202) {
        return EbookProcessingInfo(
          ebookId: ebookId,
          status: ProcessingStatus.processing,
        );
      } else {
        return EbookProcessingInfo(
          ebookId: ebookId,
          status: ProcessingStatus.error,
          errorMessage: 'Failed to continue processing',
        );
      }
    } catch (e) {
      return EbookProcessingInfo(
        ebookId: ebookId,
        status: ProcessingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}