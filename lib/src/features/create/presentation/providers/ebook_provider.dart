import 'dart:async';
import 'dart:ui'; // Add this import for VoidCallback
import 'package:dio/dio.dart';
import 'package:eulaiq/src/features/create/data/repositories/ebook_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for the selected file
final selectedFileProvider = StateProvider<PlatformFile?>((ref) => null);

// Enhanced processing info with more details from checkEbookStatus
class EnhancedEbookProcessingInfo extends EbookProcessingInfo {
  final String? currentStep;
  final int? timeRemaining; // in seconds
  final bool hasErrors;
  final Map<String, dynamic>? fullEbookData;
  final bool completionHandled; 

  EnhancedEbookProcessingInfo({
    super.ebookId,
    super.progress = 0.0,
    super.status = ProcessingStatus.initial,
    super.errorMessage,
    this.currentStep,
    this.timeRemaining,
    this.hasErrors = false,  // Default to false
    this.fullEbookData,
    this.completionHandled = false,
  });

  @override
  EnhancedEbookProcessingInfo copyWith({
    String? ebookId,
    double? progress,
    ProcessingStatus? status,
    String? errorMessage,
    String? currentStep,
    int? timeRemaining,
    bool? hasErrors,
    Map<String, dynamic>? fullEbookData,
  }) {
    return EnhancedEbookProcessingInfo(
      ebookId: ebookId ?? this.ebookId,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentStep: currentStep ?? this.currentStep,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      hasErrors: hasErrors ?? this.hasErrors,
      fullEbookData: fullEbookData ?? this.fullEbookData,
    );
  }
}

// Provider for the ebook repository
final ebookRepositoryProvider = Provider<EbookRepository>((ref) {
  return EbookRepository();
});

// Provider for the ebook processing info
final ebookProcessingProvider = StateNotifierProvider<EbookProcessingNotifier, EnhancedEbookProcessingInfo>((ref) {
  final repository = ref.watch(ebookRepositoryProvider);
  return EbookProcessingNotifier(repository);
});

// Add a global provider to track background processing status

// Global processing status provider that persists across screens
final backgroundProcessingProvider = Provider<bool>((ref) {
  final processingState = ref.watch(ebookProcessingProvider);
  return processingState.status == ProcessingStatus.processing;
});

class EbookProcessingNotifier extends StateNotifier<EnhancedEbookProcessingInfo> {
  final EbookRepository _repository;
  Timer? _pollingTimer;
  bool _pollingActive = false;

  EbookProcessingNotifier(this._repository) : super(EnhancedEbookProcessingInfo());

  // Add getter to check if polling is active
  bool get isPolling => _pollingActive;

  Future<void> uploadFile(
    PlatformFile file, {
    CancelToken? cancelToken,
    Duration timeout = const Duration(minutes: 5),
    VoidCallback? onTimeout,
  }) async {
    // Update state to uploading
    state = state.copyWith(status: ProcessingStatus.uploading);
    
    try {
      // Call repository to upload file with timeout and cancel token
      final result = await _repository.uploadEbook(
        file: file,
        onProgressUpdate: (progress) {
          // Update progress as file uploads
          state = state.copyWith(progress: progress);
        },
        cancelToken: cancelToken,
        timeout: timeout,
      ).timeout(
        timeout,
        onTimeout: () {
          if (onTimeout != null) onTimeout();
          throw TimeoutException('Upload timed out');
        },
      );
      
      // Update state with result but preserve all fields
      if (result is EnhancedEbookProcessingInfo) {
        // If we get an enhanced info with full data, use it directly
        state = result;
      } else {
        // Otherwise fall back to creating our own
        state = EnhancedEbookProcessingInfo(
          ebookId: result.ebookId,
          progress: result.progress,
          status: result.status,
          errorMessage: result.errorMessage,
          currentStep: null, // Explicitly null to trigger initial state
          hasErrors: false,
          fullEbookData: result.ebookId != null ? {
            'id': result.ebookId,
            'status': 'processing'
          } : null,
        );
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        // User cancelled - reset state
        state = EnhancedEbookProcessingInfo();
      } else {
        // Other errors - set error state
        state = state.copyWith(
          status: ProcessingStatus.error,
          errorMessage: e.toString(),
        );
      }
      rethrow; // Allow UI to handle the exception
    }
  }

  void startPolling() {
    // Cancel any existing timer
    _pollingTimer?.cancel();
    
    // Only start polling if we have an ebookId
    if (state.ebookId == null) return;
    
    // Check immediately first
    _checkStatus();
    
    // Mark polling as active
    _pollingActive = true;
    
    // Start polling every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    if (state.ebookId == null) return;
    
    try {
      // Use checkEbookStatus for detailed information
      final statusData = await _repository.checkEbookStatus(state.ebookId!);
      
      // Map the status to our ProcessingStatus enum
      ProcessingStatus mappedStatus;
      final statusString = statusData['status'] as String? ?? 'processing';
      
      switch (statusString) {
        case 'complete':
          mappedStatus = ProcessingStatus.complete;
          _stopPolling(); // Stop polling when complete
          break;
        case 'error':
          mappedStatus = ProcessingStatus.error;
          _stopPolling(); // Stop polling on error
          break;
        case 'processing':
        default:
          mappedStatus = ProcessingStatus.processing;
      }
      
      // Ensure we have a double for progress
      double progress = 0.0;
      final rawProgress = statusData['progress'];
      if (rawProgress is double) {
        progress = rawProgress;
      } else if (rawProgress is int) {
        progress = rawProgress.toDouble();
      } else {
        // Fallback to current state's progress
        progress = state.progress;
      }
      
      // Safely handle timeRemaining
      int? timeRemaining;
      final rawTimeRemaining = statusData['timeRemaining'];
      if (rawTimeRemaining is int) {
        timeRemaining = rawTimeRemaining;
      } else if (rawTimeRemaining is String) {
        try {
          timeRemaining = int.parse(rawTimeRemaining);
        } catch (_) {
          timeRemaining = null;
        }
      }
      
      // Update state with enhanced details
      state = EnhancedEbookProcessingInfo(
        ebookId: state.ebookId,
        progress: progress,
        status: mappedStatus,
        errorMessage: statusData['hasErrors'] == true ? 'Processing encountered some issues' : null,
        currentStep: statusData['currentStep'] as String?,
        timeRemaining: timeRemaining,
        hasErrors: statusData['hasErrors'] == true,
        fullEbookData: statusData['ebook'] as Map<String, dynamic>?,
      );
      
      // For additional logging if needed
      if (statusData['hasErrors'] == true) {
        _fetchProcessingLogs();
      }
    } catch (e) {
      // Just keep the current state but log the error
      print('Error checking ebook status: $e');
    }
  }
  
  Future<void> _fetchProcessingLogs() async {
    if (state.ebookId == null) return;
    
    try {
      await _repository.getProcessingLogs(state.ebookId!);
      // Could save logs to state if needed
    } catch (_) {
      // Ignore errors, just trying to get additional info
    }
  }
  
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingActive = false;
  }
  
  // Add this method to the EbookProcessingNotifier class

  // Method to properly reset state to initial
  void resetState() {
    _stopPolling();
    
    // Important: Create a completely new instance instead of modifying the existing one
    // This ensures a clean state reset without any transition issues
    state = EnhancedEbookProcessingInfo();
    
    // Add a slight delay to ensure UI updates properly
    Future.delayed(const Duration(milliseconds: 50), () {
      state = EnhancedEbookProcessingInfo();
    });
  }
  
  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}