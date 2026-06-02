import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/cart.dart';
import '../models/ghn_location.dart';
import '../models/ghn_shipping_preview.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/oauth_login_request.dart';
import '../models/order.dart';
import '../models/payment_models.dart';
import '../models/product_item.dart';
import '../models/register_request.dart';
import '../models/register_response.dart';
import '../models/verify_otp_request.dart';
import '../models/warranty.dart';
import '../models/chat_message.dart';

class ApiService {
  static const String baseUrl = API_BASE_URL;
  static const Duration _requestTimeout = Duration(seconds: 30);
  static String? accessToken;
  static void Function()? onUnauthorized;

  static void setAccessToken(String? token) {
    accessToken = token;
  }

  static Map<String, String> _headers({bool auth = false, bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (auth) {
      final token = accessToken;
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập để tiếp tục');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static ApiResponse<T> _parseObjectResponse<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawData = body['data'];
    return ApiResponse<T>(
      success: body['success'] == true,
      message: body['message']?.toString() ?? '',
      data: rawData is Map<String, dynamic> ? fromJson(rawData) : null,
      statusCode: body['statusCode'] is int
          ? body['statusCode'] as int
          : int.tryParse('${body['statusCode'] ?? ''}'),
    );
  }

  static ApiResponse<List<T>> _parseListResponse<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawData = body['data'];
    final list = rawData is List
        ? rawData.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : <T>[];
    return ApiResponse<List<T>>(
      success: body['success'] == true,
      message: body['message']?.toString() ?? '',
      data: list,
      statusCode: body['statusCode'] is int
          ? body['statusCode'] as int
          : int.tryParse('${body['statusCode'] ?? ''}'),
    );
  }

  static Future<ApiResponse<Cart>> getCart() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$CART_ENDPOINT'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, Cart.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải giỏ hàng'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Cart>> addCartItem({
    required int productItemId,
    required int quantity,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$CART_ENDPOINT/items'),
            headers: _headers(auth: true, json: true),
            body: jsonEncode({
              'productItemId': productItemId,
              'quantity': quantity,
            }),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, Cart.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể thêm vào giỏ hàng'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Cart>> updateCartItem({
    required int cartItemId,
    required int quantity,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$CART_ENDPOINT/items/$cartItemId'),
            headers: _headers(auth: true, json: true),
            body: jsonEncode({'quantity': quantity}),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, Cart.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể cập nhật giỏ hàng'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Cart>> removeCartItem(int cartItemId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$CART_ENDPOINT/items/$cartItemId'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, Cart.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể xóa sản phẩm'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<OrderDetail>> checkout(
    CreateOrderRequest request,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/checkout'),
            headers: _headers(auth: true, json: true),
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _parseObjectResponse(body, OrderDetail.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể đặt hàng'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Map<String, String> _ghnHeaders() {
    return {
      'Content-Type': 'application/json',
      'Token': GHN_TOKEN,
      'ShopId': GHN_SHOP_ID,
    };
  }

  static List<T> _parseGhnList<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawData = body['data'];
    final list = rawData is List
        ? rawData.whereType<Map<String, dynamic>>().map(fromJson).toList()
        : rawData is Map<String, dynamic>
        ? <T>[fromJson(rawData)]
        : <T>[];
    return list;
  }



  static Future<List<GhnProvince>> getGhnProvinces() async {
    try {
      final response = await http
          .get(
            Uri.parse('$GHN_BASE_URL/master-data/province'),
            headers: _ghnHeaders(),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      if (response.statusCode == 200) {
        final data = body['data'];
        if (data is! List) {
          throw Exception('Dữ liệu GHN không hợp lệ: $body');
        }
        return _parseGhnList(body, GhnProvince.fromJson);
      }
      throw Exception(
        'Lỗi GHN ${response.statusCode}: ${body['message'] ?? body}',
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<List<GhnDistrict>> getGhnDistricts(int provinceId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$GHN_BASE_URL/master-data/district?province_id=$provinceId'),
            headers: _ghnHeaders(),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      if (response.statusCode == 200) {
        final data = body['data'];
        if (data is! List) {
          throw Exception('Dữ liệu GHN không hợp lệ: $body');
        }
        return _parseGhnList(
          body,
          GhnDistrict.fromJson,
        ).where((district) => district.provinceId == provinceId).toList();
      }
      throw Exception(
        'Lỗi GHN ${response.statusCode}: ${body['message'] ?? body}',
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<List<GhnWard>> getGhnWards(int districtId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$GHN_BASE_URL/master-data/ward?district_id=$districtId'),
            headers: _ghnHeaders(),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      if (response.statusCode == 200) {
        return _parseGhnList(body, GhnWard.fromJson);
      }
      throw Exception(
        'Lỗi GHN ${response.statusCode}: ${body['message'] ?? body}',
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<GhnShippingPreviewResponse> previewGhnShippingOrder(
    GhnShippingPreviewRequest request,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$GHN_BASE_URL/v2/shipping-order/preview'),
            headers: _ghnHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      final preview = GhnShippingPreviewResponse.fromJson(body);
      if (response.statusCode == 200 && preview.isSuccess) {
        return preview;
      }
      throw Exception(
        preview.message?.isNotEmpty == true
            ? preview.message!
            : _extractMessage(response, fallback: 'Không thể kiểm tra phí GHN'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<List<OrderSummary>>> getMyOrders() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseListResponse(body, OrderSummary.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải đơn hàng'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<OrderDetail>> getOrderDetail(int orderId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/$orderId'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, OrderDetail.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải chi tiết đơn'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<OrderTrack>> trackOrder(String orderCode) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/track/$orderCode'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, OrderTrack.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể theo dõi đơn hàng'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Warranty>> getWarrantyBySerial(int serialId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$WARRANTIES_ENDPOINT/serial/$serialId'),
            headers: _headers(auth: true),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, Warranty.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải bảo hành'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<List<WarrantyClaim>>> getWarrantyClaimsByAccount(
    int accountId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$WARRANTY_CLAIMS_ENDPOINT/account/$accountId'),
            headers: _headers(auth: true),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseListResponse(body, WarrantyClaim.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải lịch sử bảo hành'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
  static Future<ApiResponse<OrderDetail>> cancelOrder(int orderId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/$orderId/cancel'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, OrderDetail.fromJson);
      }
      throw Exception(_extractMessage(response, fallback: 'Không thể hủy đơn'));
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<List<OrderSummary>>> getStaffOrders({
    String? status,
  }) async {
    try {
      final query = status != null && status.isNotEmpty
          ? '?status=$status'
          : '';
      final response = await http
          .get(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/staff$query'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseListResponse(body, OrderSummary.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải đơn hàng staff'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<OrderDetail>> getStaffOrderDetail(
    int orderId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/staff/$orderId'),
            headers: _headers(auth: true),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, OrderDetail.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải chi tiết đơn'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<OrderDetail>> updateStaffOrderStatus({
    required int orderId,
    required String status,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$ORDERS_ENDPOINT/staff/$orderId/status'),
            headers: _headers(auth: true, json: true),
            body: jsonEncode({'status': status}),
          )
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeAndCheckResponse(response);
      if (response.statusCode == 200) {
        return _parseObjectResponse(body, OrderDetail.fromJson);
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể cập nhật trạng thái'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<List<ProductItemSummary>>> getProductItems({
    int page = 1,
    int size = 10,
    int? brandId,
    int? categoryId,
    int? productId,
    int? productItemId,
    double? minPrice,
    double? maxPrice,
    String sortBy = 'newest',
    String sortDir = 'desc',
  }) async {
    try {
      final queryParameters = <String, String>{
        'page': '$page',
        'size': '$size',
        'sortBy': sortBy,
        'sortDir': sortDir,
      };
      if (brandId != null) {
        queryParameters['brandId'] = '$brandId';
      }
      if (categoryId != null) {
        queryParameters['categoryId'] = '$categoryId';
      }
      if (productId != null) {
        queryParameters['productId'] = '$productId';
      }
      if (productItemId != null) {
        queryParameters['productItemId'] = '$productItemId';
      }
      if (minPrice != null) {
        queryParameters['minPrice'] = '$minPrice';
      }
      if (maxPrice != null) {
        queryParameters['maxPrice'] = '$maxPrice';
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl$PRODUCT_ITEMS_ENDPOINT/list').replace(
              queryParameters: queryParameters,
            ),
          )
          .timeout(
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
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải danh sách sản phẩm'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<List<ProductItemVariantSummary>>> getProductItemVariants(
    int productId,
  ) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$PRODUCT_ITEMS_ENDPOINT/variants/$productId'))
          .timeout(
            _requestTimeout,
            onTimeout: () => throw Exception('Request timeout'),
          );

      final body = _decodeJsonBody(response.body);
      final rawData = body['data'];
      final items = rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(ProductItemVariantSummary.fromJson)
                .toList()
          : <ProductItemVariantSummary>[];

      if (response.statusCode == 200) {
        return ApiResponse<List<ProductItemVariantSummary>>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: items,
          statusCode: body['statusCode'] is int
              ? body['statusCode'] as int
              : int.tryParse('${body['statusCode'] ?? ''}'),
        );
      }

      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải danh sách biến thể'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<List<ProductCategory>>> getCategories() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$CATEGORIES_ENDPOINT'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );

      final body = _decodeJsonBody(response.body);
      final rawData = body['data'];
      final items = rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(ProductCategory.fromJson)
                .toList()
          : <ProductCategory>[];

      if (response.statusCode == 200) {
        return ApiResponse<List<ProductCategory>>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: items,
          statusCode: body['statusCode'] is int
              ? body['statusCode'] as int
              : int.tryParse('${body['statusCode'] ?? ''}'),
        );
      }

      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải danh sách danh mục'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getProfile() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/profile'), headers: _headers(auth: true))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: body['data'] is Map<String, dynamic> ? body['data'] : {},
          statusCode: response.statusCode,
        );
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải hồ sơ'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> updateProfile({
    String? fullName,
    String? phone,
    String? address,
    int? provinceId,
    String? provinceName,
    int? districtId,
    String? districtName,
    String? wardCode,
    String? wardName,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['fullName'] = fullName;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (provinceId != null) body['provinceId'] = provinceId;
      if (provinceName != null) body['provinceName'] = provinceName;
      if (districtId != null) body['districtId'] = districtId;
      if (districtName != null) body['districtName'] = districtName;
      if (wardCode != null) body['wardCode'] = wardCode;
      if (wardName != null) body['wardName'] = wardName;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

      final response = await http
          .put(
            Uri.parse('$baseUrl/profile'),
            headers: _headers(auth: true, json: true),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final decoded = _decodeJsonBody(response.body);
      return ApiResponse<Map<String, dynamic>>(
        success: decoded['success'] == true,
        message: decoded['message']?.toString() ?? '',
        data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : {},
        statusCode: response.statusCode,
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/change-password'),
        headers: _headers(auth: true, json: true),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      final body = _decodeJsonBody(response.body);
      return ApiResponse<void>(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: null,
        statusCode: response.statusCode,
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> uploadAvatar(
      XFile file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/uploads/users'),
      );
      request.headers.addAll(_headers(auth: true));
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = _decodeJsonBody(response.body);
      return ApiResponse<Map<String, dynamic>>(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: body is Map<String, dynamic> ? body : {},
        statusCode: response.statusCode,
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<PaymentQrData>> getPaymentQr({
    required String gencode,
    required double amount,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/payment/qr?gencode=$gencode&amount=$amount'),
            headers: _headers(auth: true),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      if (response.statusCode == 200) {
        return ApiResponse<PaymentQrData>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: body['data'] is Map<String, dynamic>
              ? PaymentQrData.fromJson(body['data'])
              : null,
          statusCode: response.statusCode,
        );
      }
      throw Exception(_extractMessage(response, fallback: 'Không thể tạo QR'));
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<PaymentStatusData>> getPaymentStatus(
    String gencode,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/payment/status/$gencode'),
            headers: _headers(auth: true),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );
      final body = _decodeJsonBody(response.body);
      if (response.statusCode == 200) {
        return ApiResponse<PaymentStatusData>(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          data: body['data'] is Map<String, dynamic>
              ? PaymentStatusData.fromJson(body['data'])
              : null,
          statusCode: response.statusCode,
        );
      }
      throw Exception(
        _extractMessage(response, fallback: 'Không thể kiểm tra thanh toán'),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<ProductItemDetail>> getProductItemDetail(
    int productItemId,
  ) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$PRODUCT_ITEMS_ENDPOINT/$productItemId'))
          .timeout(
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

      throw Exception(
        _extractMessage(response, fallback: 'Không thể tải chi tiết sản phẩm'),
      );
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

  static Map<String, dynamic> _decodeAndCheckResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      onUnauthorized?.call();
    }
    final body = _decodeJsonBody(response.body);
    if (body['success'] == false) {
      final msg = body['message']?.toString() ?? '';
      if (msg.contains('đăng nhập') || msg.toLowerCase().contains('unauthorized')) {
        onUnauthorized?.call();
      }
    }
    return body;
  }
  static String _extractMessage(
    http.Response response, {
    String fallback = 'Request failed',
  }) {
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
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(
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
        throw Exception(
          _extractMessage(
            response,
            fallback: 'Lỗi đăng nhập. Vui lòng thử lại',
          ),
        );
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<LoginResponse>> oauthLogin(
    OAuthLoginRequest request,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/oauth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(
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
        throw Exception(
          _extractMessage(
            response,
            fallback: 'OAuth login failed. Please try again',
          ),
        );
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<RegisterResponse>> register(
    RegisterRequest request,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );

      final body = _decodeJsonBody(response.body);

      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 400) {
        return ApiResponse<RegisterResponse>.fromJson(
          body,
          (json) => RegisterResponse.fromJson(json),
        );
      } else {
        throw Exception(
          _extractMessage(response, fallback: 'Lỗi đăng ký. Vui lòng thử lại'),
        );
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<ApiResponse<String>> verifyOtp(VerifyOtpRequest request) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(
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
        throw Exception(
          _extractMessage(
            response,
            fallback: 'Lỗi xác thực OTP. Vui lòng thử lại',
          ),
        );
      }
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

<<<<<<< HEAD
  // ─── Chatbot ────────────────────────────────────────────────────────────────

  static const String _chatbotBaseUrl = 'https://rag.doantrang.online';

  static Future<ChatbotResponse> sendChat({
    required String text,
    required String sessionId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_chatbotBaseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'session_id': sessionId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ChatbotResponse.fromJson(body);
      } else {
        throw Exception('Server lỗi (${response.statusCode})');
      }
=======
  static Future<ApiResponse<String>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(
            const Duration(seconds: 15),
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
      }

      throw Exception(
        _extractMessage(
          response,
          fallback: 'Không thể gửi mã khôi phục. Vui lòng thử lại',
        ),
      );
>>>>>>> 6fbd4b6de364c604240e11e98cd09b118eca6cc1
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
<<<<<<< HEAD
}

class ChatbotResponse {
  final String sessionId;
  final String answer;
  final List<RetrievedProduct> retrievedProducts;
  final String? decisionAction;
  final String? decisionReason;

  ChatbotResponse({
    required this.sessionId,
    required this.answer,
    required this.retrievedProducts,
    this.decisionAction,
    this.decisionReason,
  });

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) {
    final products = (json['retrieved_products'] as List<dynamic>?)
            ?.map((e) => RetrievedProduct.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ChatbotResponse(
      sessionId: json['session_id'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      retrievedProducts: products,
      decisionAction: (json['decision'] as Map<String, dynamic>?)?['action'] as String?,
      decisionReason: (json['decision'] as Map<String, dynamic>?)?['reason'] as String?,
    );
=======

  static Future<ApiResponse<String>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'newPassword': newPassword,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
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
      }

      throw Exception(
        _extractMessage(
          response,
          fallback: 'Khong the dat lai mat khau. Vui long thu lai',
        ),
      );
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
>>>>>>> 6fbd4b6de364c604240e11e98cd09b118eca6cc1
  }
}
