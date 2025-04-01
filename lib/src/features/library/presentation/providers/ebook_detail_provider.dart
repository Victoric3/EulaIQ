import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';
import 'package:eulaiq/src/features/library/data/repositories/library_repository.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EbookDetailState extends Equatable {
  final EbookModel? ebook;
  final bool isLoading;
  final bool isLiking;
  final bool isRating;
  final String? errorMessage;
  
  const EbookDetailState({
    this.ebook,
    this.isLoading = false,
    this.isLiking = false,
    this.isRating = false,
    this.errorMessage,
  });
  
  EbookDetailState copyWith({
    EbookModel? ebook,
    bool? isLoading,
    bool? isLiking,
    bool? isRating,
    String? errorMessage,
  }) {
    return EbookDetailState(
      ebook: ebook ?? this.ebook,
      isLoading: isLoading ?? this.isLoading,
      isLiking: isLiking ?? this.isLiking,
      isRating: isRating ?? this.isRating,
      errorMessage: errorMessage,  // Pass null to clear error
    );
  }
  
  @override
  List<Object?> get props => [ebook, isLoading, isLiking, isRating, errorMessage];
}

class EbookDetailNotifier extends StateNotifier<EbookDetailState> {
  final LibraryRepository _repository;
  Timer? _likeDebounceTimer;
  Timer? _rateDebounceTimer;
  bool _isSyncingWithServer = false; // Flag to track if we're syncing with server
  bool _isDisposed = false; // Track if the notifier is disposed
  
  EbookDetailNotifier(this._repository) : super(const EbookDetailState());
  
  @override
  void dispose() {
    _isDisposed = true; // Mark as disposed
    _likeDebounceTimer?.cancel();
    _rateDebounceTimer?.cancel();
    super.dispose();
  }
  
  Future<void> fetchEbookDetails({String? id, String? slug}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final ebook = await _repository.fetchEbookDetails(id: id, slug: slug);
      state = state.copyWith(ebook: ebook, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> toggleLike() async {
    if (state.ebook == null || _isDisposed) return;
    
    // Cancel any pending requests
    _likeDebounceTimer?.cancel();
    
    // Get current like status
    final bool currentLikeStatus = state.ebook!.isLikedByCurrentUser ?? false;
    final int currentLikeCount = state.ebook!.likeCount;
    
    // Optimistically update UI
    final updatedEbook = state.ebook!.copyWith(
      isLikedByCurrentUser: !currentLikeStatus,
      likeCount: currentLikeStatus 
          ? currentLikeCount - 1 
          : currentLikeCount + 1,
    );
    
    // Update the UI state
    if (!_isDisposed) {
      state = state.copyWith(ebook: updatedEbook);
    }
    
    // Debounce API call (300ms)
    _likeDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      // Safety check - don't proceed if disposed
      if (_isDisposed) return;
      
      try {
        // Flag that we're syncing with the server
        _isSyncingWithServer = true;
        
        // Call API
        final result = await _repository.likeEbook(state.ebook!.id);
        
        // Safety check again
        if (_isDisposed) return;
        
        // Get server status (what the server thinks the like state is)
        final serverLikeStatus = result['likeStatus'];
        
        // If there's a mismatch between UI and server, make another request 
        // to sync the server with our UI (not the other way around)
        if (serverLikeStatus != state.ebook!.isLikedByCurrentUser) {
          // Don't use recursive call - just make another API request
          await _repository.likeEbook(state.ebook!.id);
        }
        
        _isSyncingWithServer = false;
      } catch (e) {
        // Safety check
        if (_isDisposed) return;
        
        // ONLY on error, revert to original state
        final revertedEbook = state.ebook!.copyWith(
          isLikedByCurrentUser: currentLikeStatus,
          likeCount: currentLikeCount,
        );
        state = state.copyWith(ebook: revertedEbook);
        
        // Show error notification
        final notificationService = NotificationService();
        notificationService.showNotification(
          message: 'Error updating like status',
          type: NotificationType.error,
          duration: const Duration(seconds: 2),
        );
        
        _isSyncingWithServer = false;
      }
    });
  }

