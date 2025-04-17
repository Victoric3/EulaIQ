import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/comments/data/models/comment_model.dart';
import 'package:eulaiq/src/features/comments/presentation/providers/comment_provider.dart';
import 'package:eulaiq/src/features/create/data/repositories/ebook_repository.dart';
import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';
import 'package:eulaiq/src/features/library/presentation/providers/ebook_detail_provider.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_provider.dart';
import 'package:eulaiq/src/features/library/presentation/ui/widgets/processing_logs_view.dart';
import 'package:eulaiq/src/features/quiz/presentation/providers/quiz_summary_provider.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/widgets/quiz_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// Import the StarRating widget
import 'package:eulaiq/src/common/widgets/star_rating.dart';

// Add these imports
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';

// Add the imports at the top of your file
import 'package:eulaiq/src/features/comments/presentation/ui/widgets/comment_section.dart';

@RoutePage()
class EbookDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final String? slug;
  
  const EbookDetailScreen({
    Key? key,
    required this.id,
    this.slug,
  }) : super(key: key);
  
  @override
  ConsumerState<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends ConsumerState<EbookDetailScreen> {
  Timer? _statusCheckTimer;
  bool _hasCleanedUp = false;
  final EbookRepository _ebookRepository = EbookRepository();

  @override
  void initState() {
    super.initState();
    
    // Fetch ebook details when screen loads
    Future.microtask(() {
      // Load eBook details
      ref.read(ebookDetailProvider.notifier).fetchEbookDetails(id: widget.id, slug: widget.slug);
      
      // Load comments immediately for comment preview section
      ref.read(commentsProvider(widget.id).notifier).fetchComments();
      
      // Start polling for status updates if the ebook is still processing
      _startStatusPolling();
    });
  }
  
  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
  
  void _startStatusPolling() async {
    // Get the current eBook
    final currentEbook = ref.read(ebookDetailProvider).ebook;
    
    // Only start polling if the eBook is in processing state
    if (currentEbook?.status == 'processing') {
      // Cancel any existing timer
      _statusCheckTimer?.cancel();
      
      // Poll every 5 seconds
      _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkEbookStatus();
      });
    }
  }

  Future<void> _checkEbookStatus() async {
    try {
      // Get the current eBook from state
      final currentEbook = ref.read(ebookDetailProvider).ebook;
      if (currentEbook == null) return;
      
      // Use the repository to check status
      final statusData = await _ebookRepository.checkEbookStatus(currentEbook.id);
      
      // Extract the status from the response
      final apiStatus = statusData['status'] as String?;
      
      // If status has changed from processing to something else (like complete)
      if (apiStatus != null && apiStatus != 'processing' && currentEbook.status == 'processing') {
        // Refresh the eBook details to get the latest state
        ref.read(ebookDetailProvider.notifier).fetchEbookDetails(id: widget.id);
        
        // Also update the library to reflect the status change
        ref.read(libraryProvider.notifier).refreshEbook(currentEbook.id);
        
        // Stop polling since processing is no longer active
        _statusCheckTimer?.cancel();
        _statusCheckTimer = null;
      }
    } catch (e) {
      print('Error checking eBook status: $e');
    }
  }

  // Use this method before navigating away
  void cleanupBeforeNavigation() {
    if (!_hasCleanedUp && mounted) {
      _hasCleanedUp = true;
      ref.read(ebookDetailProvider.notifier).clearEbookDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(ebookDetailProvider);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [
                  AppColors.darkBg,
                  AppColors.darkBg.withOpacity(0.95),
                  AppColors.darkBg.withOpacity(0.9),
                ]
              : [
                  AppColors.neutralLightGray.withOpacity(0.5),
                  Colors.white,
                  AppColors.brandDeepGold.withOpacity(0.05),
                ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: state.isLoading 
            ? _buildLoadingView(isDark)
            : state.errorMessage != null
              ? _buildErrorView(isDark, state.errorMessage!)
              : state.ebook != null
                ? _buildDetailView(isDark, state.ebook!)
                : const Center(child: Text('No ebook selected')),
        ),
      ),
    );
  }
  
  Widget _buildLoadingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading eBook ...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView(bool isDark, String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load eBook',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.read(ebookDetailProvider.notifier)
                .fetchEbookDetails(id: widget.id, slug: widget.slug);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  // Update the _buildDetailView method to make it scrollable
Widget _buildDetailView(bool isDark, EbookModel ebook) {
  return Stack(
    children: [
      CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Ensure it's scrollable
        slivers: [
          // App bar with book cover and back button
          SliverPersistentHeader(
            delegate: _EbookDetailHeaderDelegate(
              ebook: ebook,
              isDark: isDark,
              onBackPressed: cleanupBeforeNavigation, // Pass the callback
            ),
            pinned: true,
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and author info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ebook.title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Created ${timeago.format(ebook.createdAt)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Reading list button
                      _buildBookmarkButton(isDark, ebook, ref),
                      
                      const SizedBox(width: 8),
                      // Like button
                      _buildLikeButton(isDark, ebook),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Add rating component
                  _buildRatingComponent(isDark, ebook),
                  
                  const SizedBox(height: 16),
                  
                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ebook.tags.map((tag) => _buildTag(isDark, tag)).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  if (ebook.description != null && ebook.description!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ebook.description!,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  
                  // Contents section
                  if (ebook.contentTitles != null && ebook.contentTitles!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contents',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildContentsSection(isDark, ebook),
                        const SizedBox(height: 24),
                      ],
                    ),
                  
                  // Action buttons
                  _buildActionButtons(isDark, ebook),
                  
                  const SizedBox(height: 24),
                  
                  // Features
                  _buildFeaturesSection(isDark, ebook),
                  
                  const SizedBox(height: 24),
                  
                  // Add comment preview section
                  _buildCommentPreview(isDark),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Add padding at the bottom to prevent overflow
          const SliverToBoxAdapter(
            child: SizedBox(height: 40), // Extra padding at the bottom
          ),
        ],
      ),
      
      // Add floating comment button
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(
          onPressed: () => _showComments(context, isDark),
          backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          child: Icon(
            MdiIcons.commentOutline,
            color: isDark ? Colors.black87 : Colors.white,
          ),
          elevation: 4,
        ),
      ),
    ],
  );
}
  
// Update the _buildLikeButton method for better UI feedback
Widget _buildLikeButton(bool isDark, EbookModel ebook) {
  final isLiked = ebook.isLikedByCurrentUser ?? false;
  
  return Column(
    children: [
      InkWell(
        onTap: () => ref.read(ebookDetailProvider.notifier).toggleLike(),
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLiked 
              ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1))
              : (isDark ? Colors.black26 : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(
              color: isLiked
                ? Colors.red
                : isDark 
                  ? AppColors.neonCyan.withOpacity(0.2)
                  : AppColors.brandDeepGold.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              key: ValueKey<bool>(isLiked), // Key for proper animation
              color: isLiked ? Colors.red : isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              size: 24,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          '${ebook.likeCount}',
          key: ValueKey<int>(ebook.likeCount), // Key for proper animation
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isLiked 
              ? Colors.red.shade700
              : isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    ],
  );
}

// Update the _buildRatingComponent for better interaction
Widget _buildRatingComponent(bool isDark, EbookModel ebook) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          // Animated rating value
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              '${ebook.averageRating.toStringAsFixed(1)} (${ebook.ratingCount})',
              key: ValueKey<String>('${ebook.averageRating}${ebook.ratingCount}'),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      StarRating(
        rating: ebook.userRating?.toDouble() ?? 0.0,
        size: 32,
        color: isDark ? Colors.amber : Colors.amber.shade700,
        unratedColor: isDark ? Colors.white30 : Colors.black26,
        allowHalfStar: false, // Full stars only for rating input
        onRatingChanged: (rating) {
          // Haptic feedback for rating
          HapticFeedback.lightImpact();
          
          // Show subtle notification instead of snackbar
          NotificationService().showNotification(
            message: 'Rated $rating stars',
            type: NotificationType.success,
            duration: const Duration(seconds: 1),
          );
          
          // Call the rating function
          ref.read(ebookDetailProvider.notifier).rateEbook(rating);
        },
      ),
      const SizedBox(height: 4),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: ebook.userRating != null ? 0.0 : 1.0,
        child: Text(
          'Tap to rate',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ),
      if (ebook.userRating != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Text(
                'Your rating: ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              Text(
                '${ebook.userRating}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber : Colors.amber.shade800,
                ),
              ),
              const Text(' '),
              Icon(
                Icons.star,
                size: 12,
                color: isDark ? Colors.amber : Colors.amber.shade800,
              ),
            ],
          ),
        ),
    ],
  );
}
  
  Widget _buildTag(bool isDark, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark 
          ? AppColors.neonCyan.withOpacity(0.1)
          : AppColors.brandDeepGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
            ? AppColors.neonCyan.withOpacity(0.3)
            : AppColors.brandDeepGold.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        ),
      ),
    );
  }
  
  Widget _buildContentsSection(bool isDark, EbookModel ebook) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
            ? AppColors.neonCyan.withOpacity(0.2)
            : AppColors.brandDeepGold.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: ebook.contentTitles!.length > 5 
          ? 5 // Only show first 5 items
          : ebook.contentTitles!.length,
        separatorBuilder: (context, index) => Divider(
          color: isDark 
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final item = ebook.contentTitles![index];
          final isHeading = item['type'] == 'head';
          
          return ListTile(
            dense: !isHeading,
            contentPadding: EdgeInsets.only(
              left: isHeading ? 16.0 : 32.0,
              right: 16.0,
            ),
            title: Text(
              item['title'] ?? 'Untitled Section',
              style: TextStyle(
                fontSize: isHeading ? 15 : 14,
                fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            trailing: Text(
              'p. ${item['page'] ?? '?'}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            onTap: () {
              // Navigate to specific section in reader
            },
          );
        },
      ),
    );
  }
  
  Widget _buildActionButtons(bool isDark, EbookModel ebook) {
  
  return Column(
    children: [
      // Primary Action: Start Reading (Full Width)
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            // Check if fileUrl exists
            if (ebook.fileUrl != null && ebook.fileUrl!.isNotEmpty) {
              context.router.push(DocumentViewerRoute(
                fileUrl: ebook.fileUrl!,
                title: ebook.title,
                ebookId: ebook.id,
              ));
            } else {
              NotificationService().showNotification(
                message: 'Document file not available',
                type: NotificationType.error,
                duration: const Duration(seconds: 3),
              );
            }
          },
          icon: Icon(
            MdiIcons.bookOpenPageVariant,
            size: 20,
          ),
          label: const Text('Start Reading'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
      
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              // Listen button (if audio available)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.router.push(AudioRoute(
                        ebookId: ebook.id,
                        title: ebook.title,
                        imageUrl: ebook.coverImage,
                      ));
                    },
                    icon: Icon(
                      MdiIcons.headphones,
                      size: 20,
                    ),
                    label: const Text('Listen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      side: BorderSide(
                        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showQuizSummary(context, isDark, ebook.id),
                    icon: Icon(
                      MdiIcons.checkboxMarkedCircleOutline,
                      size: 20,
                    ),
                    label: const Text('Quiz'),
                    style: OutlinedButton.styleFrom(
                      // Same style as before
                    ),
                  ),
                ),
            ],
          ),
        ),
      
      // Logs button (if in processing state)
      if (ebook.status == 'processing' || ebook.status == 'error') 
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(top: 16),
          child: OutlinedButton.icon(
            onPressed: () => _showProcessingLogs(context, isDark),
            icon: Icon(
              MdiIcons.textBox,
              size: 20,
            ),
            label: const Text('View Processing Logs'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              side: BorderSide(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
    ],
  );
}
  
  Widget _buildFeaturesSection(bool isDark, EbookModel ebook) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        // Grid of features
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 3.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Page count
            _buildFeatureItem(
              isDark,
              MdiIcons.fileDocumentOutline,
              'Pages',
              '${ebook.pageCount ?? "Unknown"}',
            ),
            
            // Reading time
            _buildFeatureItem(
              isDark,
              MdiIcons.clockOutline,
              'Read Time',
              ebook.readTime != null && ebook.readTime!.isNotEmpty 
                ? '~${ebook.readTime![0]} min' 
                : '~30 min', // fallback value
            ),
            
            // Audio status
            _buildFeatureItem(
              isDark,
              MdiIcons.headphones,
              'Audio',
              ebook.hasAudio ? 'Available' : 'None',
              isActive: ebook.hasAudio,
            ),
            
            // Quiz status
            _buildFeatureItem(
              isDark,
              MdiIcons.checkboxMarkedCircleOutline,
              'Quizzes',
              ebook.hasQuizzes ? 'Available' : 'None',
              isActive: ebook.hasQuizzes,
              onTap: ebook.hasQuizzes ? () => _showQuizSummary(context, isDark, ebook.id) : null,
            ),
          ],
        ),
      ],
    );
  }
  
  // Update _buildFeatureItem to prevent overflow
