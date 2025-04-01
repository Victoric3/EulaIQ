import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:ui';

@RoutePage()
class TabsScreenSmall extends ConsumerWidget {
  const TabsScreenSmall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AutoTabsRouter(
      routes: const [
        HomeRoute(),
        LibraryRoute(),
        CreateRoute(),
        ScheduleRoute(),
        CommunityRoute(),
      ],
      transitionBuilder: (context, child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        return Scaffold(
          body: child,
          extendBody: true, // Make body extend behind bottom nav
          bottomNavigationBar: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  // Consistent color with app theme
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            AppColors.darkBg.withOpacity(0.85),
                            AppColors.darkBg.withOpacity(0.95),
                          ]
                        : [
                            Colors.white.withOpacity(0.85),
                            Colors.white.withOpacity(0.95),
                          ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  // Subtle top border for definition
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.neonCyan.withOpacity(0.1)
                          : AppColors.brandDeepGold.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                child: BottomNavigationBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: isDark 
                    ? AppColors.neonCyan 
                    : AppColors.brandDeepGold,
                  unselectedItemColor: isDark
                    ? Colors.white.withOpacity(0.5)
                    : AppColors.neutralDarkGray.withOpacity(0.5),
                  showUnselectedLabels: true,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  items: <BottomNavigationBarItem>[
                    _buildNavItem(MdiIcons.homeVariant, 'Home', tabsRouter.activeIndex == 0, isDark),
                    _buildNavItem(MdiIcons.bookshelf, 'Library', tabsRouter.activeIndex == 1, isDark),
                    _buildNavItem(MdiIcons.plusCircle, 'Create', tabsRouter.activeIndex == 2, isDark, isCreate: true),
                    _buildNavItem(MdiIcons.calendarText, 'Schedule', tabsRouter.activeIndex == 3, isDark),
                    _buildNavItem(MdiIcons.accountGroup, 'Community', tabsRouter.activeIndex == 4, isDark),
                  ],
                  currentIndex: tabsRouter.activeIndex,
                  onTap: tabsRouter.setActiveIndex,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, bool isActive, bool isDark, {bool isCreate = false}) {
    return BottomNavigationBarItem(
      icon: Container(
        height: 32,
        width: 32,
        margin: const EdgeInsets.only(bottom: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: isCreate ? BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.neonCyan, AppColors.neonPurple]
                  : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isDark 
                  ? AppColors.neonCyan.withOpacity(0.3)
                  : AppColors.brandDeepGold.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ) : isActive ? BoxDecoration(
            color: isDark
                ? AppColors.neonCyan.withOpacity(0.15)
                : AppColors.brandDeepGold.withOpacity(0.15),
            shape: BoxShape.circle,
          ) : null,
          child: Icon(
            icon,
            size: isActive ? 24 : 20,
            color: isCreate 
                ? Colors.white
                : isActive
                    ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                    : null,
          ),
        ),
      ),
      label: label,
    );
  }
}
