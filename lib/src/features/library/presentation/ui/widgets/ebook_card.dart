import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class EbookCard extends StatelessWidget {
  final EbookModel ebook;
  final Function(String ebookId)? onRetryProcessing;
  
  const EbookCard({
    Key? key,
    required this.ebook,
    this.onRetryProcessing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        // Navigate to detail view when tapped
        context.router.push(EbookDetailRoute(id: ebook.id));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark 
              ? AppColors.neonCyan.withOpacity(0.2)
              : AppColors.brandDeepGold.withOpacity(0.2),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image with status badge
            Expanded(
              flex: 7,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image (with placeholder)
                    ebook.coverImage != null && ebook.coverImage!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ebook.coverImage!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildCoverPlaceholder(isDark),
                          errorWidget: (context, url, error) => _buildCoverPlaceholder(isDark),
                        )
                      : _buildCoverPlaceholder(isDark),
                      
                    // Processing overlay for books still being processed
                    if (ebook.status == 'processing')
                      Stack(
                        children: [
                          // Background gradient (existing code)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.2),
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                          
                          // Processing indicator (existing code)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    value: ebook.completionPercentage != null ? ebook.completionPercentage! / 100 : null,
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Processing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Retry button for processing (new code)
                          if (onRetryProcessing != null)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.8), // Amber to match the processing status color
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.restart_alt, // Different icon to distinguish from error retry
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Restart processing',
                                  onPressed: () => onRetryProcessing!(ebook.id),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  iconSize: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    
                    // Status badge (top right) - only show for non-complete status
                    if (ebook.status.toLowerCase() != 'complete')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildStatusBadge(isDark),
                      ),
                    
                    // Feature badges (bottom left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Row(
                        children: [
                          if (ebook.hasAudio)
                            _buildFeatureBadge(
                              isDark, 
                              MdiIcons.headphones, 
                              'Audio'
                            ),
                          if (ebook.hasAudio && ebook.hasQuizzes)
                            const SizedBox(width: 4),
                          if (ebook.hasQuizzes)
                            _buildFeatureBadge(
                              isDark, 
                              MdiIcons.checkboxMarkedCircleOutline, 
                              'Quiz'
                            ),
                        ],
                      ),
                    ),
                    
                    // Retry button for error status
                    if (ebook.status == 'error' && onRetryProcessing != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            tooltip: 'Retry processing',
                            onPressed: () => onRetryProcessing!(ebook.id),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: const EdgeInsets.all(4),
                            iconSize: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Book info section
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with ellipsis for overflow
                    Text(
                      ebook.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Creation date
                    Text(
                      'Created ${timeago.format(ebook.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
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

  Widget _buildCoverPlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[850] : Colors.grey[200],
      child: Center(
        child: Icon(
          MdiIcons.bookOutline,
          size: 40,
          color: isDark ? Colors.white30 : Colors.black26,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    // Early return for complete status - shouldn't happen but just in case
    if (ebook.status.toLowerCase() == 'complete') {
      return const SizedBox.shrink(); // Empty widget
    }
    
    Color badgeColor;
    String statusText;
    IconData icon;
    
    switch (ebook.status.toLowerCase()) {
      case 'processing':
        badgeColor = Colors.amber;
        statusText = 'Processing';
        icon = MdiIcons.clockOutline;
        break;
      case 'error':
        badgeColor = Colors.red;
        statusText = 'Error';
        icon = MdiIcons.alertCircle;
        break;
      default:
        badgeColor = Colors.blue;
        statusText = ebook.status;
        icon = MdiIcons.star;
        break;
    }
    
    // Rest of your existing code remains the same
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(bool isDark, IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}