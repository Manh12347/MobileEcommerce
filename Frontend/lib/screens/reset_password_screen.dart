import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/login_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _otpError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    context.read<LoginProvider>().clearError(notify: false);
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    _otpError = null;
    _passwordError = null;
    _confirmPasswordError = null;

    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    var valid = true;

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _otpError = 'Vui lòng nhập mã OTP gồm 6 chữ số';
      valid = false;
    }
    final passwordRuleError = _validatePasswordRules(password);

    if (password.isEmpty) {
      _passwordError = 'Mật khẩu mới không được bỏ trống';
      valid = false;
    } else if (passwordRuleError != null) {
      _passwordError = passwordRuleError;
      valid = false;
    }
    if (confirmPassword != password) {
      _confirmPasswordError = 'Mật khẩu xác nhận không khớp';
      valid = false;
    }

    return valid;
  }

  String? _validatePasswordRules(String password) {
    if (password.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Mật khẩu phải chứa ít nhất 1 chữ hoa (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Mật khẩu phải chứa ít nhất 1 chữ thường (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Mật khẩu phải chứa ít nhất 1 số (0-9)';
    }
    if (!RegExp(
      r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?]''',
    ).hasMatch(password)) {
      return 'Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt (!@#...)';
    }
    return null;
  }

  Future<void> _resetPassword() async {
    if (!_validate()) {
      setState(() {});
      return;
    }

    final success = await context.read<LoginProvider>().resetPassword(
      email: widget.email,
      otp: _otpController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đặt lại mật khẩu thành công'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _resendOtp() async {
    final success = await context.read<LoginProvider>().forgotPassword(
      widget.email,
    );
    if (!mounted || !success) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã gửi lại mã OTP'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoginProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Đặt lại mật khẩu',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD5DAEA)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3F6DB5).withValues(alpha: 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset_outlined,
                      color: Color(0xFF0759D8),
                      size: 54,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nhập mã OTP và mật khẩu mới',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF596274),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _TextFieldBlock(
                      label: 'Mã OTP',
                      errorText: _otpError,
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: (_) {
                          if (_otpError != null) {
                            setState(() => _otpError = null);
                          }
                        },
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: '123456',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TextFieldBlock(
                      label: 'Mật khẩu mới',
                      errorText: _passwordError,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Ví dụ: Techshop@1',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _PasswordRuleNote(),
                    const SizedBox(height: 16),
                    _TextFieldBlock(
                      label: 'Xác nhận mật khẩu',
                      errorText: _confirmPasswordError,
                      child: TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        onChanged: (_) {
                          if (_confirmPasswordError != null) {
                            setState(() => _confirmPasswordError = null);
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Nhập lại mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (provider.errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          provider.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE5484D),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: provider.isLoading ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0759D8),
                          disabledBackgroundColor: const Color(0xFF8EAAF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: provider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Đặt lại mật khẩu'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: provider.isLoading ? null : _resendOtp,
                      child: const Text('Gửi lại mã OTP'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({
    required this.label,
    required this.child,
    this.errorText,
  });

  final String label;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3F4658),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText == null
                  ? const Color(0xFFC8CEE0)
                  : const Color(0xFFE5484D),
            ),
          ),
          child: child,
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFE5484D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _PasswordRuleNote extends StatelessWidget {
  const _PasswordRuleNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: Color(0xFF596274)),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt (!@#...).',
            style: TextStyle(
              color: Color(0xFF596274),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
