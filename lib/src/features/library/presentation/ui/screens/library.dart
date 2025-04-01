import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/auth/data/models/user_model.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:eulaiq/src/features/create/data/repositories/ebook_repository.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_provider.dart';
import 'package:eulaiq/src/features/library/presentation/ui/widgets/ebook_card.dart';
import 'package:eulaiq/src/features/library/presentation/ui/widgets/ebook_skeleton_card.dart';
import 'package:eulaiq/src/features/library/presentation/ui/widgets/empty_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_refresh_provider.dart';

@RoutePage()
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
    
    // We'll move the data loading logic to didChangeDependencies
    // to avoid duplicate loading
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Use a flag to ensure we only load data once during initialization
    if (!_initialLoadComplete && mounted) {
      _initialLoadComplete = true;
      
      // Check if we need to refresh based on the refresh provider
      final shouldRefresh = ref.read(libraryRefreshProvider);
      
      // IMPORTANT: Use Future.microtask to delay provider updates
      Future.microtask(() {
        if (!mounted) return;
        
        if (shouldRefresh) {
          ref.read(libraryRefreshProvider.notifier).state = false;
          ref.read(libraryProvider.notifier).fetchEbooks(refresh: true);
        } else {
          // Only fetch if we haven't already
          if (ref.read(libraryProvider).ebooks.isEmpty) {
            ref.read(libraryProvider.notifier).fetchEbooks(refresh: false);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(libraryProvider.notifier).loadMoreEbooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryState = ref.watch(libraryProvider);
    final userState = ref.watch(userProvider);
    
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
          child: Column(
            children: [
              _buildHeader(context, isDark, userState.valueOrNull),
              
              // Search bar
              _buildSearchBar(isDark),
              
              // Filter chips
              _buildFilterChips(isDark),
              
              // Main content
              Expanded(
                child: libraryState.isRefreshing
                  ? _buildLoadingIndicator(isDark)
                  : _buildMainContent(isDark, libraryState),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        // Increase padding from 90 to 120 pixels to raise the button higher
        padding: const EdgeInsets.only(bottom: 120.0),
        child: FloatingActionButton(
          onPressed: () {
            // Get the root router
            final rootRouter = AutoRouter.of(context).root;
            
            // Find the tabs router and set its active index to 2 (Create tab)
            final tabsRouter = rootRouter.innerRouterOf<TabsRouter>(TabsRoute.name);
            if (tabsRouter != null) {
              tabsRouter.setActiveIndex(2); // Create tab is at index 2
            } else {
              // Fallback to direct navigation if we're not in the tabs router
              context.router.navigate(const CreateRoute());
            }
          },
          backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Adjust location
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, UserModel? user) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [
                    AppColors.darkBg.withOpacity(0.9),
                    AppColors.darkBg.withOpacity(0.85),
                  ]
                : [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.95),
                  ],
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Title section with icon
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [AppColors.neonCyan.withOpacity(0.8), AppColors.neonPurple.withOpacity(0.5)]
                            : [AppColors.brandDeepGold.withOpacity(0.8), AppColors.brandWarmOrange.withOpacity(0.5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                              ? AppColors.neonCyan.withOpacity(0.2)
                              : AppColors.brandDeepGold.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        MdiIcons.bookshelf,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'My Library',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.neutralDarkGray,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Add a search button before the user profile
              IconButton(
                icon: Icon(
                  Icons.search,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
                onPressed: () {
                  setState(() {
                    _isSearchExpanded = !_isSearchExpanded;
                  });
                },
              ),
              
              // User profile (if available)
              if (user != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: user.photo.isNotEmpty
                    ? Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark 
                              ? AppColors.neonCyan.withOpacity(0.5)
                              : AppColors.brandDeepGold.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            user.photo,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark 
                              ? AppColors.neonCyan.withOpacity(0.5)
                              : AppColors.brandDeepGold.withOpacity(0.5),
                            width: 1.5,
                          ),
                          color: isDark ? Colors.grey[850] : Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            user.firstname.isNotEmpty ? user.firstname[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isSearchExpanded ? 72 : 0,
      // Add a clip behavior to prevent content from showing when collapsed
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: _isSearchExpanded ? 12 : 0),
      decoration: BoxDecoration(
        // Add a matching background color to prevent transparency issues
        color: isDark ? AppColors.darkBg.withOpacity(0.95) : Colors.white.withOpacity(0.95),
      ),
      child: Opacity(
        // Animate opacity along with height for smoother transition
        opacity: _isSearchExpanded ? 1.0 : 0.0,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search your eBooks...',
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                // Explicitly refresh with null query
                ref.read(libraryProvider.notifier).setSearchQuery("");
                ref.read(libraryProvider.notifier).refreshEbooks();
                setState(() {
                  _isSearchExpanded = false;
                });
              },
            ),
            filled: true,
            fillColor: isDark ? Colors.black26 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark 
                  ? AppColors.neonCyan.withOpacity(0.3)
                  : AppColors.brandDeepGold.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark 
                  ? AppColors.neonCyan.withOpacity(0.3)
                  : AppColors.brandDeepGold.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            ),
          ),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          onChanged: (value) {
            // Trigger search after 2+ characters
            if (value.length > 1) {
              ref.read(libraryProvider.notifier).setSearchQuery(value);
            } else if (value.isEmpty) {
              // Explicitly refresh with null query when cleared
              ref.read(libraryProvider.notifier).setSearchQuery("");
              ref.read(libraryProvider.notifier).refreshEbooks();
            }
          },
        ),
      ),
    );
  }

  // Update the _buildFilterChips method with icons for all filters
  Widget _buildFilterChips(bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg.withOpacity(0.95) : Colors.white.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.neonCyan.withOpacity(0.05)
                : AppColors.brandDeepGold.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add icons to all filter chips for consistency
          _buildFilterChip(isDark, 'All', 'all', icon: MdiIcons.bookshelf),
          _buildFilterChip(isDark, 'Favorites', 'favorites', icon: MdiIcons.heartOutline),
          _buildFilterChip(isDark, 'Reading List', 'readlist', icon: MdiIcons.bookmarkOutline),
          _buildFilterChip(isDark, 'Complete', 'complete', icon: MdiIcons.checkCircleOutline),
          _buildFilterChip(isDark, 'Processing', 'processing', icon: MdiIcons.progressClock),
          _buildFilterChip(isDark, 'With Audio', 'audio', icon: MdiIcons.headphones),
          _buildFilterChip(isDark, 'With Quizzes', 'quiz', icon: MdiIcons.checkboxMarkedCircleOutline),
          _buildFilterChip(isDark, 'Recent', 'recent', icon: MdiIcons.history),
        ],
      ),
    );
  }

  // Update the _buildFilterChip method to optionally include an icon
  Widget _buildFilterChip(bool isDark, String label, String? filterValue, {IconData? icon}) {
  final currentFilter = ref.watch(libraryProvider).filterBy;
  
  // "All" chip should be selected when no filter is active
  final isSelected = currentFilter == filterValue;
  
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected
                ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(libraryProvider.notifier).setFilter(selected ? filterValue : 'all');
      },
      backgroundColor: isDark ? Colors.black12 : Colors.white,
      selectedColor: isDark ? AppColors.neonCyan.withOpacity(0.2) : AppColors.brandDeepGold.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected
          ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
          : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
            ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
            : Colors.transparent,
        ),
      ),
    ),
  );
}

  Widget _buildMainContent(bool isDark, LibraryState libraryState) {
    if (libraryState.errorMessage != null) {
      return _buildErrorView(isDark, libraryState.errorMessage!);
    }
    
    if (libraryState.isLoading && libraryState.ebooks.isEmpty) {
      return _buildLoadingGrid(isDark);
    }
    
    if (libraryState.ebooks.isEmpty) {
      // Check if we're displaying empty results due to search
      if (libraryState.searchQuery != null && libraryState.searchQuery!.isNotEmpty) {
        return _buildNoSearchResultsView(isDark, libraryState.searchQuery!);
      }
      
      // Otherwise show the general empty library view
      return EmptyLibrary(
        onCreatePressed: () {
          // Navigate to create tab
          final rootRouter = AutoRouter.of(context).root;
          final tabsRouter = rootRouter.innerRouterOf<TabsRouter>(TabsRoute.name);
          if (tabsRouter != null) {
            tabsRouter.setActiveIndex(2); // Create tab is at index 2
          } else {
            context.router.navigate(const CreateRoute());
          }
        },
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).refreshEbooks(),
      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: libraryState.isLoading 
          ? libraryState.ebooks.length + 2
          : libraryState.ebooks.length,
        itemBuilder: (context, index) {
          if (index >= libraryState.ebooks.length) {
            return const EbookSkeletonCard();
          }
          
          return EbookCard(
            ebook: libraryState.ebooks[index],
            onRetryProcessing: _retryProcessing,
          );
        },
      ),
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6, // Show 6 skeleton items
      itemBuilder: (_, __) => const EbookSkeletonCard(),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return Center(
      child: CircularProgressIndicator(
        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
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
            'Something went wrong',
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
            onPressed: () => ref.read(libraryProvider.notifier).fetchEbooks(),
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

  // Add this method to _LibraryScreenState
  void _retryProcessing(String ebookId) async {
  try {
     // Show loading indicator using notification service
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.showNotification(
      message: 'Restarting processing for ebook...',
      type: NotificationType.info,
      duration: const Duration(seconds: 2),
    );
    
    // Create an instance of the EbookRepository
    final repository = EbookRepository();
    
    // Call the continueProcessing method
    final result = await repository.continueProcessing(ebookId);
    
    // Check the result and show appropriate message
    if (result.status == ProcessingStatus.processing) {
      notificationService.showNotification(
        message: 'Processing restarted successfully!',
        type: NotificationType.success,
      );
      
      // Refresh the library to show updated status
      ref.read(libraryProvider.notifier).refreshEbooks();
    } else {
      // Show error message
      notificationService.showNotification(
        message: 'Failed to restart processing: ${result.errorMessage}',
        type: NotificationType.error,
      );
    }
  } catch (e) {
    // Show error message
    ref.read(notificationServiceProvider).showNotification(
      message: 'Error: ${e.toString()}',
      type: NotificationType.error,
    );
  }
}

  Widget _buildNoSearchResultsView(bool isDark, String searchQuery) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Icon(
                MdiIcons.magnifyClose,
                size: 80,
                color: isDark ? Colors.white30 : Colors.grey[300],
              ),
              const SizedBox(height: 24),
              Text(
                'No results found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We couldn\'t find any eBooks matching "$searchQuery"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Clear search
                  _searchController.clear();
                  ref.read(libraryProvider.notifier).setSearchQuery("");
                  setState(() {
                    _isSearchExpanded = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Clear Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}