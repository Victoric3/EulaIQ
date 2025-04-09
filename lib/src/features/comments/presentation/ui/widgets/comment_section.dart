import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/comments/presentation/providers/comment_provider.dart';
import 'package:eulaiq/src/features/comments/presentation/ui/widgets/comment_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class CommentSection extends ConsumerStatefulWidget {
  final String storyId;
  final Color? backgroundColor;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  
  const CommentSection({
    Key? key,
    required this.storyId,
    this.backgroundColor,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.2,
    this.maxChildSize = 0.9,
  }) : super(key: key);
  
  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late ScrollController _scrollController;
  bool _isComposing = false;
  String? _currentParentCommentId;
  String? _currentReplyUsername;
  bool _showEmojiKeyboard = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    Future.microtask(() => ref.read(commentsProvider(widget.storyId).notifier).fetchComments());
    
    // Add haptic feedback when sheet appears (TikTok-like)
    HapticFeedback.lightImpact();
    
    // Listen to keyboard visibility to hide emoji picker when keyboard appears
    _commentFocusNode.addListener(_onFocusChange);
  }
  
  void _onFocusChange() {
    if (_commentFocusNode.hasFocus && _showEmojiKeyboard) {
      setState(() {
        _showEmojiKeyboard = false;
      });
    }
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.removeListener(_onFocusChange);
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _cancelReply() {
    setState(() {
      _currentParentCommentId = null;
      _currentReplyUsername = null;
      _commentController.text = '';
      _isComposing = false;
    });
  }

  void _handleReply(String commentId, String authorName) {
    setState(() {
      _isComposing = true;
      _currentParentCommentId = commentId;
      _currentReplyUsername = authorName;
      _commentController.text = '@$authorName ';
    });
    _commentFocusNode.requestFocus();
    
    // Add TikTok-like haptic feedback
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(commentsProvider(widget.storyId));
    
    // Use MediaQuery to get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    
    return Container(
      // Set a specific height based on available screen space
      height: screenSize.height * 0.85, // This should match your modal sheet constraints
      color: widget.backgroundColor ?? (isDark ? AppColors.darkBg : Colors.white),
      child: SafeArea(
        // Only apply bottom safe area to avoid notch issues
        top: false,
        child: Stack(
          // Make sure Stack takes full container size
          fit: StackFit.expand,
          children: [
            // Column for top elements and scrollable content
            Column(
              children: [
                // TikTok-style drag handle
                _buildDragHandle(isDark),
                
                // Header with comment count
                _buildHeader(isDark, state),
                
                // Comments list - should fill available space
                Expanded(
                  child: state.isLoading 
                    ? _buildLoadingIndicator(isDark)
                    : state.comments.isEmpty && !state.isLoading
                      ? _buildEmptyState(isDark)
                      : _buildCommentList(isDark, state),
                ),
                
                // Add padding at the bottom to make room for the fixed input area
                SizedBox(height: 70 + (_showEmojiKeyboard ? 250 : 0)),
              ],
            ),
            
            // Input field positioned at the absolute bottom
            Positioned(
              left: 0,
              right: 0,
              // Use system keyboard height when regular keyboard is shown, 0 when showing emoji keyboard
              bottom: _showEmojiKeyboard ? 0 : MediaQuery.of(context).viewInsets.bottom,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Comment input
                    _buildCommentInput(isDark),
                    
                    // Emoji keyboard with fixed height
                    if (_showEmojiKeyboard)
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, -1),
                            ),
                          ],
                        ),
                        child: _buildEmojiKeyboard(isDark),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: double.infinity,
        height: 24,
        alignment: Alignment.center,
        child: Container(
          width: 36, 
          height: 4, 
          decoration: BoxDecoration(
            color: isDark ? Colors.white38 : Colors.black26,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, CommentsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Title with comment count
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.pagination.totalComments} in total',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Improved close button with better visual design
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading comments...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.commentOutline,
            size: 64,
            color: isDark ? Colors.white30 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts!',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList(bool isDark, CommentsState state) {
    return ListView.builder(
      controller: _scrollController,
      // Add padding at the bottom to ensure content doesn't get hidden behind the input
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.comments.length + (state.pagination.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom when loading more
        if (index == state.comments.length) {
          if (state.isLoadingMore) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
            );
          } else {
            // Load more when reaching the bottom
            Future.microtask(() {
              ref.read(commentsProvider(widget.storyId).notifier).loadMoreComments();
            });
            return const SizedBox(height: 50);
          }
        }
        
        final comment = state.comments[index];
        return CommentItem(
          comment: comment,
          storyId: widget.storyId,
          isDark: isDark,
          onReply: _handleReply, // Use our new method here
        );
      },
    );
  }

  Widget _buildCommentInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply indicator (keep existing code)
          if (_currentReplyUsername != null) ... [
            Container(
              margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark 
                  ? Colors.grey.shade900 
                  : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark 
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '@$_currentReplyUsername',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _cancelReply,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close,
                          size: 15,
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
            
          // Input row with WhatsApp-style
          Row(
            children: [
              // Emoji toggle button
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _showEmojiKeyboard = !_showEmojiKeyboard;
                      
                      // This is key - unfocus immediately to dismiss system keyboard
                      if (_showEmojiKeyboard) {
                        _commentFocusNode.unfocus();
                        
                        // Important: Manually update keyboard visibility metrics
                        FocusScope.of(context).unfocus();
                      } else {
                        _commentFocusNode.requestFocus();
                      }
                    });
                  },
                  icon: Icon(
                    _showEmojiKeyboard ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: isDark 
                      ? AppColors.neonCyan.withOpacity(0.8) 
                      : AppColors.brandDeepGold,
                    size: 24,
                  ),
                  constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
              ),
              
              // Input field with rounded border (keep existing code with minor adjustments)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          keyboardType: TextInputType.multiline,
                          maxLines: 5,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                          onChanged: (text) {
                            setState(() {
                              _isComposing = text.isNotEmpty;
                            });
                          },
                          onTap: () {
                            // When tapping the text field, always hide emoji keyboard
                            if (_showEmojiKeyboard) {
                              setState(() {
                                _showEmojiKeyboard = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: _currentParentCommentId != null 
                              ? 'Reply to @$_currentReplyUsername...' 
                              : 'Write a comment...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey : Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Send button with dynamic appearance like WhatsApp (keep existing code)
              Container(
                margin: const EdgeInsets.only(right: 2),
                child: Material(
                  color: _isComposing 
                    ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: !_isComposing 
                      ? null 
                      : () {
                        final text = _commentController.text.trim();
                        if (text.isEmpty) return;
                        
                        if (_currentParentCommentId != null) {
                          ref.read(repliesProvider((_currentParentCommentId!, widget.storyId)).notifier)
                            .addReply(text);
                          
                          ref.read(repliesProvider((_currentParentCommentId!, widget.storyId)).notifier)
                            .toggleExpandedIfNeeded();
                        } else {
                          ref.read(commentsProvider(widget.storyId).notifier)
                            .addComment(text);
                        }
                        
                        _commentController.clear();
                        setState(() {
                          _isComposing = false;
                          _currentParentCommentId = null;
                          _currentReplyUsername = null;
                        });
                        
                        FocusScope.of(context).unfocus();
                      },
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.send,
                        size: 22,
                        color: _isComposing 
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Add this method to your class

  Widget _buildEmojiKeyboard(bool isDark) {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          // Insert emoji at current cursor position
          final text = _commentController.text;
          final selection = _commentController.selection;
          final newText = text.replaceRange(
            selection.start, 
            selection.end, 
            emoji.emoji
          );
          _commentController.text = newText;
          _commentController.selection = TextSelection.collapsed(
            offset: selection.start + emoji.emoji.length
          );
          setState(() {
            _isComposing = _commentController.text.isNotEmpty;
          });
        },
        onBackspacePressed: () {
          if (_commentController.text.isNotEmpty) {
            // Only delete if there's text to delete
            final selection = _commentController.selection;
            final text = _commentController.text;
            if (selection.start > 0) {
              final newStart = selection.start - 1;
              _commentController.text = text.substring(0, newStart) + text.substring(selection.end);
              _commentController.selection = TextSelection.collapsed(offset: newStart);
              setState(() {
                _isComposing = _commentController.text.isNotEmpty;
              });
            }
          }
        },
        config: Config(
          height: 250, // Keep this consistent
          emojiViewConfig: EmojiViewConfig(
            columns: 9, // More columns for better density
            emojiSizeMax: 28.0,
            backgroundColor: isDark ? Colors.black : Colors.white,
          ),
          categoryViewConfig: CategoryViewConfig(
            indicatorColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            backgroundColor: isDark ? Colors.black : Colors.white,
            iconColor: isDark ? Colors.white54 : Colors.grey,
            iconColorSelected: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            categoryIcons: const CategoryIcons(),
            tabIndicatorAnimDuration: kTabScrollDuration,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: isDark ? Colors.black : Colors.white,
          ),
          skinToneConfig: SkinToneConfig(
            enabled: true,
            dialogBackgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDark ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}