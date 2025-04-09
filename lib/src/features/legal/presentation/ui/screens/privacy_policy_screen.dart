import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';

@RoutePage()
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
              title: '1. Information We Collect',
              children: [
                _buildSubsection(
                  isDark,
                  title: 'Educational Data',
                  content: 'We collect information related to your medical education journey:',
                  bulletPoints: [
                    'Learning preferences and study patterns',
                    'Academic progress and performance data',
                    'Content interaction metrics',
                    'Educational materials usage statistics',
                  ],
                ),
                const SizedBox(height: 16),
                _buildSubsection(
                  isDark,
                  title: 'Personal Information',
                  bulletPoints: [
                    'Name and academic credentials',
                    'Medical school affiliation',
                    'Educational background',
                    'Communication preferences',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '2. How We Use Your Information',
              children: [
                _buildText('We use collected information to:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'Personalize your learning experience',
                    'Adapt content to your knowledge level',
                    'Generate customized study materials',
                    'Track your progress and provide insights',
                    'Improve our AI-powered learning algorithms',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '3. Data Protection',
              children: [
                _buildText('We implement robust security measures to protect your educational data:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'End-to-end encryption for learning materials',
                    'Secure storage of academic progress',
                    'Regular platform security audits',
                    'Strict access controls for student data',
                    'Compliance with educational data regulations',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '4. Your Rights',
              children: [
                _buildText('As a medical student, you have the right to:', isDark),
                _buildBulletPoints(
                  isDark,
                  [
                    'Access your learning history and progress data',
                    'Request corrections to your academic profile',
                    'Export your study materials and notes',
                    'Control your learning preferences',
                    'Manage community participation settings',
                  ],
                ),
              ],
            ),
            
            _buildSection(
              isDark,
              title: '5. Contact Us',
              children: [
                _buildText('For privacy-related inquiries, contact our Data Protection Team:', isDark),
                const SizedBox(height: 8),
                _buildText('Email: support@eulaiq.com', isDark, isBold: true),
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
          'Privacy Policy',
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
            'At EulaIQ, we are committed to protecting your privacy while delivering innovative medical education through our AI-powered learning platform.',
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