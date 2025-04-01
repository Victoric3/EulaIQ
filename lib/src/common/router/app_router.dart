import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/router/auth_guard.dart';
import 'package:eulaiq/src/features/auth/blocs/verify_code.dart';
import 'package:eulaiq/src/features/auth/screens/auth_screen.dart';
import 'package:eulaiq/src/features/auth/screens/intro_page.dart';
import 'package:eulaiq/src/features/auth/screens/reset_password_screen.dart';
import 'package:eulaiq/src/features/auth/screens/verification_code_screen.dart';
import 'package:eulaiq/src/features/library/presentation/ui/screens/ebook_detail_screen.dart';
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
    CustomRoute(
      page: TabsRoute.page,
      path: '/tabs',
      transitionsBuilder:
          (_, animation, ___, child) =>
              FadeTransition(opacity: animation, child: child),
      children: <AutoRoute>[
        RedirectRoute(path: '', redirectTo: 'home'),
        AutoRoute(page: HomeRoute.page, path: 'home'),
        AutoRoute(page: LibraryRoute.page, path: 'library'),
        AutoRoute(page: ScheduleRoute.page, path: 'schedule'),
        AutoRoute(page: CreateRoute.page, path: 'create'),
        AutoRoute(page: CommunityRoute.page, path: 'community'),
      ],
    ),
  ];
}
