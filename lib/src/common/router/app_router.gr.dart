// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

abstract class _$AppRouter extends RootStackRouter {
  // ignore: unused_element
  _$AppRouter();

  @override
  final Map<String, PageFactory> pagesMap = {
    AuthRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const AuthScreen(),
      );
    },
    CommunityRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const CommunityScreen(),
      );
    },
    CreateRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const CreateScreen(),
      );
    },
    DocumentViewerRoute.name: (routeData) {
      final args = routeData.argsAs<DocumentViewerRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: DocumentViewerScreen(
          key: args.key,
          fileUrl: args.fileUrl,
          title: args.title,
          fileType: args.fileType,
          ebookId: args.ebookId,
          page: args.page,
        ),
      );
    },
    EbookDetailRoute.name: (routeData) {
      final args = routeData.argsAs<EbookDetailRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: EbookDetailScreen(
          key: args.key,
          id: args.id,
          slug: args.slug,
        ),
      );
    },
    ExamHistoryRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const ExamHistoryScreen(),
      );
    },
    HomeRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const HomeScreen(),
      );
    },
    IntroRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const IntroScreen(),
      );
    },
    LibraryRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const LibraryScreen(),
      );
    },
    MeRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const MeScreen(),
      );
    },
    PrivacyPolicyRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const PrivacyPolicyScreen(),
      );
    },
    QuizOptionsRoute.name: (routeData) {
      final args = routeData.argsAs<QuizOptionsRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: QuizOptionsScreen(
          key: args.key,
          ebookId: args.ebookId,
          preSelectedExamId: args.preSelectedExamId,
        ),
      );
    },
    QuizResultsRoute.name: (routeData) {
      final args = routeData.argsAs<QuizResultsRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: QuizResultsScreen(
          key: args.key,
          examHistoryId: args.examHistoryId,
        ),
      );
    },
    QuizReviewRoute.name: (routeData) {
      final args = routeData.argsAs<QuizReviewRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: QuizReviewScreen(
          key: args.key,
          questions: args.questions,
        ),
      );
    },
    QuizRoute.name: (routeData) {
      final args = routeData.argsAs<QuizRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: QuizScreen(
          key: args.key,
          questions: args.questions,
          durationPerQuestion: args.durationPerQuestion,
          totalDuration: args.totalDuration,
          examOptions: args.examOptions,
        ),
      );
    },
    ReaderRoute.name: (routeData) {
      final args = routeData.argsAs<ReaderRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ReaderScreen(
          key: args.key,
          storyId: args.storyId,
          title: args.title,
        ),
      );
    },
    ResetPasswordRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const ResetPasswordScreen(),
      );
    },
    ScheduleRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const ScheduleScreen(),
      );
    },
    SignInRoute.name: (routeData) {
      final args = routeData.argsAs<SignInRouteArgs>(
          orElse: () => const SignInRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: SignInScreen(key: args.key),
      );
    },
    SignUpRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const SignUpScreen(),
      );
    },
    SplashRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const SplashScreen(),
      );
    },
    TabsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const TabsScreen(),
      );
    },
    TabsRouteSmall.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const TabsScreenSmall(),
      );
    },
    TermsOfServiceRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const TermsOfServiceScreen(),
      );
    },
    UserAnalyticsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const UserAnalyticsScreen(),
      );
    },
    VerificationCodeRoute.name: (routeData) {
      final args = routeData.argsAs<VerificationCodeRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: VerificationCodeScreen(
          verificationType: args.verificationType,
          key: args.key,
        ),
      );
    },
  };
}

/// generated route for
/// [AuthScreen]
class AuthRoute extends PageRouteInfo<void> {
  const AuthRoute({List<PageRouteInfo>? children})
      : super(
          AuthRoute.name,
          initialChildren: children,
        );

  static const String name = 'AuthRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [CommunityScreen]
class CommunityRoute extends PageRouteInfo<void> {
  const CommunityRoute({List<PageRouteInfo>? children})
      : super(
          CommunityRoute.name,
          initialChildren: children,
        );

  static const String name = 'CommunityRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [CreateScreen]
class CreateRoute extends PageRouteInfo<void> {
  const CreateRoute({List<PageRouteInfo>? children})
      : super(
          CreateRoute.name,
          initialChildren: children,
        );

