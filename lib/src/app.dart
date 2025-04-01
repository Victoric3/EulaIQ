import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/utils/app_lifecycle_manager.dart';
import 'package:eulaiq/src/common/widgets/session_listener.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:eulaiq/src/common/services/navigation_service.dart';

class MyApp extends ConsumerWidget {
  MyApp({super.key});

  final appRouter = AppRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    // Store the router in the navigation service
    NavigationService.setRouter(appRouter);

    return MaterialApp.router(
      routerConfig: appRouter.config(
        // Configure the router with a navigator key if needed
        navigatorObservers: () => [
          AutoRouteObserver(),
        ],
      ),
      debugShowCheckedModeBanner: false,
      title: appName,
      builder: (context, child) {
        // Set up lifecycle observer
        AppLifecycleManager.setupLifecycleObserver(context);
        
        // Place SessionListener inside the builder
        return Stack(
          children: [
            SessionListener(child: child ?? const SizedBox.shrink()),
            Consumer(
              builder: (context, ref, _) {
                final notifications = ref.watch(notificationServiceProvider).notifications;
                return Stack(
                  children: notifications,
                );
              },
            ),
          ],
        );
      },
      theme: ref.watch(currentAppThemeNotifierProvider).when(
        data: (theme) => themeData(theme == CurrentAppTheme.dark ? darkTheme : lightTheme),
        loading: () => themeData(lightTheme),
        error: (_, __) => themeData(lightTheme),
      ),
      darkTheme: themeData(darkTheme),
      themeMode: ref.watch(currentAppThemeNotifierProvider)
          .whenData((theme) => theme.themeMode)
          .value ?? ThemeMode.system,
    );
  }
  
  // Theme configuration method
  ThemeData themeData(ThemeData theme) {
    return theme.copyWith(
      textTheme: GoogleFonts.sourceSansProTextTheme(
        theme.textTheme,
      ),
      colorScheme: theme.colorScheme.copyWith(
        secondary: lightAccent,
      ),
    );
  }
}

// Add this to your app.dart file
void monitorMemoryUsage() {
  Timer.periodic(const Duration(seconds: 10), (timer) {
    if (kDebugMode) {
      debugPrintStack(label: 'Current memory usage check');
      print('🔍 Memory check timestamp: ${DateTime.now()}');
    }
  });
}
