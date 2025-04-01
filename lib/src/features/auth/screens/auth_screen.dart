import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/constants/global_state.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/auth/blocs/auth_handler.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                    ? [
                        AppColors.darkBg,
                        AppColors.darkBg,
                        AppColors.neonPurple.withOpacity(0.1),
                      ]
                    : [
                        AppColors.neutralLightGray,
                        AppColors.brandDeepGold.withOpacity(0.1),
                      ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  // Logo and App Name
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Hero(
                            tag: 'app_logo',
                            child: Container(
                              width: size.width * 0.3,
                              height: size.width * 0.3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark 
                                    ? AppColors.darkBgCard.withOpacity(0.3)
                                    : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                        .withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/app-logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome to Eulaiq',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              foreground: Paint()
                                ..shader = LinearGradient(
                                  colors: isDark 
                                      ? [AppColors.neonCyan, AppColors.neonPurple]
                                      : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
                                ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI-powered medical learning, tailored to you',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? AppColors.textPrimary : AppColors.neutralDarkGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Auth Buttons
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _AuthButton(
                          icon: Icons.alternate_email_rounded, // More modern email icon
                          label: 'Sign in with Email',
                          onPressed: () => context.router.push(SignInRoute()),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _AuthButton(
                          icon: Icons.email, // Default icon (won't be shown due to iconWidget)
                          // Custom Google icon with better styling
                          iconWidget: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/icons/google-icon.png',
                              height: 20,
                              width: 20,
                            ),
                          ),
                          label: 'Continue with Google',
                          onPressed: () {
                            final signInState = ref.read(signInProvider);
                            signInState.signInWithGoogle(context, ref);
                          },
                          isDark: isDark,
                          isLoading: ref.watch(googleSignInLoadingProvider), // Updated
                        ),
                        const SizedBox(height: 16),
                        _AuthButton(
                          icon: Icons.explore_outlined, // More inviting guest icon
                          label: 'Continue as Guest',
                          onPressed: () {
                            final signInState = ref.read(signInProvider);
                            signInState.continueAsGuest(context, ref);
                          },
                          isDark: isDark,
                          isOutlined: true,
                          isLoading: ref.watch(guestSignInLoadingProvider), // Updated
                        ),
                        const SizedBox(height: 24),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: isDark ? AppColors.textPrimary : AppColors.textDark,
                            ),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => context.router.push(const SignUpRoute()),
                                  child: Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final IconData icon;
  final Widget? iconWidget; // Add support for custom icon widgets
  final String label;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isOutlined;
  final bool isLoading;

  const _AuthButton({
    required this.icon,
    this.iconWidget,
    required this.label,
    required this.onPressed,
    required this.isDark,
    this.isOutlined = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: !isOutlined
            ? LinearGradient(
                colors: isDark
                    ? [AppColors.neonCyan, AppColors.neonPurple]
                    : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
              )
            : null,
        border: isOutlined
            ? Border.all(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                width: 2,
              )
            : null,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Use custom icon widget if provided, otherwise use icon
                  iconWidget ??
                      Icon(
                        icon,
                        size: 24, // Slightly larger icons
                        color: isOutlined
                            ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                            : (isDark ? AppColors.darkBg : Colors.white),
                      ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600, // Slightly bolder text
                      color: isOutlined
                          ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                          : (isDark ? AppColors.darkBg : Colors.white),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}