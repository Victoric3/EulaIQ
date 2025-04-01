import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/comments/data/models/comment_model.dart';
import 'package:eulaiq/src/features/comments/presentation/providers/comment_provider.dart';

class CommentItem extends ConsumerWidget {
  final CommentModel comment;
  final String storyId;
  final bool isDark;
  final Function(String commentId, String authorName)? onReply;
  
  const CommentItem({
    Key? key,
    required this.comment,
    required this.storyId,
    required this.isDark,
    this.onReply,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? Colors.white24 : Colors.grey.shade300,
                backgroundImage: comment.author['photo'] != null 
                  ? CachedNetworkImageProvider(comment.author['photo']) 
                  : null,
                child: comment.author['photo'] == null 
                  ? Text(
                      (comment.author['username'] as String).isNotEmpty 
                        ? (comment.author['username'] as String)[0].toUpperCase() 
                        : '?',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    )
                  : null,
              ),
              const SizedBox(width: 12),
              
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author and timestamp
                    Row(
                      children: [
                        Text(
                          comment.author['username'] ?? 'Unknown User',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(comment.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Comment text
                    Text(
                      comment.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Like and reply buttons
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: () {
                            ref.read(commentsProvider(storyId).notifier)
                              .toggleCommentLike(comment.id);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  comment.isLikedByCurrentUser 
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: comment.isLikedByCurrentUser
                                    ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                    : (isDark ? Colors.white70 : Colors.black54),
                                ),
                                if (comment.likeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    comment.likeCount.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: comment.isLikedByCurrentUser
                                        ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                        : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Reply button
                        InkWell(
                          onTap: () => onReply?.call(
                            comment.id, 
                            comment.author['username'] ?? 'Unknown',
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Replies
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: _buildRepliesSection(ref),
          ),
        
        // Divider
        Divider(color: isDark ? Colors.white12 : Colors.black12),
      ],
    );
  }
  
  Widget _buildRepliesSection(WidgetRef ref) {
    final repliesState = ref.watch(repliesProvider((comment.id, storyId)));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            ref.read(repliesProvider((comment.id, storyId)).notifier).toggleExpanded();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Icon(
                  repliesState.isExpanded 
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                  size: 16,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
                const SizedBox(width: 4),
                Text(
                  repliesState.isExpanded 
                    ? 'Hide replies'
                    : 'View ${comment.replies.length} replies',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Only show RepliesList if expanded
        if (repliesState.isExpanded)
          RepliesList(
            commentId: comment.id,
            storyId: storyId,
            isDark: isDark,
            onReply: onReply,
          ),
      ],
    );
  }
}

// A separate widget for replies that are expanded
class RepliesList extends ConsumerWidget {
  final String commentId;
  final String storyId;
  final bool isDark;
  final Function(String commentId, String authorName)? onReply;
  
  const RepliesList({
    Key? key,
    required this.commentId,
    required this.storyId,
    required this.isDark,
    this.onReply,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repliesProvider((commentId, storyId)));
    
    if (!state.isExpanded) {
      return const SizedBox.shrink();
    }
    
    if (state.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
      );
    }
    
    if (state.replies.isEmpty && !state.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No replies yet',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white54 : Colors.black38,
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.replies.length + (state.pagination.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.replies.length) {
          if (state.isLoadingMore) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
            );
          } else if (state.pagination.hasMore) {
            // Instead of automatic loading, show a "Show more replies" button
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextButton(
                onPressed: () {
                  ref.read(repliesProvider((commentId, storyId)).notifier).loadMoreReplies();
                },
                child: Text(
                  'Show more replies',
                  style: TextStyle(
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }
        
        final reply = state.replies[index];
        return ReplyItem(
          reply: reply,
          storyId: storyId,
          commentId: commentId,
          isDark: isDark,
          onReply: onReply,
        );
      },
    );
  }
}

// Simple reply item
class ReplyItem extends ConsumerWidget {
  final CommentModel reply;
  final String storyId;
  final String commentId;
  final bool isDark;
  final Function(String commentId, String authorName)? onReply;
  
  const ReplyItem({
    Key? key,
    required this.reply,
    required this.storyId,
    required this.commentId,
    required this.isDark,
    this.onReply,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isDark ? Colors.white24 : Colors.grey.shade300,
            backgroundImage: reply.author['photo'] != null 
              ? CachedNetworkImageProvider(reply.author['photo']) 
              : null,
            child: reply.author['photo'] == null 
              ? Text(
                  (reply.author['username'] as String).isNotEmpty 
                    ? (reply.author['username'] as String)[0].toUpperCase() 
                    : '?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 10,
                  ),
                )
              : null,
          ),
          const SizedBox(width: 8),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and timestamp
                Row(
                  children: [
                    Text(
                      reply.author['username'] ?? 'Unknown User',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        // Use blue colors for usernames in replies
                        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(reply.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                
                // Reply text
                Text(
                  reply.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Like button
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        ref.read(repliesProvider((commentId, storyId)).notifier)
                          .toggleReplyLike(reply.id);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              reply.isLikedByCurrentUser 
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                              size: 14,
                              color: reply.isLikedByCurrentUser
                                ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                : (isDark ? Colors.white70 : Colors.black54),
                            ),
                            if (reply.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                reply.likeCount.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: reply.isLikedByCurrentUser
                                    ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                    : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}