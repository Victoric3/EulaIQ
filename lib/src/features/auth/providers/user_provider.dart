import 'package:eulaiq/src/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';


// Make this a StateProvider to better handle initialization
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserRepository(prefs: prefs);
});

// User provider with better error handling
final userProvider = StateNotifierProvider<UserNotifier, AsyncValue<UserModel?>>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UserNotifier(repository);
});

class UserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final UserRepository _repository;
  
  UserNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      // Try to get cached user first
      final cachedUser = _repository.getCachedUser();
      if (cachedUser != null) {
        state = AsyncValue.data(cachedUser);
      }
      
      // Then try to fetch fresh data
      final user = await _repository.fetchAndCacheUserData();
      if (user != null) {
        state = AsyncValue.data(user);
      } else if (state is AsyncLoading) {
        // Only set to null if we're still loading (no cached data)
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      print('Error loading user: $e');
      // Keep cached data if available
      if (state is! AsyncData) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repository.fetchAndCacheUserData();
      if (user != null) {
        state = AsyncValue.data(user);
      }
    } catch (e) {
      // Only update state if refresh fails with error
      print('Error refreshing user: $e');
    }
  }

  Future<void> clearUser() async {
    await _repository.clearUserData();
    state = const AsyncValue.data(null);
  }
}