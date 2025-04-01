import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EmptyLibrary extends StatelessWidget {
  final VoidCallback? onCreatePressed;
  
  const EmptyLibrary({
    Key? key,
    this.onCreatePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Eula logo with glow effect
              Container(
                width: size.width * 0.3,
                height: size.width * 0.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark 
                    ? AppColors.darkBg.withOpacity(0.5)
                    : Colors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                        .withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Image.asset(
                      'assets/brand_assets/Eula.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Your Library is Empty',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Create your first interactive eBook by uploading a document',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: onCreatePressed ?? () {
                  context.router.pushNamed('/create');
                },
                icon: Icon(
                  MdiIcons.bookPlus,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Create New eBook',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.5),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Features list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      isDark,
                      MdiIcons.bookOpenPageVariant,
                      'Create interactive eBooks from your documents'
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      isDark,
                      MdiIcons.headphones,
                      'Get AI-generated audio for your content'
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      isDark,
                      MdiIcons.checkboxMarkedCircleOutline,
                      'Practice with auto-generated quizzes'
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(bool isDark, IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark 
              ? AppColors.neonCyan.withOpacity(0.1)
              : AppColors.brandDeepGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}