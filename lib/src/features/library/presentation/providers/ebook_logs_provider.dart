import 'dart:async';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/create/data/repositories/ebook_repository.dart';
import 'package:eulaiq/src/features/create/presentation/providers/ebook_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State class for logs
class EbookLogsState {
  final List<Map<String, dynamic>> logs;
  final bool isLoading;
  final String? errorMessage;
  final bool isPolling;
  
  EbookLogsState({
    this.logs = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isPolling = false,
  });
  
  EbookLogsState copyWith({
    List<Map<String, dynamic>>? logs,
    bool? isLoading,
    String? errorMessage,
    bool? isPolling,
  }) {
    return EbookLogsState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

// Notifier for handling logs
class EbookLogsNotifier extends StateNotifier<EbookLogsState> {
  final EbookRepository _repository;
  final String ebookId;
  Timer? _pollingTimer;
  bool _isDisposed = false;
  
  EbookLogsNotifier(this._repository, this.ebookId) : super(EbookLogsState()) {
    fetchLogs();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _stopPolling();
    super.dispose();
  }
  
  Future<void> fetchLogs() async {
    if (_isDisposed) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final logs = await _repository.getProcessingLogs(ebookId);
      if (_isDisposed) return;
      
      state = state.copyWith(
        logs: logs,
        isLoading: false,
      );
    } catch (e) {
      if (_isDisposed) return;
      
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load logs: ${e.toString()}',
      );
    }
  }
  
  Future<void> continueProcessing() async {
    if (_isDisposed) return;
    
    try {
      final result = await _repository.continueProcessing(ebookId);
      
      if (_isDisposed) return;
      
      if (result.status == ProcessingStatus.processing) {
        NotificationService().showNotification(
          message: 'Processing continued successfully',
          type: NotificationType.success,
          duration: const Duration(seconds: 2),
        );
        
        // Start polling for updates
        startPolling();
      } else {
        NotificationService().showNotification(
          message: result.errorMessage ?? 'Failed to continue processing',
          type: NotificationType.error,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (_isDisposed) return;
      
      NotificationService().showNotification(
        message: 'Failed to continue processing: ${e.toString()}',
        type: NotificationType.error,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  void startPolling() {
    if (_isDisposed) return;
    
    // Cancel any existing timer
    _pollingTimer?.cancel();
    
    // Start polling every 3 seconds
    state = state.copyWith(isPolling: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchLogs();
    });
  }
  
  void _stopPolling() {
    _pollingTimer?.cancel();
    if (!_isDisposed) {
      state = state.copyWith(isPolling: false);
    }
  }
  
  void togglePolling() {
    if (state.isPolling) {
      _stopPolling();
    } else {
      startPolling();
    }
  }
}

// Provider for logs
final ebookLogsProvider = StateNotifierProvider.family<EbookLogsNotifier, EbookLogsState, String>(
  (ref, ebookId) => EbookLogsNotifier(
    ref.watch(ebookRepositoryProvider),
    ebookId,
  ),
);