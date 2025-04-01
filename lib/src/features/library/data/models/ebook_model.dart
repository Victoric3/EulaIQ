import 'package:equatable/equatable.dart';

class EbookModel extends Equatable {
  final String id;
  final String title;
  final String? slug;
  final String? description;
  final String? coverImage;
  final String author;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final String status;
  final String? fileUrl; // Add this field
  
  // Derived fields from Story model
  final int? pageCount;
  final bool hasAudio;
  final bool hasQuizzes;
  final double? completionPercentage;
  
  // Like and rating fields
  final List<String>? likes; 
  final int likeCount;
  final bool? isLikedByCurrentUser;
  final double averageRating;
  final int ratingCount;
  final int? userRating; // Rating given by current user (if any)
  
  // Other fields
  final List<int>? readTime;
  final List<Map<String, dynamic>>? contentTitles;
  final List<Map<String, dynamic>>? sections; // Add this field
  final String? processingError;
  final bool? isInReadingList; // Add this field

  const EbookModel({
    required this.id,
    required this.title,
    this.slug, // Add to constructor
    this.description,
    this.coverImage,
    required this.author,
    required this.createdAt,
    this.updatedAt,
    this.tags = const [],
    required this.status,
    this.fileUrl, // Add to constructor
    this.pageCount,
    this.hasAudio = false,
    this.hasQuizzes = false,
    this.completionPercentage,
    this.likes,
    this.likeCount = 0,
    this.isLikedByCurrentUser = false,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.userRating,
    this.readTime,
    this.contentTitles,
    this.sections, // Add this to constructor parameters
    this.processingError,
    this.isInReadingList = false, // Add to constructor
  });
  
  // Add a copyWith method to help with updates
  EbookModel copyWith({
    String? id,
    String? title,
    String? slug, // Add to copyWith
    String? description,
    String? coverImage,
    String? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? status,
    String? fileUrl, // Add to copyWith params
    int? pageCount,
    bool? hasAudio,
    bool? hasQuizzes,
    double? completionPercentage,
    List<String>? likes,
    int? likeCount,
    bool? isLikedByCurrentUser,
    double? averageRating,
    int? ratingCount,
    int? userRating,
    List<int>? readTime,
    List<Map<String, dynamic>>? contentTitles,
    List<Map<String, dynamic>>? sections, // Add this parameter
    String? processingError,
    bool? isInReadingList, // Add to copyWith
  }) {
    return EbookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug, // Include in return
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      fileUrl: fileUrl ?? this.fileUrl, // Add to return object
      pageCount: pageCount ?? this.pageCount,
      hasAudio: hasAudio ?? this.hasAudio,
      hasQuizzes: hasQuizzes ?? this.hasQuizzes,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      likes: likes ?? this.likes,
      likeCount: likeCount ?? this.likeCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      userRating: userRating ?? this.userRating,
      readTime: readTime ?? this.readTime,
      contentTitles: contentTitles ?? this.contentTitles,
      sections: sections ?? this.sections,
      processingError: processingError ?? this.processingError,
      isInReadingList: isInReadingList ?? this.isInReadingList, // Include in return
    );
  }

  // Update the fromJson method
  factory EbookModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    // Parse likes and check if user has liked
    List<String> likesList = [];
    bool isLiked = false;
    
    if (json['likes'] != null) {
      likesList = (json['likes'] as List).map((item) {
        final String likeId = item is Map ? item['_id'] ?? '' : item.toString();
        return likeId;
      }).toList();
      
      // Check if current user has liked this ebook
      if (currentUserId != null) {
        isLiked = likesList.contains(currentUserId);
      }
    }
    
    // Find user's rating if available
    int? userRating;
    if (json['ratings'] != null && currentUserId != null) {
      final userRatingObj = (json['ratings'] as List).firstWhere(
        (rating) {
          final userId = rating is Map 
            ? rating['user'] is Map 
              ? rating['user']['_id'] ?? '' 
              : rating['user'].toString()
            : '';
          return userId == currentUserId;
        }, 
        orElse: () => null
      );
      
      if (userRatingObj != null) {
        userRating = userRatingObj['rating'];
      }
    }
    
    // Parse readTime from JSON
    List<int>? readTimeList;
    if (json['readTime'] != null) {
      readTimeList = (json['readTime'] as List).map((item) => item as int).toList();
    }
    
    return EbookModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Untitled eBook',
      slug: json['slug'], // Extract slug from JSON
      description: json['description'],
      // Map 'image' to coverImage
      coverImage: json['image'],
      fileUrl: json['fileUrl'], // Extract fileUrl from JSON
      author: json['author'] is Map ? json['author']['username'] ?? '' : json['author'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      status: json['status'] ?? 'processing',
      // Calculate pageCount from processingProgress
      pageCount: json['processingProgress']?['totalPages'],
      // Check if audioCollections array is not empty
      hasAudio: (json['audioCollections'] as List?)?.isNotEmpty ?? false,
      // Check if questions array is not empty
      hasQuizzes: (json['questions'] as List?)?.isNotEmpty ?? false,
      // Calculate completion percentage from processingProgress
      completionPercentage: json['processingProgress'] != null ?
          (json['processingProgress']['pagesProcessed'] / 
           (json['processingProgress']['totalPages'] > 0 ? 
            json['processingProgress']['totalPages'] : 1)) * 100 : 0.0,
      // Include sections for potential detailed view
      sections: (json['sections'] as List?)?.map((section) => 
          Map<String, dynamic>.from(section)).toList(),
      // Include content titles for navigation
      contentTitles: (json['contentTitles'] as List?)?.map((title) => 
          Map<String, dynamic>.from(title)).toList(),
      // Parse ratings data
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
      // Parse readTime
      readTime: readTimeList,
      // Get processing error if present
      processingError: json['processingError'],
      likes: likesList,
      likeCount: likesList.length,
      isLikedByCurrentUser: isLiked,
      userRating: userRating,
      isInReadingList: json['isInReadingList'] ?? false, // Parse isInReadingList
    );
  }

  @override
  List<Object?> get props => [
    id, title, slug, description, coverImage, author, 
    createdAt, updatedAt, tags, status, fileUrl, pageCount, // Add fileUrl here
    hasAudio, hasQuizzes, completionPercentage,
    likes, likeCount, isLikedByCurrentUser, averageRating, ratingCount, userRating,
    readTime, contentTitles, sections, processingError, isInReadingList // Add isInReadingList
  ];
}

class PaginationModel {
  final int currentPage;
  final int totalPages;
  final int totalEbooks;
  final bool hasMore;

  const PaginationModel({
    required this.currentPage,
    required this.totalPages,
    required this.totalEbooks,
    required this.hasMore,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalEbooks: json['totalEbooks'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}