Widget _buildFeatureItem(
  bool isDark, 
  IconData icon, 
  String title, 
  String value, 
  {bool isActive = true, VoidCallback? onTap}
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
            ? isDark 
              ? AppColors.neonCyan.withOpacity(0.3)
              : AppColors.brandDeepGold.withOpacity(0.3)
            : isDark 
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive
              ? isDark ? AppColors.neonCyan : AppColors.brandDeepGold
              : isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Use MainAxisSize.min to prevent overflow
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis, // Handle overflow text
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive
                      ? isDark ? Colors.white : Colors.black87
                      : isDark ? Colors.white60 : Colors.black45,
                  ),
                  overflow: TextOverflow.ellipsis, // Handle overflow text
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Inside _EbookDetailScreenState class, add this method at the end
void _showComments(BuildContext context, bool isDark) {
  // Pre-load comments if not already loaded
  if (ref.read(commentsProvider(widget.id)).comments.isEmpty && 
      !ref.read(commentsProvider(widget.id)).isLoading) {
    ref.read(commentsProvider(widget.id).notifier).fetchComments();
  }
  
  // Create a scrim color with proper opacity like TikTok
  final scrimColor = Colors.black.withOpacity(0.5);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: scrimColor,
    builder: (context) {
      // Use FractionallySizedBox directly without wrapping in GestureDetector
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: CommentSection(
            storyId: widget.id,
            backgroundColor: isDark 
              ? AppColors.darkBg 
              : Colors.white,
          ),
        ),
      );
    },
  );
}

