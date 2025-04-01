import 'package:eulaiq/src/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:ui';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';

// Change from autoDispose to regular provider to maintain state across reloads
final homeScrollControllerProvider = Provider((ref) {
  final controller = ScrollController();
  ref.onDispose(() {
    controller.dispose(); // Proper disposal when actually needed
  });
  return controller;
});

@RoutePage()
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with AutomaticKeepAliveClientMixin {
  // Add AutomaticKeepAliveClientMixin to preserve state during tab navigation
  late ScrollController scrollController;
  
  @override
  void initState() {
    super.initState();
    // Get controller reference in initState instead of build
    scrollController = ref.read(homeScrollControllerProvider);
  }
  
  @override
  void dispose() {
    // Don't dispose the controller here as it's managed by the provider
    super.dispose();
  }
  
  @override
  bool get wantKeepAlive => true; // Keep this widget alive
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final viewPadding = MediaQuery.of(context).viewPadding;
    
    // Use watch just for the user state, not the controller
    final userState = ref.watch(userProvider);
    
    return Scaffold(
      body: Container(
        // Enhanced background matching auth screen style
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
                  AppColors.neutralLightGray,
                  Colors.white,
                  AppColors.brandDeepGold.withOpacity(0.1),
                ],
          ),
        ),
        // Ensure minimum height
        constraints: BoxConstraints(
          minHeight: size.height,
        ),
        child: CustomScrollView(
          key: const PageStorageKey('homeScrollView'),
          controller: scrollController, // Use the controller from initState
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Using SliverPersistentHeader with increased size
            SliverPersistentHeader(
              key: const ValueKey('homeHeader'),
              pinned: true,
              floating: true,
              delegate: _HeaderDelegate(
                isDark: isDark,
                viewPadding: viewPadding,
                headerMaxExtent: 220.0, // Increased to properly fit content
                headerMinExtent: 210.0,  // Increased for better appearance when collapsed
                user: userState.valueOrNull, // Pass user data to header
              ),
            ),
            
            // Content area with bottom padding for navigation bar
            SliverPadding(
              padding: EdgeInsets.only(bottom: 80 + bottomPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Ensure we have at least minimal content to fill viewport
                  SizedBox(
                    height: size.height - 280 - bottomPadding,
                    child: const Center(
                      child: Text(
                        'Content will be added here',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: _buildAICopilotFAB(isDark),
      ),
    );
  }

  // Change this method to remove the Hero wrapper
  Widget _buildAICopilotFAB(bool isDark) {
    // Remove the Hero widget and use heroTag property instead
    return FloatingActionButton(
      heroTag: 'ai_copilot_fab', // Set custom hero tag here
      onPressed: () {},
      backgroundColor: isDark 
        ? AppColors.darkBg 
        : Colors.white,
      elevation: 4,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark 
                ? AppColors.neonCyan.withOpacity(0.3)
                : AppColors.brandDeepGold.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset(
          'assets/brand_assets/Eula.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// Custom delegate for flexible header with improved sizing and layout
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final EdgeInsets viewPadding;
  final double headerMaxExtent;
  final double headerMinExtent;
  final UserModel? user; // Add user parameter

  _HeaderDelegate({
    required this.isDark,
    required this.viewPadding,
    required this.headerMaxExtent,
    required this.headerMinExtent,
    this.user, // Make it optional
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / maxExtent;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [
                    AppColors.darkBg.withOpacity(0.9),
                    AppColors.darkBg.withOpacity(0.85),
                    AppColors.darkBg.withOpacity(0.8),
                  ]
                : [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.95),
                    AppColors.brandDeepGold.withOpacity(0.05),
                  ],
            ),
            // Subtle bottom border
            border: Border(
              bottom: BorderSide(
                color: isDark
                  ? AppColors.neonCyan.withOpacity(0.1)
                  : AppColors.brandDeepGold.withOpacity(0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  // Content that fades out when scrolling
                  Opacity(
                    opacity: 1 - progress,
                    child: Column(
                      children: [
                        // Top row with profile and actions - fixed height
                        SizedBox(
                          height: 60,
                          child: _buildTopRow(isDark, context),
                        ),
                        
                        // Search bar - fixed height
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: _buildSearchBar(isDark, context),
                        ),
                        
                        // Filter chips - fixed height
                        SizedBox(
                          height: 40,
                          child: _buildFilterChips(isDark, context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Collapsed title that appears when scrolling
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: progress,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 30,
                              width: 30,
                              margin: const EdgeInsets.only(right: 12),
                              child: Image.asset(
                                'assets/brand_assets/Eula.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            Text(
                              'EulaIQ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                foreground: Paint()..shader = LinearGradient(
                                  colors: isDark 
                                    ? [AppColors.neonCyan, AppColors.neonPurple]
                                    : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
                                ).createShader(const Rect.fromLTWH(0, 0, 100, 0)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(bool isDark, BuildContext context) {
    return Padding(
      key: const ValueKey('topRowHeader'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile section with proper layout
          Expanded(
            child: Row(
              children: [
                // Profile picture with gradient border
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [AppColors.neonCyan, AppColors.neonPurple]
                        : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                            .withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: user?.photo != null && user!.photo.isNotEmpty
                      ? Image.network(
                          user!.photo,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(isDark),
                        )
                      : _buildDefaultAvatar(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark 
                            ? Colors.white70
                            : AppColors.neutralDarkGray.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        user != null 
                          ? '${user!.firstname} ${user!.lastname}'
                          : 'Guest User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.neutralDarkGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons with proper spacing
          Row(
            children: [
              _buildActionButton(
                icon: MdiIcons.bell,
                isDark: isDark,
                hasNotification: true,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: MdiIcons.cogOutline,
                isDark: isDark,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required bool isDark,
    bool hasNotification = false,
    required VoidCallback onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: isDark 
              ? Colors.grey[850]!.withOpacity(0.5)
              : AppColors.neutralLightGray.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              size: 20,
            ),
            onPressed: onTap,
            padding: EdgeInsets.zero,
          ),
        ),
        if (hasNotification)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isDark ? AppColors.neonCyan : AppColors.brandWarmOrange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBg : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.neonCyan : AppColors.brandWarmOrange).withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark, BuildContext context) {
    return Container(
      key: const ValueKey('searchBar'),
      height: 45, // Slightly increased height
      decoration: BoxDecoration(
        color: isDark 
          ? Colors.grey[850]!.withOpacity(0.3)
          : AppColors.neutralLightGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark 
            ? AppColors.neonCyan.withOpacity(0.15)
            : AppColors.brandDeepGold.withOpacity(0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            MdiIcons.magnify,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search medical content...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark 
                    ? Colors.white60
                    : AppColors.neutralDarkGray.withOpacity(0.5),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.neutralDarkGray,
              ),
            ),
          ),
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isDark 
                    ? AppColors.neonCyan.withOpacity(0.15)
                    : AppColors.brandDeepGold.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: Center(
              child: Icon(
                MdiIcons.tuneVertical,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark, BuildContext context) {
    final filters = ['All', 'Books', 'Videos', 'Audio', 'Questions'];
    
    return ListView.builder(
      key: const ValueKey('filterChips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final filter = filters[index];
        final isSelected = filter == 'All';
        
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                : (isDark ? Colors.grey[850]!.withOpacity(0.3) : AppColors.neutralLightGray.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? Colors.transparent
                  : (isDark ? AppColors.neonCyan.withOpacity(0.15) : AppColors.brandDeepGold.withOpacity(0.15)),
                width: 0.5,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.3),
                  blurRadius: 5,
                  spreadRadius: 0.5,
                ),
              ] : null,
            ),
            child: Center(
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? AppColors.darkBg : Colors.white)
                      : (isDark ? Colors.white : AppColors.neutralDarkGray),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      child: Text(
        user?.firstname.isNotEmpty == true 
            ? user!.firstname[0].toUpperCase() 
            : 'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        ),
      ),
    );
  }

  @override
  double get maxExtent => headerMaxExtent;

  @override
  double get minExtent => headerMinExtent;

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark || 
           oldDelegate.headerMaxExtent != headerMaxExtent || 
           oldDelegate.headerMinExtent != headerMinExtent ||
           oldDelegate.user?.id != user?.id; // Add user ID comparison
  }
}