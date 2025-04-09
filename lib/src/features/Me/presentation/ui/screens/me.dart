import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();
  
  // Simple preferences
  bool _appNotifications = true;
  bool _emailNotifications = true;

  // Animation controller for profile effects
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Load notification preferences
    _loadNotificationPreferences();

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appNotifications = prefs.getBool('pref_app_notifications') ?? true;
      _emailNotifications = prefs.getBool('pref_email_notifications') ?? true;
    });
  }

  Future<void> _saveNotificationPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      body: userAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          )
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            'Error loading profile: $error',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          )
        ),
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Please sign in to view your profile',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.router.push(SignInRoute()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                automaticallyImplyLeading: false,
                expandedHeight: 180,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [Colors.black, Colors.blueGrey.shade900]
                            : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Center(child: _buildProfileAvatar(isDark, user.photo)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  tabs: const [
                    Tab(text: 'Profile', icon: Icon(Icons.person)),
                    Tab(text: 'Settings', icon: Icon(Icons.settings)),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(isDark, user),
                _buildSettingsTab(isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileAvatar(bool isDark, String photoUrl) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                    .withOpacity(0.3),
                blurRadius: 10 * _animationController.value,
                spreadRadius: 3 * _animationController.value,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: isDark 
                ? AppColors.neonCyan.withOpacity(0.1)
                : AppColors.brandDeepGold.withOpacity(0.1),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty 
                ? Icon(
                    Icons.person,
                    size: 30,
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(bool isDark, dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(isDark, 'Account Information'),
            _buildInfoCard(
              isDark,
              icon: Icons.person,
              title: 'Name',
              value: '${user.firstname} ${user.lastname}',
            ),
            _buildInfoCard(
              isDark,
              icon: Icons.tag,
              title: 'Username',
              value: user.username,
            ),
            _buildInfoCard(
              isDark,
              icon: Icons.email,
              title: 'Email',
              value: user.email,
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader(isDark, 'Learning Activity'),
            _buildActivityCard(
              isDark,
              title: 'Reading List',
              value: '${user.readListLength} books',
              icon: MdiIcons.bookOpenPageVariant,
              onTap: () {
                // Navigate to library with readlist filter selected
                final rootRouter = AutoRouter.of(context).root;
                final tabsRouter = rootRouter.innerRouterOf<TabsRouter>(TabsRoute.name);
                if (tabsRouter != null) {
                  // Set active index to 0 (Library tab)
                  tabsRouter.setActiveIndex(0);
                  
                  // Use future.delayed to ensure the tab has switched before setting filter
                  Future.delayed(const Duration(milliseconds: 100), () {
                    // Set filter in the Library provider
                    ref.read(libraryProvider.notifier).setFilter('readlist');
                  });
                } else {
                  // Fallback direct navigation
                  context.router.push(const LibraryRoute()).then((_) {
                    // Set filter after navigation completes
                    ref.read(libraryProvider.notifier).setFilter('readlist');
                  });
                }
              },
            ),
            _buildActivityCard(
              isDark,
              title: 'Study Progress',
              value: 'View history',
              icon: MdiIcons.chartLineVariant,
              onTap: () => context.router.push(const ExamHistoryRoute()),
            ),
            _buildActivityCard(
              isDark,
              title: 'Analytics',
              value: 'View stats',
              icon: MdiIcons.viewDashboard,
              onTap: () => context.router.push(const UserAnalyticsRoute()),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(isDark, 'Account Actions'),
            _buildActionCard(
              isDark,
              title: 'Change Username',
              subtitle: 'Update your display name',
              icon: Icons.edit,
              onTap: () => _showChangeUsernameModal(context, isDark, user.username),
            ),
            _buildActionCard(
              isDark,
              title: 'Change Password',
              subtitle: 'Update your account password',
              icon: Icons.lock_outline,
              onTap: () => _showChangePasswordConfirmation(context, isDark),
            ),
            _buildActionCard(
              isDark,
              title: 'Sign Out',
              subtitle: 'Log out of your account',
              icon: Icons.logout,
              isDestructive: true,
              onTap: () => _showSignOutConfirmation(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(isDark, 'Appearance'),
            _buildThemeToggle(isDark),

            const SizedBox(height: 24),
            _buildSectionHeader(isDark, 'Notifications'),
            _buildNotificationToggle(
              isDark,
              'App Notifications',
              'Get notified about new content and updates',
              _appNotifications,
              (value) {
                setState(() => _appNotifications = value);
                _saveNotificationPreference('pref_app_notifications', value);
              },
              Icons.notification_important,
            ),
            _buildNotificationToggle(
              isDark,
              'Email Notifications',
              'Receive important updates via email',
              _emailNotifications,
              (value) {
                setState(() => _emailNotifications = value);
                _saveNotificationPreference('pref_email_notifications', value);
              },
              Icons.email,
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(isDark, 'About'),
            _buildInfoCard(
              isDark,
              icon: Icons.info,
              title: 'Version',
              value: '1.0.0',
            ),
            _buildInfoCard(
              isDark,
              icon: Icons.verified_user,
              title: 'Terms of Service',
              value: 'View',
              onTap: () => context.router.push(const TermsOfServiceRoute()),
              ),
            _buildInfoCard(
              isDark,
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              value: 'View',
              onTap: () => context.router.push(const PrivacyPolicyRoute()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: onTap != null
            ? Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white70 : Colors.black54,
              )
            : null,
        subtitle: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActivityCard(
    bool isDark, {
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionCard(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDestructive
            ? (isDark ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50)
            : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDestructive
              ? (isDark ? Colors.red.shade800 : Colors.red.shade300)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive
                ? Colors.red
                : (isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDestructive
                ? Colors.red
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNotificationToggle(
    bool isDark,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          activeTrackColor: isDark 
              ? AppColors.neonCyan.withOpacity(0.3)
              : AppColors.brandDeepGold.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
        title: Text(
          'Dark Mode',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          'Switch between light and dark theme',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: Switch(
          value: isDark,
          onChanged: (value) {
            // Toggle theme
            ref.read(currentAppThemeNotifierProvider.notifier)
               .updateCurrentAppTheme(value);
          },
          activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          activeTrackColor: isDark
              ? AppColors.neonCyan.withOpacity(0.3)
              : AppColors.brandDeepGold.withOpacity(0.3),
        ),
      ),
    );
  }

  void _showChangeUsernameModal(BuildContext context, bool isDark, String currentUsername) {
  _usernameController.text = currentUsername;
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      // Add this to account for keyboard height
      final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
      
      return Padding(
        // Add padding at bottom equal to keyboard height
        padding: EdgeInsets.only(bottom: keyboardSpace),
        child: FractionallySizedBox(
          // Reduce height factor when keyboard is visible
          heightFactor: keyboardSpace > 0 ? 0.5 : 0.65,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              color: isDark ? AppColors.darkBg : Colors.white,
              child: Column(
                children: [
                  // Header with handle - keep as is
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey[50],
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        
                        // Title
                        Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Change Username',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              color: isDark ? Colors.white70 : Colors.black54,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      // Add controller to auto-scroll to field
                      controller: ScrollController(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Username',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              hintText: 'Enter your new username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            autofocus: true,
                            // Add this to ensure keyboard shows immediately
                            keyboardType: TextInputType.text,
                          ),
                          
                          const SizedBox(height: 16),
                          Text(
                            'Your username will be visible to other users.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          
                          // Add extra padding when keyboard is visible
                          SizedBox(height: keyboardSpace > 0 ? 28 : 100),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_usernameController.text.trim().isNotEmpty) {
                                  _updateUsername(_usernameController.text);
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Update Username',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  void _showSignOutConfirmation(BuildContext context, bool isDark) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.95),
              ),
              child: Column(
                children: [
                  // Header with handle
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [Colors.red.shade900.withOpacity(0.7), Colors.red.shade800.withOpacity(0.5)]
                            : [Colors.red.shade700.withOpacity(0.7), Colors.red.shade600.withOpacity(0.5)],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        
                        // Title with warning icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Content - use Expanded + SingleScrollView like username modal
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.red.shade900.withOpacity(0.2) 
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark 
                                    ? Colors.red.shade800 
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: Icon(
                              Icons.logout,
                              size: 40,
                              color: isDark ? Colors.red.shade300 : Colors.red.shade600,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Are you sure you want to sign out?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You will need to sign in again to access your account.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          
                          // Buttons at the bottom of scrollable area
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(
                                      color: isDark ? Colors.white70 : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _signOut();
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  void _updateUsername(String newUsername) async {
    try {
      // Validate input
      if (newUsername.trim().isEmpty) {
        ref.read(notificationServiceProvider).showNotification(
          message: 'Username cannot be empty',
          type: NotificationType.warning,
        );
        return;
      }
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.neonCyan 
                : AppColors.brandDeepGold,
          )
        ),
      );

      // Make the API request to the correct endpoint
      final response = await DioConfig.dio?.post(
        '/auth/changeUserName',
        data: {'newUsername': newUsername.trim()},
      );

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (response?.statusCode == 200) {
        // Refresh user data to get updated username
        await ref.read(userProvider.notifier).refreshUser();

        // Show success notification
        ref.read(notificationServiceProvider).showNotification(
          message: response?.data['message'] ?? 'Username updated successfully',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );
      } else if (response?.statusCode == 400) {
        // Handle the case where username is already taken
        ref.read(notificationServiceProvider).showNotification(
          message: response?.data['errorMessage'] ?? 'This username is already taken',
          type: NotificationType.warning,
        );
      } else {
        throw Exception('Failed to update username');
      }
    } catch (e) {
      // Close loading indicator if it's still showing
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Determine error message
      String errorMessage = 'Failed to update username';
      if (e is DioException) {
        if (e.response?.statusCode == 400) {
          errorMessage = e.response?.data['errorMessage'] ?? 'Username already exists';
        } else if (e.response?.statusCode == 500) {
          errorMessage = 'Server error, please try again later';
        }
      }
      
      // Show error notification
      ref.read(notificationServiceProvider).showNotification(
        message: errorMessage,
        type: NotificationType.error,
      );
    }
  }

  void _signOut() async {
  try {
    // First close the bottom sheet modal
    Navigator.pop(context);

    // Then show loading indicator with message
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey.shade900
            : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            CircularProgressIndicator(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.neonCyan 
                  : AppColors.brandDeepGold,
            ),
            const SizedBox(height: 24),
            Text(
              'Signing out...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    // Call the signout endpoint
    final response = await DioConfig.dio?.post('/auth/signout');

    // Close loading indicator
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (response?.statusCode == 200) {
      // Clear user data locally
      await ref.read(userProvider.notifier).clearUser();
      
      // Show success notification
      ref.read(notificationServiceProvider).showNotification(
        message: response?.data['message'] ?? 'Successfully signed out',
        type: NotificationType.success,
        duration: const Duration(seconds: 3),
      );

      // Short delay to ensure notification is seen before navigation
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate to auth screen
      if (context.mounted) {
        context.router.replace(const AuthRoute());
      }
    } else {
      throw Exception('Failed to sign out');
    }
  } catch (e) {
    // Close loading indicator if it's still showing
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Show error notification with more descriptive message
    ref.read(notificationServiceProvider).showNotification(
      message: 'Sign out failed. Please try again.',
      type: NotificationType.error,
      duration: const Duration(seconds: 4),
    );
  }
}

  void _showChangePasswordConfirmation(BuildContext context, bool isDark) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            color: isDark ? AppColors.darkBg : Colors.white,
            child: Column(
              children: [
                // Header with handle
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black12 : Colors.grey[50],
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      // Title
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: isDark ? Colors.white70 : Colors.black54,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Content - use Expanded + SingleScrollView like username modal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            size: 40,
                            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Change Your Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'For security reasons, we\'ll send a verification code to your email before allowing you to change your password.',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        
                        // Button at the bottom of scrollable area
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.router.push(const ResetPasswordRoute());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}
