import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/login_provider.dart';
import 'main_shell_screen.dart';

class OtpConfirmScreen extends StatefulWidget {
  const OtpConfirmScreen({
    super.key,
    required this.email,
    this.navigateToHomeOnSuccess = false,
  });

  final String email;
  final bool navigateToHomeOnSuccess;

  @override
  State<OtpConfirmScreen> createState() => _OtpConfirmScreenState();
}

class _OtpConfirmScreenState extends State<OtpConfirmScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _localError;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((controller) => controller.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      setState(() => _localError = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }

    final success = await context.read<LoginProvider>().verifyOtp(
          widget.email,
          _otp,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xác minh OTP thành công'),
          backgroundColor: Colors.green,
        ),
      );
      if (widget.navigateToHomeOnSuccess) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const MainShellScreen(),
          ),
          (route) => false,
        );
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  void _handleDigitChanged(String value, int index) {
    if (_localError != null) {
      setState(() => _localError = null);
    }

    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (var i = 0; i < digits.length && index + i < 6; i++) {
        _controllers[index + i].text = digits[i];
      }
      final nextIndex = (index + digits.length).clamp(0, 5);
      _focusNodes[nextIndex].requestFocus();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
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
              child: Container(
                color: const Color(0xFFFBF9FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cofirm OTP',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFDDE2F1)),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            color: const Color(0xFF3F4658),
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            'assets/branding/techshop_premium_logo.png',
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 38),
                    Center(
                      child: Container(
                        height: 96,
                        width: 96,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E8FF),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          height: 42,
                          width: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0759D8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Xác minh mã OTP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mã đã được gửi đến email của bạn. Vui lòng\nkiểm tra hộp thư đến (bao gồm cả thư rác).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: List.generate(6, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == 5 ? 0 : 3,
                              left: index == 0 ? 0 : 3,
                            ),
                            child: _OtpBox(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              autoFocus: index == 0,
                              onChanged: (value) =>
                                  _handleDigitChanged(value, index),
                            ),
                          ),
                        );
                      }),
                    ),
                    Consumer<LoginProvider>(
                      builder: (context, provider, _) {
                        final message =
                            _localError ?? provider.errorMessage;
                        if (message.isEmpty) {
                          return const SizedBox(height: 32);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 18),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE5484D),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                    Consumer<LoginProvider>(
                      builder: (context, provider, _) {
                        return SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: provider.isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F66EA),
                              disabledBackgroundColor:
                                  const Color(0xFF8EAAF6),
                              foregroundColor: Colors.white,
                              elevation: 12,
                              shadowColor:
                                  const Color(0xFF2F66EA).withOpacity(0.26),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
                                : const Text('Xác minh'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Gửi lại mã ngay',
                        style: TextStyle(
                          color: Color(0xFF0759D8),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFFDDE2F1)),
                    const SizedBox(height: 34),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 16,
                          color: Color(0xFF596274),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Bạn gặp sự cố? Liên hệ kỹ thuật',
                          style: TextStyle(
                            color: Color(0xFF596274),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SupportButton(
                          icon: Icons.mail_outline,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 16),
                        _SupportButton(
                          icon: Icons.phone_outlined,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 58),
                    const Text(
                      '© 2024 TechShop. Tất cả quyền được bảo lưu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8A8F9E),
                        fontSize: 15,
                      ),
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.autoFocus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autoFocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autoFocus,
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF1F2430),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFFBF9FF),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFFC8CEE0),
              width: 1.6,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF0759D8),
              width: 2.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        color: const Color(0xFF3F4658),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF0F1FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
