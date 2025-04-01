import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple provider to track if library should refresh
final libraryRefreshProvider = StateProvider<bool>((ref) => false);