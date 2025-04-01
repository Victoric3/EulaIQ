import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class EbookSkeletonCard extends StatelessWidget {
  const EbookSkeletonCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
            ? AppColors.neonCyan.withOpacity(0.1)
            : AppColors.brandDeepGold.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: Container(
                height: 150,
                color: Colors.white,
              ),
            ),
            
            // Content placeholders
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title placeholder
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: Colors.white,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Date placeholder
                  Container(
                    width: 100,
                    height: 10,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}