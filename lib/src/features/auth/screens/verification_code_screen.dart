import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/constants/global_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/auth/blocs/verify_code.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

@RoutePage()
class VerificationCodeScreen extends ConsumerStatefulWidget {
  final VerificationType verificationType;
  
  const VerificationCodeScreen({
    required this.verificationType,
    super.key,
  });

  @override
  ConsumerState<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends ConsumerState<VerificationCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(verifyCodeProvider).setVerificationType(widget.verificationType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final verifyCode = ref.watch(verifyCodeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.06,
            vertical: size.height * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark 
                        ? AppColors.neonCyan.withOpacity(0.3)
                        : AppColors.brandDeepGold.withOpacity(0.3),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: isDark ? AppColors.textPrimary : AppColors.textDark,
                  ),
                  onPressed: () => context.router.pop(),
                ),
              ),
              SizedBox(height: size.height * 0.04),

              Text(
                _getHeaderText(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: size.width * 0.07,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = LinearGradient(
                      colors: isDark
                          ? [AppColors.neonCyan, AppColors.neonPurple]
                          : [AppColors.brandDeepGold, AppColors.brandWarmOrange],
                    ).createShader(Rect.fromLTWH(0, 0, size.width * 0.5, 0)),
                ),
              ),
              SizedBox(height: size.height * 0.02),

              Text(
                _getSubtitleText(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark 
                      ? AppColors.textPrimary.withOpacity(0.7)
                      : AppColors.neutralDarkGray,
                ),
              ),
              SizedBox(height: size.height * 0.06),

              // Verification Code Input
              if (widget.verificationType != VerificationType.resetPassword)
                _buildVerificationCodeInput(),

              // Password Fields for Reset Password
              if (widget.verificationType == VerificationType.resetPassword)
                _buildPasswordFields(),

              SizedBox(height: size.height * 0.04),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: ref.watch(loadingProvider)
                      ? null
                      : () => verifyCode.verifyCode(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.neonCyan
                        : AppColors.brandDeepGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: ref.watch(loadingProvider)
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          _getActionButtonText(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              // Resend Option
              if (widget.verificationType != VerificationType.resetPassword)
                _buildResendOption(),
            ],
          ),
        ),
      ),
    );
  }

  String _getHeaderText() {
    switch (widget.verificationType) {
      case VerificationType.signUp:
        return 'Verify Your Email';
      case VerificationType.unUsualSignIn:
        return 'Verify Your Login';
      case VerificationType.resetPassword:
        return 'Reset Password';
      case VerificationType.forgotPassword:
        return 'Enter Verification Code';
    }
  }

  String _getSubtitleText() {
    switch (widget.verificationType) {
      case VerificationType.signUp:
        return 'Please enter the verification code sent to your email';
      case VerificationType.unUsualSignIn:
        return 'Verify your login attempt';
      case VerificationType.resetPassword:
        return 'Enter your new password';
      case VerificationType.forgotPassword:
        return 'Enter the verification code sent to your email';
    }
  }

  String _getActionButtonText() {
    switch (widget.verificationType) {
      case VerificationType.signUp:
      case VerificationType.unUsualSignIn:
      case VerificationType.forgotPassword:
        return 'Verify';
      case VerificationType.resetPassword:
        return 'Reset Password';
    }
  }

  Widget _buildVerificationCodeInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final verifyCode = ref.watch(verifyCodeProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
      child: PinCodeTextField(
        appContext: context,
        length: 6,
        controller: _codeController,
        onChanged: (value) => verifyCode.updateToken(value),
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(12),
          fieldHeight: size.width * 0.14,
          fieldWidth: size.width * 0.12,
          activeFillColor: isDark 
              ? AppColors.neonCyan.withOpacity(0.1)
              : AppColors.brandDeepGold.withOpacity(0.1),
          selectedFillColor: isDark
              ? AppColors.neonCyan.withOpacity(0.2)
              : AppColors.brandDeepGold.withOpacity(0.2),
          inactiveFillColor: isDark
              ? AppColors.darkBg
              : Colors.grey.shade100,
          activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          selectedColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          inactiveColor: isDark
              ? AppColors.neonCyan.withOpacity(0.3)
              : AppColors.brandDeepGold.withOpacity(0.3),
        ),
        animationType: AnimationType.scale,
        enableActiveFill: true,
        keyboardType: TextInputType.number,
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _buildPasswordFields() {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final verifyCode = ref.watch(verifyCodeProvider);

    return Column(
      children: [
        // Add verification code input first
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.02),
          child: PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _codeController,
            onChanged: (value) => verifyCode.updateToken(value),
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: size.width * 0.14,
              fieldWidth: size.width * 0.12,
              activeFillColor: isDark 
                  ? AppColors.neonCyan.withOpacity(0.1)
                  : AppColors.brandDeepGold.withOpacity(0.1),
              selectedFillColor: isDark
                  ? AppColors.neonCyan.withOpacity(0.2)
                  : AppColors.brandDeepGold.withOpacity(0.2),
              inactiveFillColor: isDark
                  ? AppColors.darkBg
                  : Colors.grey.shade100,
              activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              selectedColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              inactiveColor: isDark
                  ? AppColors.neonCyan.withOpacity(0.3)
                  : AppColors.brandDeepGold.withOpacity(0.3),
            ),
            animationType: AnimationType.scale,
            enableActiveFill: true,
            keyboardType: TextInputType.number,
            animationDuration: const Duration(milliseconds: 200),
          ),
        ),
        SizedBox(height: size.height * 0.04),

        // Existing password fields
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [
                      AppColors.neonCyan.withOpacity(0.05),
                      AppColors.neonPurple.withOpacity(0.05),
                    ]
                  : [
                      AppColors.brandDeepGold.withOpacity(0.05),
                      AppColors.brandWarmOrange.withOpacity(0.05),
                    ],
            ),
          ),
          child: _CustomTextField(
            controller: _passwordController,
            label: 'New Password',
            isPassword: true,
            onChanged: (value) => verifyCode.updatePassword(value),
            hint: 'Enter your new password',
            prefixIcon: Icons.lock_outline,
          ),
        ),
        SizedBox(height: size.height * 0.02),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [
                      AppColors.neonCyan.withOpacity(0.05),
                      AppColors.neonPurple.withOpacity(0.05),
                    ]
                  : [
                      AppColors.brandDeepGold.withOpacity(0.05),
                      AppColors.brandWarmOrange.withOpacity(0.05),
                    ],
            ),
          ),
          child: _CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            isPassword: true,
            onChanged: (value) => ref.read(verifyCodeProvider).updateConfirmPassword(value),
            hint: 'Confirm your new password',
            prefixIcon: Icons.lock_outline,
          ),
        ),
        SizedBox(height: size.height * 0.03),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark 
                ? AppColors.neonCyan.withOpacity(0.05)
                : AppColors.brandDeepGold.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Password must be at least 8 characters long and include uppercase, lowercase, numbers, and special characters.',
                  style: TextStyle(
                    color: isDark 
                        ? AppColors.textPrimary.withOpacity(0.7)
                        : AppColors.neutralDarkGray,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResendOption() {
    final verifyCode = ref.watch(verifyCodeProvider);
    final userEmail = ref.watch(email.notifier).state;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
      child: Center(
        child: TextButton(
          onPressed: verifyCode.isResending || userEmail == null
              ? null 
              : () => verifyCode.resendVerificationToken(userEmail, ref),
          child: Text(
            verifyCode.isResending ? 'Sending...' : 'Resend Code',
            style: TextStyle(
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              fontSize: size.width * 0.04,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isPassword;
  final Function(String) onChanged;
  final IconData? prefixIcon;

  const _CustomTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.isPassword = false,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final verifyCode = ref.watch(verifyCodeProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final size = MediaQuery.of(context).size;

        return TextField(
          controller: controller,
          obscureText: isPassword && !verifyCode.passwordVisible,
          style: TextStyle(
            color: isDark ? AppColors.textPrimary : AppColors.textDark,
            fontSize: size.width * 0.04,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark 
                  ? AppColors.textPrimary.withOpacity(0.3)
                  : AppColors.neutralDarkGray.withOpacity(0.3),
              fontSize: size.width * 0.035,
            ),
            labelStyle: TextStyle(
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              fontSize: size.width * 0.04,
            ),
            prefixIcon: prefixIcon != null 
                ? Icon(
                    prefixIcon,
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    size: size.width * 0.05,
                  )
                : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      verifyCode.passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      size: size.width * 0.05,
                    ),
                    onPressed: () => verifyCode.togglePasswordVisibility(),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark 
                    ? AppColors.neonCyan.withOpacity(0.3)
                    : AppColors.brandDeepGold.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isDark 
                ? AppColors.darkBg 
                : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: onChanged,
        );
      },
    );
  }
}