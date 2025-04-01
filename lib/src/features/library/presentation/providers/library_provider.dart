import 'package:equatable/equatable.dart';
import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';
import 'package:eulaiq/src/features/library/data/repositories/library_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Repository provider
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref);
});

// State class for the library
class LibraryState extends Equatable {
  final List<EbookModel> ebooks;
  final PaginationModel? pagination;
  final bool isLoading;
  final String? errorMessage;
  final bool isRefreshing;
  final String? searchQuery;
  final String? filterBy;

  const LibraryState({
    this.ebooks = const [],
    this.pagination,
    this.isLoading = false,
    this.errorMessage,
    this.isRefreshing = false,
    this.searchQuery,
    this.filterBy = 'all'
  });

  LibraryState copyWith({
    List<EbookModel>? ebooks,
    PaginationModel? pagination,
    bool? isLoading,
    String? errorMessage,
    bool? isRefreshing,
    String? searchQuery,
    String? filterBy,
  }) {
    return LibraryState(
      ebooks: ebooks ?? this.ebooks,
      pagination: pagination ?? this.pagination,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      searchQuery: searchQuery ?? this.searchQuery,
      filterBy: filterBy ?? this.filterBy,
    );
  }

  @override
  List<Object?> get props => [
        ebooks,
        pagination,
        isLoading,
        errorMessage,
        isRefreshing,
        searchQuery,
        filterBy
      ];
}

// Library notifier for state management
class LibraryNotifier extends StateNotifier<LibraryState> {
  final LibraryRepository _repository;

  LibraryNotifier(this._repository) : super(const LibraryState()) {
  fetchEbooks();
}

  Future<void> fetchEbooks({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isRefreshing: true);
    } else {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      Map<String, dynamic> result;
      
      // Choose the appropriate fetch method based on filter
      switch (state.filterBy) {
        case 'favorites':
          result = await _repository.fetchUserFavorites(
            page: refresh ? 1 : state.pagination?.currentPage ?? 1,
            limit: 10,
          );
          break;
        case 'readlist':
          result = await _repository.fetchUserReadList(
            page: refresh ? 1 : state.pagination?.currentPage ?? 1,
            limit: 10,
          );
          break;
        default:
          result = await _repository.fetchUserEbooks(
            page: refresh ? 1 : state.pagination?.currentPage ?? 1,
            limit: 10,
            searchQuery: state.searchQuery,
            filterBy: state.filterBy,
          );
          break;
      }

      final ebooks = result['ebooks'] as List<EbookModel>;
      final pagination = result['pagination'] as PaginationModel;

      // IMPORTANT FIX: Always replace the list when refreshing or on first page,
      // only append when loading additional pages (page > 1)
      final isFirstPage = pagination.currentPage == 1;
      
      state = state.copyWith(
        // Replace if refreshing or first page, otherwise append
        ebooks: refresh || isFirstPage ? ebooks : [...state.ebooks, ...ebooks],
        pagination: pagination,
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshEbooks({bool keepFilter = false}) async {
    try {
      state = state.copyWith(isRefreshing: true);
      
      final filterToUse = keepFilter ? state.filterBy : state.filterBy ?? 'all';
      
      Map<String, dynamic> result;
      
      // Choose the appropriate fetch method based on filter
      switch (filterToUse) {
        case 'favorites':
          result = await _repository.fetchUserFavorites(
            page: 1,
            limit: 10,
          );
          break;
        case 'readlist':
          result = await _repository.fetchUserReadList(
            page: 1,
            limit: 10,
          );
          break;
        default:
          // Use the default fetch method for other filters
          result = await _repository.fetchUserEbooks(
            page: 1,
            limit: 10,
            searchQuery: state.searchQuery,
            filterBy: filterToUse,
          );
          break;
      }

      final ebooks = result['ebooks'] as List<EbookModel>;
      final pagination = result['pagination'] as PaginationModel;

      // ALWAYS replace the ebooks list on refresh, never append
      state = state.copyWith(
        ebooks: ebooks, // Don't append, just replace
        pagination: pagination,
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (e) {
      // Error handling
    }
  }

  Future<void> loadMoreEbooks() async {
    if (state.isLoading || !(state.pagination?.hasMore ?? false)) return;

    final nextPage = (state.pagination?.currentPage ?? 0) + 1;
    
    state = state.copyWith(isLoading: true);
    
    try {
      Map<String, dynamic> result;
      
      // Choose the appropriate fetch method based on filter
      switch (state.filterBy) {
        case 'favorites':
          result = await _repository.fetchUserFavorites(
            page: nextPage,
            limit: 10,
          );
          break;
        case 'readlist':
          result = await _repository.fetchUserReadList(
            page: nextPage,
            limit: 10,
          );
          break;
        default:
          // Use the default fetch method for other filters
          result = await _repository.fetchUserEbooks(
            page: nextPage,
            limit: 10,
            searchQuery: state.searchQuery,
            filterBy: state.filterBy,
          );
          break;
      }

      final newEbooks = result['ebooks'] as List<EbookModel>;
      final pagination = result['pagination'] as PaginationModel;

      state = state.copyWith(
        ebooks: [...state.ebooks, ...newEbooks],
        pagination: pagination,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setSearchQuery(String? query) {
    // Reset pagination when search changes
    state = state.copyWith(
      searchQuery: query,
      isLoading: true,
      errorMessage: null,
      ebooks: [], // Clear previous results when search changes
    );
    
    // Fetch from first page when search changes
    fetchEbooks(refresh: true);
  }

  void setFilter(String? filterValue) {
    // Don't do anything if filter hasn't changed
    if (filterValue == state.filterBy) return;

    // Update state with new filter and start loading
    state = state.copyWith(
      isLoading: true,
      filterBy: filterValue ?? 'all',
      errorMessage: null,
      // Don't clear existing eBooks immediately for smoother UX
      // The refresh will replace them soon
    );

    // Schedule the refresh asynchronously to allow UI to update first
    Future.microtask(() => refreshEbooks());
  }

  // Method to directly add a newly created eBook
  void addNewEbook(EbookModel ebook) {
    // Check if the ebook already exists in our list (avoid duplicates)
    final exists = state.ebooks.any((e) => e.id == ebook.id);
    print(ebook.coverImage);
    if (!exists) {
      // Add the new ebook at the beginning of the list since it's newest
      final updatedEbooks = [ebook, ...state.ebooks];
      
      // Update the state with the new list
      state = state.copyWith(
        ebooks: updatedEbooks,
        // Increment the total count in pagination if it exists
        pagination: state.pagination != null
          ? PaginationModel(
              currentPage: state.pagination!.currentPage,
              totalPages: state.pagination!.totalPages,
              totalEbooks: (state.pagination!.totalEbooks) + 1,
              hasMore: state.pagination!.hasMore,
            )
          : null,
      );
    }
  }

  /// Refreshes a specific eBook in the library
  Future<void> refreshEbook(String ebookId) async {
  try {
    // Fetch the specific eBook from the repository
    final updatedEbook = await _repository.fetchEbookDetails(id: ebookId);
    
    // Find and replace the eBook in the current list
    final currentEbooks = List<EbookModel>.from(state.ebooks);
    final index = currentEbooks.indexWhere((e) => e.id == ebookId);
    
    if (index >= 0) {
      // Replace the eBook at the found index
      currentEbooks[index] = updatedEbook;
      
      // Update state with the modified list
      state = state.copyWith(
        ebooks: currentEbooks,
      );
    }
  } catch (e) {
    print('Error refreshing eBook: $e');
  }
}
}

// Provider for the library state
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  return LibraryNotifier(repository);
});