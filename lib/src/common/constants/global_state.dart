import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loadingProvider = StateProvider<bool>((ref) => false);
final googleSignInLoadingProvider = StateProvider<bool>((ref) => false);
final guestSignInLoadingProvider = StateProvider<bool>((ref) => false);
final errorProvider = StateProvider<String?>((ref) => null);
final successProvider = StateProvider<String?>((ref) => null);
final statusProvider = StateProvider<String?>((ref) => null);
final email = StateProvider<String?>((ref) => null);
final statusCodeProvider = StateProvider<int?>((ref) => null);
final emailProvider = StateProvider<String>((ref) => '');

// Function to set error and success messages and clear them after 5 seconds
void setMessages(WidgetRef ref, {String? errorMessage, String? successMessage}) {
  // Set the error message if provided
  if (errorMessage != null) {
    ref.read(errorProvider.notifier).state = errorMessage; // Set the error message
  }

  // Set the success message if provided
  if (successMessage != null) {
    ref.read(successProvider.notifier).state = successMessage; // Set the success message
  }

  // Clear the error message after 5 seconds
  Timer(const Duration(seconds: 5), () {
    if (errorMessage != null) {
      ref.read(errorProvider.notifier).state = null; // Clear the error message
    }

    if (successMessage != null) {
      ref.read(successProvider.notifier).state = null; // Clear the success message
    }
  });
}
