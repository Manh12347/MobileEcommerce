import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/login_provider.dart';
import 'otp_confirm_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isValid = true;
    _emailError = null;
    _passwordError = null;
    _confirmPasswordError = null;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      _emailError = 'Email không được bỏ trống';
      isValid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      _emailError = 'Email không hợp lệ';
      isValid = false;
    }

    if (password.isEmpty) {
      _passwordError = 'Mật khẩu không được bỏ trống';
      isValid = false;
    } else if (password.length < 6) {
      _passwordError = 'Mật khẩu phải có ít nhất 6 ký tự';
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Vui lòng nhập lại mật khẩu';
      isValid = false;
    } else if (confirmPassword != password) {
      _confirmPasswordError = 'Mật khẩu nhập lại không khớp';
      isValid = false;
    }

    return isValid;
  }

  Future<void> _register(LoginProvider provider) async {
    if (!_validateForm()) {
      setState(() {});
      return;
    }

    final email = _emailController.text.trim();
    final success = await provider.register(email, _passwordController.text);

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpConfirmScreen(
            email: email,
            navigateToHomeOnSuccess: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(40, 42, 40, 38),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF576CA8).withOpacity(0.08),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/branding/techshop_premium_logo.png',
                            height: 42,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Text(
                          'Tạo tài khoản',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1F2430),
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng ký tài khoản TechShop và xác minh email bằng mã OTP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF596274),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 34),
                        const _FieldLabel(text: 'Email'),
                        const SizedBox(height: 7),
                        _InputShell(
                          hasError: _emailError != null,
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'name@example.com',
                              hintStyle: TextStyle(
                                color: Color(0xFF868CA0),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_emailError != null) _ErrorText(_emailError!),
                        const SizedBox(height: 16),
                        const _FieldLabel(text: 'Mật khẩu'),
                        const SizedBox(height: 7),
                        _InputShell(
                          hasError: _passwordError != null,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Ẩn mật khẩu'
                                    : 'Hiện mật khẩu',
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF596274),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_passwordError != null)
                          _ErrorText(_passwordError!),
                        const SizedBox(height: 16),
                        const _FieldLabel(text: 'Nhập lại mật khẩu'),
                        const SizedBox(height: 7),
                        _InputShell(
                          hasError: _confirmPasswordError != null,
                          child: TextField(
                            controller: _confirmPasswordController,
                            obscureText: !_showConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_confirmPasswordError != null) {
                                setState(() => _confirmPasswordError = null);
                              }
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                tooltip: _showConfirmPassword
                                    ? 'Ẩn mật khẩu'
                                    : 'Hiện mật khẩu',
                                icon: Icon(
                                  _showConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF596274),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showConfirmPassword =
                                        !_showConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_confirmPasswordError != null)
                          _ErrorText(_confirmPasswordError!),
                        const SizedBox(height: 22),
                        Consumer<LoginProvider>(
                          builder: (context, provider, _) {
                            return provider.errorMessage.isNotEmpty
                                ? Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0F0),
                                      border: Border.all(
                                        color: const Color(0xFFFFB8B8),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      provider.errorMessage,
                                      style: const TextStyle(
                                        color: Color(0xFFB3261E),
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                        Consumer<LoginProvider>(
                          builder: (context, provider, _) {
                            return SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _register(provider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2F66EA),
                                  disabledBackgroundColor:
                                      const Color(0xFF8EAAF6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: provider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Đăng ký',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Đã có tài khoản?',
                              style: TextStyle(
                                color: Color(0xFF596274),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  color: Color(0xFF0B57D0),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'TECHSHOP ECOSYSTEM © 2024',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF7A8192),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF3F4658),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({
    required this.child,
    required this.hasError,
  });

  final Widget child;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAFF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: hasError ? const Color(0xFFE5484D) : const Color(0xFFC8CEE0),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE5484D),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