  static const String name = 'CreateRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [DocumentViewerScreen]
class DocumentViewerRoute extends PageRouteInfo<DocumentViewerRouteArgs> {
  DocumentViewerRoute({
    Key? key,
    required String fileUrl,
    required String title,
    String? fileType,
    required String ebookId,
    int? page,
    List<PageRouteInfo>? children,
  }) : super(
          DocumentViewerRoute.name,
          args: DocumentViewerRouteArgs(
            key: key,
            fileUrl: fileUrl,
            title: title,
            fileType: fileType,
            ebookId: ebookId,
            page: page,
          ),
          initialChildren: children,
        );

  static const String name = 'DocumentViewerRoute';

  static const PageInfo<DocumentViewerRouteArgs> page =
      PageInfo<DocumentViewerRouteArgs>(name);
}

class DocumentViewerRouteArgs {
  const DocumentViewerRouteArgs({
    this.key,
    required this.fileUrl,
    required this.title,
    this.fileType,
    required this.ebookId,
    this.page,
  });

  final Key? key;

  final String fileUrl;

  final String title;

  final String? fileType;

  final String ebookId;

  final int? page;

  @override
  String toString() {
    return 'DocumentViewerRouteArgs{key: $key, fileUrl: $fileUrl, title: $title, fileType: $fileType, ebookId: $ebookId, page: $page}';
  }
}

/// generated route for
/// [EbookDetailScreen]
class EbookDetailRoute extends PageRouteInfo<EbookDetailRouteArgs> {
  EbookDetailRoute({
    Key? key,
    required String id,
    String? slug,
    List<PageRouteInfo>? children,
  }) : super(
          EbookDetailRoute.name,
          args: EbookDetailRouteArgs(
            key: key,
            id: id,
            slug: slug,
          ),
          initialChildren: children,
        );

  static const String name = 'EbookDetailRoute';

  static const PageInfo<EbookDetailRouteArgs> page =
      PageInfo<EbookDetailRouteArgs>(name);
}

class EbookDetailRouteArgs {
  const EbookDetailRouteArgs({
    this.key,
    required this.id,
    this.slug,
  });

  final Key? key;

  final String id;

  final String? slug;

  @override
  String toString() {
    return 'EbookDetailRouteArgs{key: $key, id: $id, slug: $slug}';
  }
}

/// generated route for
/// [ExamHistoryScreen]
class ExamHistoryRoute extends PageRouteInfo<void> {
  const ExamHistoryRoute({List<PageRouteInfo>? children})
      : super(
          ExamHistoryRoute.name,
          initialChildren: children,
        );

