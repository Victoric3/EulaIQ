import 'dart:async';
import 'dart:math';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';

@RoutePage()
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _mascotSlideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _mascotSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    startTimeout();
  }

  void startTimeout() {
    Timer(const Duration(seconds: 3), () => context.router.replace(const TabsRoute()));
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
          // Enhanced gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: isDark
                    ? [
                        AppColors.neonPurple.withOpacity(0.15),
                        AppColors.darkBg,
                        AppColors.darkBg,
                      ]
                    : [
                        AppColors.brandWarmOrange.withOpacity(0.1),
                        AppColors.neutralLightGray,
                        Colors.white,
                      ],
              ),
            ),
          ),

          // Animated particles effect
          CustomPaint(
            painter: ParticlesPainter(
              color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                  .withOpacity(0.1),
            ),
          ),

          // Main content
          Column(
            children: [
              SizedBox(height: size.height * 0.1),
              
              // Mascot Image (Eula) - Now larger and more prominent
              Expanded(
                flex: 3,
                child: AnimatedBuilder(
                  animation: _mascotSlideAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _mascotSlideAnimation.value),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: size.width * 0.9,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                    .withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/brand_assets/Eula.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // App Logo - Now smaller and at the bottom
              Expanded(
                flex: 1,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: size.width * 0.2,
                          height: size.width * 0.2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark 
                                ? AppColors.darkBgCard.withOpacity(0.3)
                                : Colors.white.withOpacity(0.9),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                    .withOpacity(0.15),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Hero(
                            tag: 'app_logo',
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app-logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.02),
                        // App name with gradient text
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? [AppColors.neonCyan, AppColors.neonPurple]
                                : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
                          ).createShader(bounds),
                          child: Text(
                            appName,
                            style: TextStyle(
                              fontSize: size.width * 0.06,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add this custom painter for the particle effect
class ParticlesPainter extends CustomPainter {
  final Color color;
  final int numberOfParticles = 30;

  ParticlesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint()..color = color;

    for (int i = 0; i < numberOfParticles; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) => false;
}
