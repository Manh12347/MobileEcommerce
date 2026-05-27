import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/login_provider.dart';
import 'forgot_password_screen.dart';
import 'main_shell_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isValid = true;
    _emailError = null;
    _passwordError = null;

    if (_emailController.text.isEmpty) {
      _emailError = 'Email không được bỏ trống';
      isValid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(_emailController.text)) {
      _emailError = 'Email không hợp lệ';
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      _passwordError = 'Mật khẩu không được bỏ trống';
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      _passwordError = 'Mật khẩu phải có ít nhất 6 ký tự';
      isValid = false;
    }

    return isValid;
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainShellScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                          color: const Color(0xFF576CA8).withValues(alpha: 0.08),
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
                        const SizedBox(height: 42),
                        const Text(
                          'Chào mừng trở lại',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1F2430),
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đăng nhập vào tài khoản TechShop của bạn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF596274),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 38),
                        _FieldLabel(text: 'Email'),
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
                        _FieldLabel(text: 'Mật khẩu'),
                        const SizedBox(height: 7),
                        _InputShell(
                          hasError: _passwordError != null,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '••••••••',
                              hintStyle: const TextStyle(
                                color: Color(0xFF868CA0),
                                fontSize: 18,
                              ),
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
                        if (_passwordError != null) _ErrorText(_passwordError!),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                side: const BorderSide(
                                  color: Color(0xFFC8CEE0),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'Ghi nhớ đăng nhập',
                                style: TextStyle(
                                  color: Color(0xFF596274),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Quên mật khẩu?',
                                style: TextStyle(
                                  color: Color(0xFF0B57D0),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Consumer<LoginProvider>(
                          builder: (context, loginProvider, _) {
                            return loginProvider.errorMessage.isNotEmpty
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
                                      loginProvider.errorMessage,
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
                          builder: (context, loginProvider, _) {
                            return SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: loginProvider.isLoading
                                    ? null
                                    : () async {
                                        if (_validateForm()) {
                                          setState(() {});
                                          final success =
                                              await loginProvider.login(
                                            _emailController.text,
                                            _passwordController.text,
                                          );
                                          if (success && mounted) {
                                            _goHome();
                                          }
                                        } else {
                                          setState(() {});
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2F66EA),
                                  disabledBackgroundColor:
                                      const Color(0xFF8EAAF6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: loginProvider.isLoading
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
                                        'Đăng nhập',
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
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                'hoặc',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Consumer<LoginProvider>(
                          builder: (context, loginProvider, _) {
                            return SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: loginProvider.isLoading
                                    ? null
                                    : () async {
                                        final success = await loginProvider
                                            .loginWithGoogle();
                                        if (success && mounted) {
                                          _goHome();
                                        }
                                      },
                                icon: const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                label: const Text(
                                  'Tiếp tục với Google',
                                  style: TextStyle(
                                    color: Color(0xFF252A35),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFC8CEE0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 38),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text(
                              'Chưa có tài khoản?',
                              style: TextStyle(
                                color: Color(0xFF596274),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Đăng ký ngay',
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