  static const String name = 'ExamHistoryRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [HomeScreen]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
      : super(
          HomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'HomeRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [IntroScreen]
class IntroRoute extends PageRouteInfo<void> {
  const IntroRoute({List<PageRouteInfo>? children})
      : super(
          IntroRoute.name,
          initialChildren: children,
        );

  static const String name = 'IntroRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [LibraryScreen]
class LibraryRoute extends PageRouteInfo<void> {
  const LibraryRoute({List<PageRouteInfo>? children})
      : super(
          LibraryRoute.name,
          initialChildren: children,
        );

  static const String name = 'LibraryRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [MeScreen]
class MeRoute extends PageRouteInfo<void> {
  const MeRoute({List<PageRouteInfo>? children})
      : super(
          MeRoute.name,
          initialChildren: children,
        );

  static const String name = 'MeRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [PrivacyPolicyScreen]
class PrivacyPolicyRoute extends PageRouteInfo<void> {
  const PrivacyPolicyRoute({List<PageRouteInfo>? children})
      : super(
          PrivacyPolicyRoute.name,
          initialChildren: children,
        );

  static const String name = 'PrivacyPolicyRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [QuizOptionsScreen]
class QuizOptionsRoute extends PageRouteInfo<QuizOptionsRouteArgs> {
  QuizOptionsRoute({
    Key? key,
    required String ebookId,
    String? preSelectedExamId,
    List<PageRouteInfo>? children,
  }) : super(
          QuizOptionsRoute.name,
          args: QuizOptionsRouteArgs(
            key: key,
            ebookId: ebookId,
            preSelectedExamId: preSelectedExamId,
          ),
          initialChildren: children,
        );

  static const String name = 'QuizOptionsRoute';

  static const PageInfo<QuizOptionsRouteArgs> page =
      PageInfo<QuizOptionsRouteArgs>(name);
}

class QuizOptionsRouteArgs {
  const QuizOptionsRouteArgs({
    this.key,
    required this.ebookId,
    this.preSelectedExamId,
  });

  final Key? key;

  final String ebookId;

  final String? preSelectedExamId;

  @override
  String toString() {
    return 'QuizOptionsRouteArgs{key: $key, ebookId: $ebookId, preSelectedExamId: $preSelectedExamId}';
  }
}

/// generated route for
/// [QuizResultsScreen]
class QuizResultsRoute extends PageRouteInfo<QuizResultsRouteArgs> {
  QuizResultsRoute({
    Key? key,
    required String examHistoryId,
    List<PageRouteInfo>? children,
  }) : super(
          QuizResultsRoute.name,
          args: QuizResultsRouteArgs(
            key: key,
            examHistoryId: examHistoryId,
          ),
          initialChildren: children,
        );

  static const String name = 'QuizResultsRoute';

  static const PageInfo<QuizResultsRouteArgs> page =
      PageInfo<QuizResultsRouteArgs>(name);
}

class QuizResultsRouteArgs {
  const QuizResultsRouteArgs({
    this.key,
    required this.examHistoryId,
  });

  final Key? key;

  final String examHistoryId;

  @override
  String toString() {
    return 'QuizResultsRouteArgs{key: $key, examHistoryId: $examHistoryId}';
  }
}

/// generated route for
/// [QuizReviewScreen]
class QuizReviewRoute extends PageRouteInfo<QuizReviewRouteArgs> {
  QuizReviewRoute({
    Key? key,
    required List<Map<String, dynamic>> questions,
    List<PageRouteInfo>? children,
  }) : super(
          QuizReviewRoute.name,
          args: QuizReviewRouteArgs(
            key: key,
            questions: questions,
          ),
          initialChildren: children,
        );

  static const String name = 'QuizReviewRoute';

  static const PageInfo<QuizReviewRouteArgs> page =
      PageInfo<QuizReviewRouteArgs>(name);
}

class QuizReviewRouteArgs {
  const QuizReviewRouteArgs({
    this.key,
    required this.questions,
  });

  final Key? key;

  final List<Map<String, dynamic>> questions;

  @override
  String toString() {
    return 'QuizReviewRouteArgs{key: $key, questions: $questions}';
  }
}

/// generated route for
/// [QuizScreen]
class QuizRoute extends PageRouteInfo<QuizRouteArgs> {
  QuizRoute({
    Key? key,
    required List<Map<String, dynamic>> questions,
    required int durationPerQuestion,
    required int totalDuration,
    required Map<String, dynamic> examOptions,
    List<PageRouteInfo>? children,
  }) : super(
          QuizRoute.name,
          args: QuizRouteArgs(
            key: key,
            questions: questions,
            durationPerQuestion: durationPerQuestion,
            totalDuration: totalDuration,
            examOptions: examOptions,
          ),
          initialChildren: children,
        );

  static const String name = 'QuizRoute';

  static const PageInfo<QuizRouteArgs> page = PageInfo<QuizRouteArgs>(name);
}

class QuizRouteArgs {
  const QuizRouteArgs({
    this.key,
    required this.questions,
    required this.durationPerQuestion,
    required this.totalDuration,
    required this.examOptions,
  });

  final Key? key;

  final List<Map<String, dynamic>> questions;

  final int durationPerQuestion;

  final int totalDuration;

  final Map<String, dynamic> examOptions;

  @override
  String toString() {
    return 'QuizRouteArgs{key: $key, questions: $questions, durationPerQuestion: $durationPerQuestion, totalDuration: $totalDuration, examOptions: $examOptions}';
  }
}

/// generated route for
/// [ReaderScreen]
class ReaderRoute extends PageRouteInfo<ReaderRouteArgs> {
  ReaderRoute({
    Key? key,
    required String storyId,
    required String title,
    List<PageRouteInfo>? children,
  }) : super(
          ReaderRoute.name,
          args: ReaderRouteArgs(
            key: key,
            storyId: storyId,
            title: title,
          ),
          initialChildren: children,
        );

  static const String name = 'ReaderRoute';

  static const PageInfo<ReaderRouteArgs> page = PageInfo<ReaderRouteArgs>(name);
}

class ReaderRouteArgs {
  const ReaderRouteArgs({
    this.key,
    required this.storyId,
    required this.title,
  });

  final Key? key;

  final String storyId;

  final String title;

  @override
  String toString() {
    return 'ReaderRouteArgs{key: $key, storyId: $storyId, title: $title}';
  }
}

/// generated route for
/// [ResetPasswordScreen]
class ResetPasswordRoute extends PageRouteInfo<void> {
  const ResetPasswordRoute({List<PageRouteInfo>? children})
      : super(
          ResetPasswordRoute.name,
          initialChildren: children,
        );

  static const String name = 'ResetPasswordRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [ScheduleScreen]
class ScheduleRoute extends PageRouteInfo<void> {
  const ScheduleRoute({List<PageRouteInfo>? children})
      : super(
          ScheduleRoute.name,
          initialChildren: children,
        );

  static const String name = 'ScheduleRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [SignInScreen]
class SignInRoute extends PageRouteInfo<SignInRouteArgs> {
  SignInRoute({
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
          SignInRoute.name,
          args: SignInRouteArgs(key: key),
          initialChildren: children,
        );

  static const String name = 'SignInRoute';

  static const PageInfo<SignInRouteArgs> page = PageInfo<SignInRouteArgs>(name);
}

class SignInRouteArgs {
  const SignInRouteArgs({this.key});

  final Key? key;

  @override
  String toString() {
    return 'SignInRouteArgs{key: $key}';
  }
}

/// generated route for
/// [SignUpScreen]
class SignUpRoute extends PageRouteInfo<void> {
  const SignUpRoute({List<PageRouteInfo>? children})
      : super(
          SignUpRoute.name,
          initialChildren: children,
        );

  static const String name = 'SignUpRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [SplashScreen]
class SplashRoute extends PageRouteInfo<void> {
  const SplashRoute({List<PageRouteInfo>? children})
      : super(
          SplashRoute.name,
          initialChildren: children,
        );

  static const String name = 'SplashRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [TabsScreen]
class TabsRoute extends PageRouteInfo<void> {
  const TabsRoute({List<PageRouteInfo>? children})
      : super(
          TabsRoute.name,
          initialChildren: children,
        );

  static const String name = 'TabsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [TabsScreenSmall]
class TabsRouteSmall extends PageRouteInfo<void> {
  const TabsRouteSmall({List<PageRouteInfo>? children})
      : super(
          TabsRouteSmall.name,
          initialChildren: children,
        );

  static const String name = 'TabsRouteSmall';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [TermsOfServiceScreen]
class TermsOfServiceRoute extends PageRouteInfo<void> {
  const TermsOfServiceRoute({List<PageRouteInfo>? children})
      : super(
          TermsOfServiceRoute.name,
          initialChildren: children,
        );

  static const String name = 'TermsOfServiceRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [UserAnalyticsScreen]
class UserAnalyticsRoute extends PageRouteInfo<void> {
  const UserAnalyticsRoute({List<PageRouteInfo>? children})
      : super(
          UserAnalyticsRoute.name,
          initialChildren: children,
        );

  static const String name = 'UserAnalyticsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [VerificationCodeScreen]
class VerificationCodeRoute extends PageRouteInfo<VerificationCodeRouteArgs> {
  VerificationCodeRoute({
    required VerificationType verificationType,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
          VerificationCodeRoute.name,
          args: VerificationCodeRouteArgs(
            verificationType: verificationType,
            key: key,
          ),
          initialChildren: children,
        );

  static const String name = 'VerificationCodeRoute';

  static const PageInfo<VerificationCodeRouteArgs> page =
      PageInfo<VerificationCodeRouteArgs>(name);
}

class VerificationCodeRouteArgs {
  const VerificationCodeRouteArgs({
    required this.verificationType,
    this.key,
  });

  final VerificationType verificationType;

  final Key? key;

  @override
  String toString() {
    return 'VerificationCodeRouteArgs{verificationType: $verificationType, key: $key}';
  }
}
