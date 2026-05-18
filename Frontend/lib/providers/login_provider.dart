import 'package:flutter/material.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/register_request.dart';
import '../models/register_response.dart';
import '../models/verify_otp_request.dart';
import '../services/api_service.dart';

class LoginProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';
  LoginResponse? _loginResponse;
  RegisterResponse? _registerResponse;
  String? _otpMessage;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  LoginResponse? get loginResponse => _loginResponse;
  RegisterResponse? get registerResponse => _registerResponse;
  String? get otpMessage => _otpMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final request = LoginRequest(
        email: email,
        password: password,
      );
      
      final response = await ApiService.login(request);
      _loginResponse = response.data;

      if (response.success) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message.isNotEmpty ? response.message : 'Đăng nhập thất bại';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final request = RegisterRequest(email: email, password: password);
      final response = await ApiService.register(request);
      _registerResponse = response.data;

      if (response.success) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = response.message.isNotEmpty ? response.message : 'Đăng ký thất bại';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = '';
    _otpMessage = null;
    notifyListeners();

    try {
      final request = VerifyOtpRequest(email: email, otp: otp);
      final response = await ApiService.verifyOtp(request);
      _otpMessage = response.message;

      if (response.success) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = response.message.isNotEmpty ? response.message : 'Xác thực OTP thất bại';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
