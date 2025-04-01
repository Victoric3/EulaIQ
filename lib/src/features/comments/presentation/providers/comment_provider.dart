import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/comments/data/models/comment_model.dart';
import 'package:eulaiq/src/features/comments/data/repositories/comment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State for all comments for an eBook
class CommentsState extends Equatable {
  final bool isLoading;
  final bool isLoadingMore;
  final List<CommentModel> comments;
  final CommentPaginationModel pagination;
  final String? errorMessage;
  
  const CommentsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.comments = const [],
    this.pagination = const CommentPaginationModel(),
    this.errorMessage,
  });
  
  CommentsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<CommentModel>? comments,
    CommentPaginationModel? pagination,
    String? errorMessage,
  }) {
    return CommentsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      comments: comments ?? this.comments,
      pagination: pagination ?? this.pagination,
      errorMessage: errorMessage,
    );
  }
  
  @override
  List<Object?> get props => [isLoading, isLoadingMore, comments, pagination, errorMessage];
}

// Provider for Comments
class CommentsNotifier extends StateNotifier<CommentsState> {
  final CommentRepository _repository;
  final String storyId;
  bool _isDisposed = false;
  final Map<String, Timer> _likeDebounceTimers = {};
  
  CommentsNotifier(this._repository, this.storyId) : super(const CommentsState());
  
  @override
  void dispose() {
    _isDisposed = true;
    _likeDebounceTimers.forEach((key, timer) => timer.cancel());
    _likeDebounceTimers.clear();
    super.dispose();
  }
  
