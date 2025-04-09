import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/router/auth_guard.dart';
import 'package:eulaiq/src/features/Me/me.dart';
import 'package:eulaiq/src/features/analytics/presentation/ui/screens/user_analytics_screen.dart';
import 'package:eulaiq/src/features/auth/blocs/verify_code.dart';
import 'package:eulaiq/src/features/auth/screens/auth_screen.dart';
import 'package:eulaiq/src/features/auth/screens/intro_page.dart';
import 'package:eulaiq/src/features/auth/screens/reset_password_screen.dart';
import 'package:eulaiq/src/features/auth/screens/verification_code_screen.dart';
import 'package:eulaiq/src/features/history/presentation/ui/screens/exam_history_screen.dart';
import 'package:eulaiq/src/features/legal/presentation/ui/screens/privacy_policy_screen.dart';
import 'package:eulaiq/src/features/legal/presentation/ui/screens/terms_of_service_screen.dart';
import 'package:eulaiq/src/features/library/presentation/ui/screens/ebook_detail_screen.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/screens/quiz_options_screen.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/screens/quiz_results_screen.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/screens/quiz_review_screen.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/screens/quiz_screen.dart';
import 'package:eulaiq/src/features/reader/presentation/ui/screens/document_viewer_screen.dart';
import 'package:eulaiq/src/features/reader/presentation/ui/screens/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/features/features.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends _$AppRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: SplashRoute.page,
      initial: true,
      guards: [AuthGuard()],
    ),
    AutoRoute(path: '/auth', page: AuthRoute.page),
    AutoRoute(path: '/signin', page: SignInRoute.page),
    AutoRoute(path: '/signup', page: SignUpRoute.page),
    AutoRoute(path: '/intro', page: IntroRoute.page),
    AutoRoute(path: '/home', page: HomeRoute.page, guards: [AuthGuard()]),
    AutoRoute(
      path: '/library',
      page: LibraryRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/me',
      page: MeRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(path: '/verify', page: VerificationCodeRoute.page),
    AutoRoute(path: '/reset-password', page: ResetPasswordRoute.page),
    AutoRoute(
      path: '/ebook/:id',
      page: EbookDetailRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(path: '/document', page: DocumentViewerRoute.page),
    AutoRoute(
      path: '/reader/:ebookId',
      page: ReaderRoute.page,
    ),
    AutoRoute(
      path: '/quiz',
      page: QuizRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/quizOptions',
      page: QuizOptionsRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/QuizReview',
      page: QuizReviewRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/results',
      page: QuizResultsRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/userAnalytics',
      page: UserAnalyticsRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/examHistory',
      page: ExamHistoryRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/examHistory',
      page: PrivacyPolicyRoute.page,
      guards: [AuthGuard()],
    ),
    AutoRoute(
      path: '/examHistory',
      page: TermsOfServiceRoute.page,
      guards: [AuthGuard()],
    ),
    CustomRoute(
      page: TabsRoute.page,
      path: '/tabs',
      transitionsBuilder:
          (_, animation, ___, child) =>
              FadeTransition(opacity: animation, child: child),
      children: <AutoRoute>[
        RedirectRoute(path: '', redirectTo: 'library'),
        AutoRoute(page: LibraryRoute.page, path: 'library'),
        AutoRoute(page: CreateRoute.page, path: 'create'),
        AutoRoute(page: MeRoute.page, path: 'me'),
      ],
    ),
  ];
}
