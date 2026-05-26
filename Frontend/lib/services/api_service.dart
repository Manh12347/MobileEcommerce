import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/oauth_login_request.dart';
import '../models/product_item.dart';
import '../models/register_request.dart';
import '../models/register_response.dart';
import '../models/verify_otp_request.dart';

class ApiService {
  static const String baseUrl = API_BASE_URL;

  static Future<ApiResponse<List<ProductItemSummary>>> getProductItems({
    int page = 1,
    int size = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$PRODUCT_ITEMS_ENDPOINT/list?page=$page&size=$size'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final body = _decodeJsonBody(response.body);
        final rawData = body['data'];
        final rawList = rawData is Map<String, dynamic>
          ? rawData['content']
          : rawData;

        final items = rawList is List
          ? rawList
            .whereType<Map<String, dynamic>>()
            .map(ProductItemSummary.fromJson)
            .toList()
          : <ProductItemSummary>[];

      if (response.statusCode == 200) {
        return ApiResponse<List<ProductItemSummary>>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: items,
          statusCode: body['statusCode'] is int
              ? body['statusCode'] as int
              : int.tryParse('${body['statusCode'] ?? ''}'),
        );
      }

      throw Exception(_extractMessage(
        response,
        fallback: 'Không thể tải danh sách sản phẩm',
      ));
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<ProductItemDetail>> getProductItemDetail(
    int productItemId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$PRODUCT_ITEMS_ENDPOINT/$productItemId'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final body = _decodeJsonBody(response.body);

      if (response.statusCode == 200) {
        final rawData = body['data'];
        return ApiResponse<ProductItemDetail>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: rawData is Map<String, dynamic>
              ? ProductItemDetail.fromJson(rawData)
              : null,
          statusCode: body['statusCode'] is int
              ? body['statusCode'] as int
              : int.tryParse('${body['statusCode'] ?? ''}'),
        );
      }

      throw Exception(_extractMessage(
        response,
        fallback: 'Không thể tải chi tiết sản phẩm',
      ));
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Map<String, dynamic> _decodeJsonBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid response from server');
  }

  static String _extractMessage(http.Response response,
      {String fallback = 'Request failed'}) {
    try {
      final data = _decodeJsonBody(response.body);
      final message = data['message']?.toString();
      return (message == null || message.isEmpty) ? fallback : message;
    } catch (_) {
      return fallback;
    }
  }

  static Future<ApiResponse<LoginResponse>> login(LoginRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final body = _decodeJsonBody(response.body);

      if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 401) {
        return ApiResponse<LoginResponse>.fromJson(
          body,
          (json) => LoginResponse.fromJson(json),
        );
      } else {
        throw Exception(_extractMessage(
          response,
          fallback: 'Lỗi đăng nhập. Vui lòng thử lại',
        ));
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<LoginResponse>> oauthLogin(
    OAuthLoginRequest request,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/oauth'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final body = _decodeJsonBody(response.body);

      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 401) {
        return ApiResponse<LoginResponse>.fromJson(
          body,
          (json) => LoginResponse.fromJson(json),
        );
      } else {
        throw Exception(_extractMessage(
          response,
          fallback: 'OAuth login failed. Please try again',
        ));
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<RegisterResponse>> register(RegisterRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final body = _decodeJsonBody(response.body);

      if (response.statusCode == 201 || response.statusCode == 200 || response.statusCode == 400) {
        return ApiResponse<RegisterResponse>.fromJson(
          body,
          (json) => RegisterResponse.fromJson(json),
        );
      } else {
        throw Exception(_extractMessage(
          response,
          fallback: 'Lỗi đăng ký. Vui lòng thử lại',
        ));
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<String>> verifyOtp(VerifyOtpRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      final body = _decodeJsonBody(response.body);

      if (response.statusCode == 200 || response.statusCode == 400) {
        return ApiResponse<String>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: body['data']?.toString(),
          statusCode: body['statusCode'] is int
              ? body['statusCode'] as int
              : int.tryParse('${body['statusCode'] ?? ''}'),
        );
      } else {
        throw Exception(_extractMessage(
          response,
          fallback: 'Lỗi xác thực OTP. Vui lòng thử lại',
        ));
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
