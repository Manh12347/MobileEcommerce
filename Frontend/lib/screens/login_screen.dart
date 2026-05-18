import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
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

    // Validate email
    if (_emailController.text.isEmpty) {
      _emailError = 'Email không được bỏ trống';
      isValid = false;
    } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(_emailController.text)) {
      _emailError = 'Email không hợp lệ';
      isValid = false;
    }

    // Validate password
    if (_passwordController.text.isEmpty) {
      _passwordError = 'Mật khẩu không được bỏ trống';
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      _passwordError = 'Mật khẩu phải có ít nhất 6 ký tự';
      isValid = false;
    }

    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'TechShop',
          style: TextStyle(
            color: Color(0xFF1976D2),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      color: Color(0xFF1976D2),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'user@domain.com',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      if (_emailError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _emailError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mật khẩu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      if (_passwordError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _passwordError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Navigate to forgot password
                      },
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error Message
                  Consumer<LoginProvider>(
                    builder: (context, loginProvider, _) {
                      return loginProvider.errorMessage.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                loginProvider.errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Login Button
                  Consumer<LoginProvider>(
                    builder: (context, loginProvider, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: loginProvider.isLoading
                              ? null
                              : () async {
                                  if (_validateForm()) {
                                    setState(() {});
                                    final success = await loginProvider.login(
                                      _emailController.text,
                                      _passwordController.text,
                                    );

                                    if (success && mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Đăng nhập thành công'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      // TODO: Navigate to home
                                      // Navigator.pushReplacementNamed(context, '/home');
                                    }
                                  } else {
                                    setState(() {});
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            disabledBackgroundColor:
                                const Color(0xFF1976D2).withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: loginProvider.isLoading
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
                              : const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'hoặc',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Navigate to OTP login
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF1976D2),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Đăng nhập bằng OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Chưa có tài khoản? ',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: Navigate to register
                        },
                        child: const Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Footer
                  Text(
                    '© 2024 TechShop',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
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
