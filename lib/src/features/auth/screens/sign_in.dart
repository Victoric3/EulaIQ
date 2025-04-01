import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/constants/global_state.dart';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/auth/blocs/auth_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@RoutePage()
class SignInScreen extends ConsumerWidget {
  SignInScreen({super.key});
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInState = ref.watch(signInProvider);
    final isLoading = ref.watch(loadingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.06, // Responsive horizontal padding
            vertical: size.height * 0.02, // Responsive vertical padding
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Container(
                height: size.width * 0.12, // Responsive button size
                width: size.width * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.neonCyan.withOpacity(0.3)
                            : AppColors.brandDeepGold.withOpacity(0.3),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    size: size.width * 0.045, // Responsive icon size
                    color: isDark ? AppColors.textPrimary : AppColors.textDark,
                  ),
                  onPressed: () => context.router.pop(),
                ),
              ),
              SizedBox(height: size.height * 0.04),

              // Header
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: size.width * 0.07, // Responsive text size
                  fontWeight: FontWeight.bold,
                  foreground:
                      Paint()
                        ..shader = LinearGradient(
                          colors:
                              isDark
                                  ? [AppColors.neonCyan, AppColors.neonPurple]
                                  : [
                                    AppColors.brandDeepGold,
                                    AppColors.brandWarmOrange,
                                  ],
                        ).createShader(
                          Rect.fromLTWH(
                            0,
                            0,
                            size.width * 0.5,
                            size.height * 0.1,
                          ),
                        ),
                ),
              ),
              SizedBox(height: size.height * 0.01),
              Text(
                'Sign in to continue your learning journey',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: size.width * 0.04, // Responsive text size
                  color:
                      isDark
                          ? AppColors.textPrimary.withOpacity(0.7)
                          : AppColors.neutralDarkGray,
                ),
              ),
              SizedBox(height: size.height * 0.06),

              // Form
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email Field
                    _CustomTextField(
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      onChanged:
                          (value) => signInState.validateForm(value, 'email'),
                      validator: (value) {
                        if (!signInState.emailRegExp.hasMatch(value!)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      height: size.height * 0.07, // Add height parameter
                      fontSize: size.width * 0.04, // Add fontSize parameter
                      isDark: isDark,
                    ),
                    SizedBox(height: size.height * 0.03),

                    // Password Field
                    _CustomTextField(
                      label: 'Password',
                      isPassword: true,
                      passwordVisible: signInState.passwordVisibility,
                      onTogglePassword: signInState.togglePasswordVisibility,
                      onChanged:
                          (value) =>
                              signInState.validateForm(value, 'password'),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                      height: size.height * 0.07,
                      fontSize: size.width * 0.04,
                      isDark: isDark,
                    ),
                    SizedBox(height: size.height * 0.02),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.router.push(const ResetPasswordRoute()),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: size.width * 0.035,
                            color:
                                isDark
                                    ? AppColors.neonCyan
                                    : AppColors.brandDeepGold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.04),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: size.height * 0.07,
                      child: ElevatedButton(
                        onPressed:
                            isLoading || !signInState.continueButtonEnabled
                                ? null
                                : () {
                                  if (formKey.currentState!.validate()) {
                                    signInState.signIn(context, ref);
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                          foregroundColor:
                              isDark ? AppColors.darkBg : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child:
                            isLoading
                                ? SizedBox(
                                  height: size.width * 0.06,
                                  width: size.width * 0.06,
                                  child: const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: size.width * 0.04,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.03),

                    // Sign Up Link
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color:
                                isDark
                                    ? AppColors.textPrimary
                                    : AppColors.textDark,
                            fontSize: size.width * 0.04,
                          ),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => context.router.push(const SignUpRoute()),
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? AppColors.neonCyan
                                            : AppColors.brandDeepGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final String label;
  final bool isPassword;
  final bool? passwordVisible;
  final VoidCallback? onTogglePassword;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool isDark;
  final double height;
  final double fontSize;

  const _CustomTextField({
    required this.label,
    this.isPassword = false,
    this.passwordVisible,
    this.onTogglePassword,
    this.onChanged,
    this.validator,
    this.keyboardType,
    required this.isDark,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: fontSize),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color:
                  isDark
                      ? AppColors.neonCyan.withOpacity(0.3)
                      : AppColors.brandDeepGold.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
          ),
          suffixIcon:
              isPassword
                  ? IconButton(
                    icon: Icon(
                      passwordVisible!
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color:
                          isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    ),
                    onPressed: onTogglePassword,
                  )
                  : null,
        ),
        obscureText: isPassword && !passwordVisible!,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(
          fontSize: fontSize,
          color: isDark ? AppColors.textPrimary : AppColors.textDark,
        ),
      ),
    );
  }
}