  // Fetch comments (initial or refresh)
  Future<void> fetchComments() async {
    if (_isDisposed) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final result = await _repository.getAllComments(storyId);
      if (_isDisposed) return;
      
      state = state.copyWith(
        isLoading: false,
        comments: result['comments'],
        pagination: result['pagination'],
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Load more comments (pagination)
  Future<void> loadMoreComments() async {
    if (_isDisposed || !state.pagination.hasMore || state.isLoadingMore) return;
    
    state = state.copyWith(isLoadingMore: true);
    
    try {
      final nextPage = state.pagination.currentPage + 1;
      final result = await _repository.getAllComments(storyId, page: nextPage);
      if (_isDisposed) return;
      
      state = state.copyWith(
        isLoadingMore: false,
        comments: [...state.comments, ...result['comments']],
        pagination: result['pagination'],
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Add a new comment
  Future<void> addComment(String content) async {
    if (_isDisposed || content.trim().isEmpty) return;
    
    try {
      final newComment = await _repository.addComment(storyId, content);
      if (_isDisposed) return;
      
      // Optimistically update state
      state = state.copyWith(
        comments: [newComment, ...state.comments],
        pagination: CommentPaginationModel(
          currentPage: state.pagination.currentPage,
          totalPages: state.pagination.totalPages,
          totalComments: state.pagination.totalComments + 1,
          hasMore: state.pagination.hasMore,
        ),
      );
      
      NotificationService().showNotification(
        message: 'Comment added successfully',
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (_isDisposed) return;
      
      NotificationService().showNotification(
        message: 'Failed to add comment',
        type: NotificationType.error,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  // Toggle like for a comment
  Future<void> toggleCommentLike(String commentId) async {
    if (_isDisposed) return;
    
    // Find the comment
    final commentIndex = state.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;
    
    final comment = state.comments[commentIndex];
    
    // Cancel any pending timer for this comment
    _likeDebounceTimers[commentId]?.cancel();
    
    // Update optimistically
    final bool newLikeStatus = !comment.isLikedByCurrentUser;
    final int newLikeCount = comment.likeCount + (newLikeStatus ? 1 : -1);
    
    final updatedComment = comment.copyWith(
      isLikedByCurrentUser: newLikeStatus,
      likeCount: newLikeCount,
    );
    
    final updatedComments = [...state.comments];
    updatedComments[commentIndex] = updatedComment;
    
    state = state.copyWith(comments: updatedComments);
    
    // Debounce API call
    _likeDebounceTimers[commentId] = Timer(const Duration(milliseconds: 300), () async {
      if (_isDisposed) return;
      
      try {
        await _repository.toggleCommentLike(commentId);
        // Success - keep optimistic update
      } catch (e) {
        if (_isDisposed) return;
        
        // Revert on error
        final revertedComment = comment;
        final revertedComments = [...state.comments];
        revertedComments[commentIndex] = revertedComment;
        
        state = state.copyWith(comments: revertedComments);
        
        NotificationService().showNotification(
          message: 'Error updating like',
          type: NotificationType.error,
          duration: const Duration(seconds: 2),
        );
      }
    });
  }
}

// Per-story comment provider
final commentsProvider = StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
  (ref, storyId) => CommentsNotifier(ref.watch(commentRepositoryProvider), storyId),
);

// State for replies to a specific comment
class RepliesState extends Equatable {
  final bool isLoading;
  final bool isLoadingMore;
  final List<CommentModel> replies;
  final CommentPaginationModel pagination;
  final bool isExpanded;
  final String? errorMessage;
  
  const RepliesState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.replies = const [],
    this.pagination = const CommentPaginationModel(),
    this.isExpanded = false,
    this.errorMessage,
  });
  
  RepliesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<CommentModel>? replies,
    CommentPaginationModel? pagination,
    bool? isExpanded,
    String? errorMessage,
  }) {
    return RepliesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      replies: replies ?? this.replies,
      pagination: pagination ?? this.pagination,
      isExpanded: isExpanded ?? this.isExpanded,
      errorMessage: errorMessage,
    );
  }
  
  @override
  List<Object?> get props => [isLoading, isLoadingMore, replies, pagination, isExpanded, errorMessage];
}

// Provider for replies to a specific comment
class RepliesNotifier extends StateNotifier<RepliesState> {
  final CommentRepository _repository;
  final String commentId;
  final String storyId;
  bool _isDisposed = false;
  final Map<String, Timer> _likeDebounceTimers = {};
  
  RepliesNotifier(this._repository, this.commentId, this.storyId) : super(const RepliesState());
  
  @override
  void dispose() {
    _isDisposed = true;
    _likeDebounceTimers.forEach((key, timer) => timer.cancel());
    _likeDebounceTimers.clear();
    super.dispose();
  }

  // Toggle expanded state
  void toggleExpanded() {
    if (_isDisposed) return;
    
    final newExpanded = !state.isExpanded;
    state = state.copyWith(isExpanded: newExpanded);
    
    // Only load replies when expanding and if they haven't been loaded yet
    if (newExpanded && state.replies.isEmpty && !state.isLoading) {
      fetchReplies();
    }
  }
  
  // Add this method to expand replies section if it's not already expanded
  void toggleExpandedIfNeeded() {
    if (_isDisposed) return;
    
    if (!state.isExpanded) {
      state = state.copyWith(isExpanded: true);
      
      // Load replies if not loaded yet
      if (state.replies.isEmpty && !state.isLoading) {
        fetchReplies();
      }
    }
  }
  
  // Fetch replies
  Future<void> fetchReplies() async {
    if (_isDisposed) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // Pass page size as 3 to match the TikTok-style behavior
      final result = await _repository.getReplies(commentId, page: 1, pageSize: 3);
      if (_isDisposed) return;
      
      state = state.copyWith(
        isLoading: false,
        replies: result['replies'],
        pagination: result['pagination'],
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Load more replies
  Future<void> loadMoreReplies() async {
    if (_isDisposed || !state.pagination.hasMore || state.isLoadingMore) return;
    
    state = state.copyWith(isLoadingMore: true);
    
    try {
      final nextPage = state.pagination.currentPage + 1;
      final result = await _repository.getReplies(
        commentId,
        page: nextPage,
        pageSize: 3  // Keep the page size small like TikTok
      );
      if (_isDisposed) return;
      
      state = state.copyWith(
        isLoadingMore: false,
        replies: [...state.replies, ...result['replies']],
        pagination: result['pagination'],
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Add a reply
  Future<void> addReply(String content) async {
    if (_isDisposed || content.trim().isEmpty) return;
    
    try {
      final newReply = await _repository.addComment(
        storyId, 
        content, 
        parentCommentId: commentId,
      );
      if (_isDisposed) return;
      
      // Optimistically update state
      state = state.copyWith(
        replies: [newReply, ...state.replies],
        pagination: CommentPaginationModel(
          currentPage: state.pagination.currentPage,
          totalPages: state.pagination.totalPages,
          totalComments: state.pagination.totalComments + 1,
          hasMore: state.pagination.hasMore,
        ),
      );
      
      NotificationService().showNotification(
        message: 'Reply added successfully',
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (_isDisposed) return;
      
      NotificationService().showNotification(
        message: 'Failed to add reply',
        type: NotificationType.error,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  // Toggle like for a reply
  Future<void> toggleReplyLike(String replyId) async {
    if (_isDisposed) return;
    
    // Find the reply
    final replyIndex = state.replies.indexWhere((r) => r.id == replyId);
    if (replyIndex == -1) return;
    
    final reply = state.replies[replyIndex];
    
    // Cancel any pending timer for this reply
    _likeDebounceTimers[replyId]?.cancel();
    
    // Update optimistically
    final bool newLikeStatus = !reply.isLikedByCurrentUser;
    final int newLikeCount = reply.likeCount + (newLikeStatus ? 1 : -1);
    
    final updatedReply = reply.copyWith(
      isLikedByCurrentUser: newLikeStatus,
      likeCount: newLikeCount,
    );
    
    final updatedReplies = [...state.replies];
    updatedReplies[replyIndex] = updatedReply;
    
    state = state.copyWith(replies: updatedReplies);
    
    // Debounce API call
    _likeDebounceTimers[replyId] = Timer(const Duration(milliseconds: 300), () async {
      if (_isDisposed) return;
      
      try {
        await _repository.toggleCommentLike(replyId);
        // Success - keep optimistic update
      } catch (e) {
        if (_isDisposed) return;
        
        // Revert on error
        final revertedReply = reply;
        final revertedReplies = [...state.replies];
        revertedReplies[replyIndex] = revertedReply;
        
        state = state.copyWith(replies: revertedReplies);
        
        NotificationService().showNotification(
          message: 'Error updating like',
          type: NotificationType.error,
          duration: const Duration(seconds: 2),
        );
      }
    });
  }
}

// Per-comment replies provider
final repliesProvider = StateNotifierProvider.family<RepliesNotifier, RepliesState, (String, String)>(
  (ref, params) => RepliesNotifier(
    ref.watch(commentRepositoryProvider), 
    params.$1, // commentId
    params.$2, // storyId
  ),
);