  Future<void> rateEbook(int rating) async {
    if (state.ebook == null || _isDisposed) return;
    
    // Cancel any pending requests
    _rateDebounceTimer?.cancel();
    
    // Get current rating values for revert if needed
    final double currentAvgRating = state.ebook!.averageRating;
    final int currentRatingCount = state.ebook!.ratingCount;
    final int? currentUserRating = state.ebook!.userRating;
    
    // Calculate new values for optimistic update
    final bool isUpdating = currentUserRating != null;
    final int newRatingCount = isUpdating ? currentRatingCount : currentRatingCount + 1;
    
    // Calculate new average (simplified)
    double newAvgRating;
    if (isUpdating) {
      // Remove old rating and add new one
      final double totalPoints = currentAvgRating * currentRatingCount;
      final double adjustedTotal = totalPoints - (currentUserRating) + rating;
      newAvgRating = adjustedTotal / currentRatingCount;
    } else {
      // Add new rating
      final double totalPoints = currentAvgRating * currentRatingCount;
      newAvgRating = (totalPoints + rating) / newRatingCount;
    }
    
    // Round to 1 decimal for UI
    newAvgRating = double.parse(newAvgRating.toStringAsFixed(1));
    
    // Update UI optimistically
    if (!_isDisposed) {
      final updatedEbook = state.ebook!.copyWith(
        userRating: rating,
        averageRating: newAvgRating,
        ratingCount: newRatingCount,
      );
      
      state = state.copyWith(ebook: updatedEbook);
    }
    
    // Debounce API call (500ms)
    _rateDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_isDisposed) return;
      
      try {
        _isSyncingWithServer = true;
        
        // Make the API call
        final response = await _repository.rateEbook(state.ebook!.id, rating);
        
        // No UI updates from server response - the UI is already updated optimistically
        // Only check if we need to re-sync
        if (response.userRating != state.ebook!.userRating && !_isSyncingWithServer) {
          // Make another request to sync server with UI
          Timer(const Duration(milliseconds: 100), () {
            rateEbook(state.ebook!.userRating!);
          });
        }
        
        _isSyncingWithServer = false;
      } catch (e) {
        // Safety check
        if (_isDisposed) return;
        
        // ONLY on error, revert to original state
        final revertedEbook = state.ebook!.copyWith(
          averageRating: currentAvgRating,
          ratingCount: currentRatingCount, 
          userRating: currentUserRating,
        );
        
        state = state.copyWith(ebook: revertedEbook);
        
        // Show error notification
        final notificationService = NotificationService();
        notificationService.showNotification(
          message: 'Error updating rating',
          type: NotificationType.error,
          duration: const Duration(seconds: 2),
        );
        
        _isSyncingWithServer = false;
      }
    });
  }
  
  Future<void> toggleReadingList() async {
    if (state.ebook == null || _isDisposed) return;
    
    // Get current reading list status
    final bool currentStatus = state.ebook!.isInReadingList ?? false;
    
    // Optimistically update UI
    final updatedEbook = state.ebook!.copyWith(
      isInReadingList: !currentStatus
    );
    
    // Update the UI state immediately
    state = state.copyWith(ebook: updatedEbook);
    
    try {
      // Call API
      final isInReadingList = await _repository.toggleReadingList(state.ebook!.id);
      
      // Safety check
      if (_isDisposed) return;
      
      // If server response doesn't match our optimistic update, correct the UI
      if (isInReadingList != updatedEbook.isInReadingList) {
        state = state.copyWith(
          ebook: updatedEbook.copyWith(isInReadingList: isInReadingList)
        );
      }
      
      // Show success notification
      NotificationService().showNotification(
        message: isInReadingList 
          ? 'Added to reading list' 
          : 'Removed from reading list',
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      // Revert on error
      if (!_isDisposed) {
        state = state.copyWith(
          ebook: state.ebook!.copyWith(isInReadingList: currentStatus)
        );
        
        // Show error notification
        NotificationService().showNotification(
          message: 'Failed to update reading list',
          type: NotificationType.error,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }
  
  void clearEbookDetails() {
    _likeDebounceTimer?.cancel();
    _rateDebounceTimer?.cancel();
    state = const EbookDetailState();
  }
}

final ebookDetailProvider = StateNotifierProvider.autoDispose<EbookDetailNotifier, EbookDetailState>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  return EbookDetailNotifier(repository);
});