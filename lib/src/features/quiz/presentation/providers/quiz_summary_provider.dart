import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/features/quiz/data/repositories/quiz_repository.dart';

class QuizSummaryState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  QuizSummaryState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
  });

  QuizSummaryState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) {
    return QuizSummaryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      data: data ?? this.data,
    );
  }
}

class QuizSummaryNotifier extends StateNotifier<QuizSummaryState> {
  final QuizRepository _repository;

  QuizSummaryNotifier(this._repository) : super(QuizSummaryState());

  Future<void> fetchQuizSummary(String ebookId) async {
    print("tried to fetch quiz summary for ebookId: $ebookId");
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final data = await _repository.getEbookQuizSummary(ebookId);
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        errorMessage: e.toString(),
      );
    }
  }
}

final quizSummaryProvider = StateNotifierProvider.family<QuizSummaryNotifier, QuizSummaryState, String>(
  (ref, ebookId) => QuizSummaryNotifier(QuizRepository())..fetchQuizSummary(ebookId),
);