import 'package:equatable/equatable.dart';

class CommentModel extends Equatable {
  final String id;
  final String content;
  final Map<String, dynamic> author;
  final String storyId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final List<String> likes;
  final bool isLikedByCurrentUser;
  final String? parentCommentId;
  final List<String> replies;
  
  const CommentModel({
    required this.id,
    required this.content,
    required this.author,
    required this.storyId,
    required this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.likes = const [],
    this.isLikedByCurrentUser = false,
    this.parentCommentId,
    this.replies = const [],
  });
  
  factory CommentModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    // Parse likes and check if user has liked
    final likesList = (json['likes'] as List?)?.map((item) => 
      item is Map ? item['_id']?.toString() ?? '' : item.toString()
    ).toList() ?? [];
    
    final bool isLiked = currentUserId != null && 
      likesList.contains(currentUserId);
    
    return CommentModel(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      author: json['author'] is Map ? 
        Map<String, dynamic>.from(json['author']) : 
        {'_id': '', 'username': 'Unknown', 'photo': null},
      storyId: json['story']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? 
        DateTime.parse(json['createdAt']) : 
        DateTime.now(),
      updatedAt: json['updatedAt'] != null ? 
        DateTime.parse(json['updatedAt']) : 
        null,
      likeCount: json['likeCount'] ?? 0,
      likes: likesList.cast<String>(),
      isLikedByCurrentUser: isLiked,
      parentCommentId: json['parentComment']?.toString(),
      replies: (json['replies'] as List?)?.map((reply) => 
        reply is Map ? reply['_id']?.toString() ?? '' : reply.toString()
      ).toList() ?? [],
    );
  }
  
  CommentModel copyWith({
    String? id,
    String? content,
    Map<String, dynamic>? author,
    String? storyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    List<String>? likes,
    bool? isLikedByCurrentUser,
    String? parentCommentId,
    List<String>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      content: content ?? this.content,
      author: author ?? this.author,
      storyId: storyId ?? this.storyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      likes: likes ?? this.likes,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
    );
  }
  
  @override
  List<Object?> get props => [
    id, content, author, storyId, createdAt, updatedAt, 
    likeCount, likes, isLikedByCurrentUser, parentCommentId, replies
  ];
}

class CommentPaginationModel extends Equatable {
  final int currentPage;
  final int totalPages;
  final int totalComments;
  final bool hasMore;
  
  const CommentPaginationModel({
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalComments = 0,
    this.hasMore = false,
  });
  
  factory CommentPaginationModel.fromJson(Map<String, dynamic> json) {
    return CommentPaginationModel(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalComments: json['count'] ?? json['totalComments'] ?? json['totalReplies'] ?? 0,
      hasMore: (json['currentPage'] ?? 1) < (json['totalPages'] ?? 1),
    );
  }
  
  @override
  List<Object?> get props => [currentPage, totalPages, totalComments, hasMore];
}