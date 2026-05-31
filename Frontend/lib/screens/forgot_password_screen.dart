import 'package:flutter/material.dart';

import 'otp_confirm_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    _emailError = null;
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _emailError = 'Email không được bỏ trống';
      return false;
    }

    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      _emailError = 'Email không hợp lệ';
      return false;
    }

    return true;
  }

  void _openOtpScreen() {
    if (!_validateEmail()) {
      setState(() {});
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpConfirmScreen(email: _emailController.text.trim()),
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Quên mật khẩu',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Image.asset(
                      'assets/branding/techshop_premium_logo.png',
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.fromLTRB(40, 42, 40, 34),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD5DAEA)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF3F6DB5,
                          ).withValues(alpha: 0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 168,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FBFF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/branding/techshop_robot.png',
                            height: 128,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 34),
                        const Text(
                          'Quên mật\nkhẩu?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1F2430),
                            fontSize: 28,
                            height: 1.16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Nhập email của bạn để\nnhận mã khôi phục',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF596274),
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 34),
                        const _FieldLabel('Email'),
                        const SizedBox(height: 7),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _emailError == null
                                  ? const Color(0xFFC8CEE0)
                                  : const Color(0xFFE5484D),
                            ),
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              icon: Icon(
                                Icons.mail_outline,
                                color: Color(0xFF596274),
                              ),
                              hintText: 'example@techshop.com',
                              hintStyle: TextStyle(
                                color: Color(0xFF868CA0),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        if (_emailError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              _emailError!,
                              style: const TextStyle(
                                color: Color(0xFFE5484D),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _openOtpScreen,
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward, size: 20),
                            label: const Text('Gửi liên kết'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0759D8),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: const Color(
                                0xFF0759D8,
                              ).withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 46),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Quay lại đăng nhập'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0759D8),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Cần trợ giúp thêm?',
                        style: TextStyle(color: Color(0xFF596274)),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Liên hệ hỗ trợ'),
                      ),
                    ],
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
  const _FieldLabel(this.text);

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
