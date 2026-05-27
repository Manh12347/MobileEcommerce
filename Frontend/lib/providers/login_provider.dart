import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/oauth_login_request.dart';
import '../models/register_request.dart';
import '../models/register_response.dart';
import '../models/verify_otp_request.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';

class LoginProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isRestoringSession = true;
  String _errorMessage = '';
  LoginResponse? _loginResponse;
  RegisterResponse? _registerResponse;
  String? _otpMessage;
  Future<void>? _googleInitFuture;

  bool get isLoading => _isLoading;
  bool get isRestoringSession => _isRestoringSession;
  String get errorMessage => _errorMessage;
  LoginResponse? get loginResponse => _loginResponse;

  bool get isStaff {
    final role = _loginResponse?.role?.toLowerCase();
    return role == 'staff' || role == 'admin';
  }

  LoginProvider() {
    restoreSession();
  }

  Future<void> restoreSession() async {
    _isRestoringSession = true;
    notifyListeners();
    final session = await AuthStorage.loadSession();
    if (session?.accessToken != null && session!.accessToken!.isNotEmpty) {
      _loginResponse = session;
      ApiService.setAccessToken(session.accessToken);
    }
    _isRestoringSession = false;
    notifyListeners();
  }

  Future<void> _persistSession(LoginResponse? response) async {
    _loginResponse = response;
    if (response?.accessToken != null && response!.accessToken!.isNotEmpty) {
      ApiService.setAccessToken(response.accessToken);
      await AuthStorage.saveSession(response);
    } else {
      ApiService.setAccessToken(null);
      await AuthStorage.clearSession();
    }
  }

  Future<void> logout() async {
    _loginResponse = null;
    ApiService.setAccessToken(null);
    await AuthStorage.clearSession();
    notifyListeners();
  }
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

      if (response.success) {
        await _persistSession(response.data);
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

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleInitFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: GOOGLE_OAUTH_SERVER_CLIENT_ID.isEmpty
          ? null
          : GOOGLE_OAUTH_SERVER_CLIENT_ID,
    );
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _ensureGoogleSignInInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Google sign-in is not supported on this device');
      }

      final account = await GoogleSignIn.instance.authenticate();
      final response = await ApiService.oauthLogin(
        OAuthLoginRequest(
          provider: 'google',
          providerUserId: account.id,
          email: account.email,
          fullName: account.displayName,
          avatarUrl: account.photoUrl,
        ),
      );

      if (response.success) {
        await _persistSession(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage =
          response.message.isNotEmpty ? response.message : 'Google login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } on GoogleSignInException catch (e) {
      _errorMessage = _googleErrorMessage(e);
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

  String _googleErrorMessage(GoogleSignInException e) {
    if (e.code == GoogleSignInExceptionCode.canceled ||
        e.code == GoogleSignInExceptionCode.interrupted) {
      return 'Google sign-in was cancelled';
    }

    if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
      return 'Google sign-in is not configured. Add google-services.json or pass GOOGLE_OAUTH_SERVER_CLIENT_ID.';
    }

    return e.description ?? 'Google sign-in failed. Please try again';
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
