import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';

@RoutePage()
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Terms of Service'),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark, textColor),
            const SizedBox(height: 24),
            
            _buildSection(
              isDark,
              title: '1. Acceptance of Terms',
              children: [
                _buildText(
                  'By accessing or using EulaIQ\'s medical education platform, you agree to be bound by these Terms of Service. Our platform is designed for educational purposes only.',
                  isDark,
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '2. Platform Services',
              children: [
                _buildSubsection(
                  isDark,
                  title: 'Medical Education Features',
                  content: 'EulaIQ provides:',
                  bulletPoints: [
                    'AI-powered medical content transformation',
                    'Interactive learning materials and study paths',
                    'Medical education podcasts and video content',
                    'Spaced repetition learning tools',
                    'Community-based learning features',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '3. Academic Integrity',
              children: [
                _buildText('Users must:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'Maintain academic honesty in all platform interactions',
                    'Use content for personal educational purposes only',
                    'Respect medical education ethical guidelines',
                    'Not share access credentials with others',
                    'Properly cite any referenced materials',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '4. Medical Content Disclaimer',
              children: [
                _buildText('Important notices about our content:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'Educational content is for learning purposes only',
                    'Not a substitute for professional medical advice',
                    'Users should verify information with official sources',
                    'Content may be updated to reflect current medical knowledge',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '5. Data Protection & Privacy',
              children: [
                _buildText('EulaIQ commits to:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'Protecting student learning data',
                    'Maintaining confidentiality of user information',
                    'Secure storage of educational progress',
                    'Transparent data collection practices',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '6. Platform Updates',
              children: [
                _buildText('EulaIQ reserves the right to:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'Update educational content',
                    'Modify platform features',
                    'Enhance learning algorithms',
                    'Improve user experience',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '7. Contact Information',
              children: [
                _buildText('For questions about these terms, contact us at:', isDark),
                const SizedBox(height: 8),
                _buildText('Email: support@eulaiq.com', isDark, isBold: true),
                _buildText('Website: www.eulaiq.com/#contact', isDark, isBold: true),
              ],
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terms of Service',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last Updated: February 24, 2025',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.2),
            ),
          ),
          child: Text(
            'Welcome to EulaIQ. By accessing our medical education platform, you agree to these terms and conditions.',
            style: TextStyle(
              fontSize: 15,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSection(
    bool isDark, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildSubsection(
    bool isDark, {
    required String title,
    String? content,
    required List<String> bulletPoints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (content != null) ...[
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildBulletPoints(isDark, bulletPoints),
      ],
    );
  }
  
  Widget _buildBulletPoints(bool isDark, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points.map((point) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  point,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )
      ).toList(),
    );
  }
  
  Widget _buildText(String text, bool isDark, {bool isBold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}