void _showProcessingLogs(BuildContext context, bool isDark) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            color: isDark ? AppColors.darkBg : Colors.white,
            child: ProcessingLogsView(ebookId: widget.id),
          ),
        ),
      );
    },
  );
}
// Add this method to _EbookDetailScreenState class
Widget _buildCommentPreview(bool isDark) {
  return Consumer(
    builder: (context, ref, child) {
      // Watch comments for this story
      final commentsState = ref.watch(commentsProvider(widget.id));
      
      return Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark 
              ? AppColors.neonCyan.withOpacity(0.2)
              : AppColors.brandDeepGold.withOpacity(0.2),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with comment count and view all button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Comment icon
                  Icon(
                    MdiIcons.commentOutline,
                    size: 20,
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                  const SizedBox(width: 8),
                  
                  // Comment count
                  Text(
                    '${commentsState.pagination.totalComments} Comments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // View all button
                  TextButton(
                    onPressed: () => _showComments(context, isDark),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
            
            // Comment preview content
            _buildCommentPreviewContent(isDark, commentsState),
          ],
        ),
      );
    }
  );
}

// Helper method to build the comment preview content
Widget _buildCommentPreviewContent(bool isDark, CommentsState state) {
  // If loading, show loading state
  if (state.isLoading) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading comments...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // If no comments, show empty state
  if (state.comments.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              MdiIcons.commentOutline,
              size: 36,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Text(
              'No comments yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to comment',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 16),
            
            // Add comment button
            TextButton.icon(
              onPressed: () => _showComments(context, isDark),
              icon: Icon(
                Icons.add_comment_outlined,
                size: 16,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
              label: Text(
                'Add Comment',
                style: TextStyle(
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Show top 2 comments
  final previewComments = state.comments.take(2).toList();
  
  return Column(
    children: [
      ...previewComments.map((comment) => _buildCommentPreviewItem(isDark, comment)),
      
      // Add comment button
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: InkWell(
          onTap: () => _showComments(context, isDark),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isDark ? Colors.white24 : Colors.grey.shade300,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add a comment...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// Helper method to build a single comment preview
Widget _buildCommentPreviewItem(bool isDark, CommentModel comment) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  fontSize: 14,
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
              
              // Comment text (limited to 2 lines)
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Like count and reply count
              Row(
                children: [
                  // Like count
                  Row(
                    children: [
                      Icon(
                        comment.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: comment.isLikedByCurrentUser 
                          ? Colors.red 
                          : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likeCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  
                  if (comment.replies.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    
                    // Reply count
                    Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${comment.replies.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Update the _showComments method to trigger comment loading if needed
}

class _EbookDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  final EbookModel ebook;
  final bool isDark;
  final double maxHeight = 300.0;
  final double minHeight = 80.0;
  final VoidCallback onBackPressed; // Add this line to accept a callback
  
  _EbookDetailHeaderDelegate({
    required this.ebook,
    required this.isDark,
    required this.onBackPressed, // Add this parameter
  });
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / (maxHeight - minHeight);
    final showTitle = progress > 0.5;
    
    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Cover image background
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: (1 - progress).clamp(0.0, 1.0), // Clamp between 0.0 and 1.0
              child: ebook.coverImage != null && ebook.coverImage!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: ebook.coverImage!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                      child: Icon(
                        MdiIcons.bookOpenPageVariant,
                        size: 80,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                  )
                : Container(
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    child: Icon(
                      MdiIcons.bookOpenPageVariant,
                      size: 80,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
            ),
          ),
          
          // Gradient overlay for better text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    isDark 
                      ? AppColors.darkBg.withOpacity(progress < 0.5 ? 0.8 : 1.0)
                      : Colors.white.withOpacity(progress < 0.5 ? 0.8 : 1.0),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onBackPressed(); 
                        context.router.pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Title in header when scrolled
          if (showTitle)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 60,
              right: 16,
              child: Text(
                ebook.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  double get maxExtent => maxHeight;
  
  @override
  double get minExtent => minHeight;
  
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

Widget _buildBookmarkButton(bool isDark, EbookModel ebook, WidgetRef ref) {
  final isInReadingList = ebook.isInReadingList ?? false;
  
  return Column(
    children: [
      InkWell(
        onTap: () => ref.read(ebookDetailProvider.notifier).toggleReadingList(),
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isInReadingList 
              ? (isDark ? AppColors.neonCyan.withOpacity(0.2) : AppColors.brandDeepGold.withOpacity(0.1))
              : (isDark ? Colors.black26 : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(
              color: isInReadingList
                ? isDark ? AppColors.neonCyan : AppColors.brandDeepGold
                : isDark 
                  ? AppColors.neonCyan.withOpacity(0.2)
                  : AppColors.brandDeepGold.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isInReadingList ? MdiIcons.bookmarkCheck : MdiIcons.bookmarkOutline,
              key: ValueKey<bool>(isInReadingList),
              color: isInReadingList 
                ? isDark ? AppColors.neonCyan : AppColors.brandDeepGold
                : isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              size: 24,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
     
    ],
  );
}

void _showQuizSummary(BuildContext context, bool isDark, String ebookId) {
  // Remove the direct ref use outside of build
  // ref.read(quizSummaryProvider(ebookId));
  
  final scrimColor = Colors.black.withOpacity(0.5);
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: scrimColor,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.95, // Takes up 95% of the screen
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: isDark ? AppColors.darkBg : Colors.white,
            child: Consumer(
              // Use Consumer widget inside the builder to access ref
              builder: (context, ref, _) {
                // Use Future.microtask to delay the provider modification
                Future.microtask(() {
                  ref.read(quizSummaryProvider(ebookId).notifier).fetchQuizSummary(ebookId);
                });
                
                return QuizSummaryView(ebookId: ebookId);
              },
            ),
          ),
        ),
      );
    },
  );
}

