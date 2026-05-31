// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/api_config.dart';
import '../models/cart.dart';
import '../models/ghn_location.dart';
import '../models/ghn_shipping_preview.dart';
import '../models/order.dart';
import '../models/payment_models.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String _paymentMethod = 'COD';
  bool _isLoadingProfile = true;
  bool _isLoadingProvinces = true;
  bool _isLoadingDistricts = false;
  bool _isLoadingWards = false;
  bool _isCheckingPreview = false;
  bool _isSubmitting = false;

  List<GhnProvince> _provinces = [];
  List<GhnDistrict> _districts = [];
  List<GhnWard> _wards = [];
  GhnProvince? _selectedProvince;
  GhnDistrict? _selectedDistrict;
  GhnWard? _selectedWard;
  String _customerName = 'Khách hàng';
  GhnShippingPreviewResponse? _previewResponse;

  // Payment screen state
  bool _showPayment = false;
  String? _gencode;
  int? _orderId;
  String? _orderCode;
  double? _totalAmount;
  int _secondsLeft = 0;
  Timer? _countdownTimer;
  StompClient? _paymentStompClient;
  PaymentQrData? _qrData;
  String _paymentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _loadProfileDefaults();
    _loadProvinces();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _paymentStompClient?.deactivate();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileDefaults() async {
    try {
      final resp = await ApiService.getProfile();
      if (resp.success && resp.data != null) {
        final address = resp.data!['address']?.toString() ?? '';
        final phone = resp.data!['phone']?.toString() ?? '';
        final fullName =
            resp.data!['full_name']?.toString() ??
            resp.data!['fullName']?.toString() ??
            '';
        if (mounted) {
          setState(() {
            _addressController.text = address;
            _phoneController.text = phone;
            if (fullName.isNotEmpty) {
              _customerName = fullName;
            }
          });
        }
      }
    } catch (_) {
      // Ignore — user can fill manually
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await ApiService.getGhnProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Không tải được danh sách tỉnh/thành: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _onProvinceChanged(GhnProvince? province) async {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedWard = null;
      _districts = [];
      _wards = [];
      _previewResponse = null;
      _isLoadingDistricts = province != null;
      _isLoadingWards = false;
    });

    if (province == null) return;

    try {
      final districts = await ApiService.getGhnDistricts(province.provinceId);
      if (!mounted) return;
      setState(() {
        _districts = districts;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Không tải được quận/huyện: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingDistricts = false);
    }
  }

  Future<void> _onDistrictChanged(GhnDistrict? district) async {
    setState(() {
      _selectedDistrict = district;
      _selectedWard = null;
      _wards = [];
      _previewResponse = null;
      _isLoadingWards = district != null;
    });

    if (district == null) return;

    try {
      final wards = await ApiService.getGhnWards(district.districtId);
      if (!mounted) return;
      setState(() {
        _wards = wards;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Không tải được phường/xã: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingWards = false);
    }
  }

  Future<void> _checkGhnPreview(Cart? cart) async {
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    if (cart == null || cart.items.isEmpty) {
      _showSnackBar('Giỏ hàng đang trống');
      return;
    }
    if (address.isEmpty || phone.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ và số điện thoại');
      return;
    }
    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedWard == null) {
      _showSnackBar('Vui lòng chọn Tỉnh/Thành, Quận/Huyện và Phường/Xã');
      return;
    }

    setState(() {
      _isCheckingPreview = true;
      _previewResponse = null;
    });

    try {
      final request = GhnShippingPreviewRequest(
        paymentTypeId: _paymentMethod == 'COD' ? 2 : 1,
        note: 'Kiểm tra đơn hàng trên FE',
        requiredNote: GHN_REQUIRED_NOTE,
        returnPhone: GHN_RETURN_PHONE,
        returnAddress: GHN_RETURN_ADDRESS,
        clientOrderCode: '',
        fromName: GHN_FROM_NAME,
        fromPhone: GHN_FROM_PHONE,
        fromAddress: GHN_FROM_ADDRESS,
        fromWardName: GHN_FROM_WARD_NAME,
        fromDistrictName: GHN_FROM_DISTRICT_NAME,
        fromProvinceName: GHN_FROM_PROVINCE_NAME,
        toName: _customerName,
        toPhone: phone,
        toAddress: address,
        toWardName: _selectedWard!.wardName,
        toWardCode: _selectedWard!.wardCode,
        toDistrictName: _selectedDistrict!.districtName,
        toProvinceName: _selectedProvince!.provinceName,
        codAmount: _paymentMethod == 'COD' ? cart.totalAmount.round() : 0,
        content: 'Đơn hàng preview từ FE',
        weight: GHN_DEFAULT_WEIGHT,
        length: GHN_DEFAULT_LENGTH,
        width: GHN_DEFAULT_WIDTH,
        height: GHN_DEFAULT_HEIGHT,
        pickStationId: null,
        deliverStationId: null,
        insuranceValue: cart.totalAmount.round(),
        serviceTypeId: GHN_SERVICE_TYPE_ID,
        coupon: null,
        pickupTime: null,
        pickShift: const [GHN_PICK_SHIFT],
        codFailedAmount: 2000,
        items: cart.items
            .map(
              (item) => GhnPreviewItem(
                name: item.productName ?? 'Sản phẩm',
                code: item.sku ?? '',
                quantity: item.quantity,
                price: item.unitPrice.round(),
                length: GHN_DEFAULT_LENGTH,
                width: GHN_DEFAULT_WIDTH,
                height: GHN_DEFAULT_HEIGHT,
                weight: GHN_DEFAULT_WEIGHT,
                category: GhnPreviewCategory(level1: 'Sản phẩm'),
              ),
            )
            .toList(),
      );

      final preview = await ApiService.previewGhnShippingOrder(request);
      if (!mounted) return;
      setState(() => _previewResponse = preview);
      _showSnackBar('Đã kiểm tra thông tin GHN thành công');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Không thể kiểm tra thông tin đơn hàng: $e');
    } finally {
      if (mounted) setState(() => _isCheckingPreview = false);
    }
  }

  Future<void> _confirmCheckout(Cart? cart) async {
    final preview = _previewResponse;
    if (cart == null || cart.items.isEmpty) {
      _showSnackBar('Giỏ hàng đang trống');
      return;
    }
    if (preview?.data == null) {
      _showSnackBar('Vui lòng kiểm tra đơn hàng GHN trước khi xác nhận');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận đặt hàng?'),
        content: Text(
          'Tổng phí GHN: ${formatCurrency(preview!.data!.totalFee?.toDouble())}\n'
          'Bạn có chắc muốn tiến hành đặt hàng không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _submit();
  }

  Future<void> _confirmPickupCheckout(Cart? cart) async {
    if (cart == null || cart.items.isEmpty) {
      _showSnackBar('Giỏ hàng đang trống');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận lấy tại cửa hàng?'),
        content: const Text(
          'Đơn hàng sẽ được tạo và hoàn tất ngay, không cần GHN hay thanh toán online.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _submit(isPickup: true);
  }

  String _formatPreviewDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal().toString();
    return local.length >= 16
        ? local.substring(0, 16).replaceFirst('T', ' ')
        : local;
  }

  Widget _buildPreviewCard() {
    final preview = _previewResponse;
    if (preview?.data == null) return const SizedBox.shrink();

    final data = preview!.data!;
    final fee = data.fee;

    return _Section(
      title: 'Thông tin đơn hàng GHN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.orderCode != null && data.orderCode!.isNotEmpty)
            _previewRow('Mã đơn', data.orderCode!),
          if (data.sortCode != null && data.sortCode!.isNotEmpty)
            _previewRow('Sort code', data.sortCode!),
          if (data.transType != null && data.transType!.isNotEmpty)
            _previewRow('Loại vận chuyển', data.transType!),
          if (fee != null) ...[
            const Divider(height: 20),
            _previewRow(
              'Phí vận chuyển',
              formatCurrency(fee.mainService?.toDouble()),
            ),
            _previewRow(
              'Phí khai giá',
              formatCurrency(fee.insurance?.toDouble()),
            ),
            _previewRow(
              'Phí hoàn/đổi',
              formatCurrency(fee.returnFee?.toDouble()),
            ),
            _previewRow('Phí giao lại', formatCurrency(fee.r2s?.toDouble())),
            _previewRow('Tổng phí', formatCurrency(data.totalFee?.toDouble())),
          ],
          const Divider(height: 20),
          _previewRow(
            'Giao dự kiến',
            _formatPreviewDate(data.expectedDeliveryTime),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7893))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF14213D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit({bool isPickup = false}) async {
    final address = isPickup
        ? GHN_FROM_ADDRESS
        : _addressController.text.trim();
    final phone = _phoneController.text.trim();

    if (address.isEmpty || phone.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ và số điện thoại');
      return;
    }

    if (!isPickup &&
        (_selectedProvince == null ||
            _selectedDistrict == null ||
            _selectedWard == null)) {
      _showSnackBar('Vui lòng chọn Tỉnh/Thành, Quận/Huyện và Phường/Xã');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.checkout(
        CreateOrderRequest(
          shippingAddress: address,
          phone: phone,
          provinceId: isPickup ? null : _selectedProvince?.provinceId,
          districtId: isPickup ? null : _selectedDistrict?.districtId,
          wardCode: isPickup ? null : _selectedWard?.wardCode,
          provinceName: isPickup ? null : _selectedProvince?.provinceName,
          districtName: isPickup ? null : _selectedDistrict?.districtName,
          wardName: isPickup ? null : _selectedWard?.wardName,
          paymentMethod: _paymentMethod,
        ),
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        final order = response.data!;

        if (_paymentMethod == 'Pickup' || _paymentMethod == 'COD') {
          // COD: xác nhận luôn, sang màn hình order
          await context.read<CartProvider>().loadCart(silent: true);
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: order.orderId,
                initialOrder: order,
              ),
            ),
            (route) => route.isFirst,
          );
          _showSnackBar(
            _paymentMethod == 'Pickup'
                ? 'Đã tạo đơn nhận tại cửa hàng — ${order.orderCode}'
                : 'Đặt hàng thành công — ${order.orderCode}',
          );
        } else {
          // Transfer: hiển thị màn hình QR + countdown
          if (!mounted) return;
          final amount = order.totalPrice ?? 0;
          setState(() {
            _gencode = order.gencode;
            _orderId = order.orderId;
            _orderCode = order.orderCode;
            _totalAmount = amount;
            _showPayment = true;
            _paymentStatus = 'pending';
          });
          _fetchQrAndStartCountdown(order.gencode!, amount);
        }
      } else {
        _showSnackBar(
          response.message.isNotEmpty ? response.message : 'Đặt hàng thất bại',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _fetchQrAndStartCountdown(String gencode, double amount) async {
    try {
      final resp = await ApiService.getPaymentQr(
        gencode: gencode,
        amount: amount,
      );
      if (!mounted) return;
      if (resp.success && resp.data != null) {
        setState(() {
          _qrData = resp.data;
          _secondsLeft = 30 * 60; // 30 minutes
        });
        _connectPaymentSocket(gencode);
        _startCountdown();
      } else {
        _showSnackBar('Không thể tạo mã QR: ${resp.message}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Lỗi tạo QR: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        }
      });

      if (_secondsLeft == 0) {
        _countdownTimer?.cancel();
        await _handlePaymentTimeout();
        return;
      }

      // Poll payment status every 5 seconds
      if (_secondsLeft % 5 == 0 && _paymentStatus != 'paid') {
        await _pollPaymentStatus();
      }
    });
  }

  Future<void> _pollPaymentStatus() async {
    if (_gencode == null) return;
    try {
      final resp = await ApiService.getPaymentStatus(_gencode!);
      if (!mounted) return;
      if (resp.success && resp.data != null) {
        final status = resp.data!.status;
        if (status == 'paid' && _paymentStatus != 'paid') {
          _countdownTimer?.cancel();
          await _handlePaymentSuccess();
        }
      }
    } catch (_) {
      // Ignore polling errors
    }
  }

  void _connectPaymentSocket(String gencode) {
    _paymentStompClient?.deactivate();

    final wsUrl =
        '${ApiService.baseUrl.replaceFirst(RegExp(r'/v1/api/?$'), '')}/ws/payment';
    final topic = '/topic/payment/$gencode';

    _paymentStompClient = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: (frame) {
          _paymentStompClient?.subscribe(
            destination: topic,
            callback: (frame) {
              final body = frame.body;
              if (body == null || body.isEmpty) return;
              try {
                final payload = PaymentNotificationPayload.fromJson(
                  jsonDecode(body) as Map<String, dynamic>,
                );
                if (payload.isPaid && _paymentStatus != 'paid') {
                  _countdownTimer?.cancel();
                  _handlePaymentSuccess();
                }
              } catch (_) {
                // Ignore malformed websocket payloads and keep polling as fallback.
              }
            },
          );
        },
        onWebSocketError: (dynamic error) {
          // Polling remains as fallback.
        },
        onStompError: (dynamic frame) {
          // Polling remains as fallback.
        },
      ),
    );

    _paymentStompClient?.activate();
  }

  Future<void> _handlePaymentSuccess() async {
    if (!mounted) return;
    setState(() => _paymentStatus = 'paid');

    // Reload cart (should be empty after successful transfer order)
    await context.read<CartProvider>().loadCart(silent: true);

    if (!mounted) return;

    // Show success + navigate to order detail
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Thanh toán thành công'),
          ],
        ),
        content: const Text('Đơn hàng của bạn đã được xác nhận.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(orderId: _orderId ?? 0),
                ),
                (route) => route.isFirst,
              );
            },
            child: const Text('Xem đơn hàng'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaymentTimeout() async {
    if (!mounted) return;
    setState(() => _paymentStatus = 'expired');

    await context.read<CartProvider>().loadCart(silent: true);

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Hết thời gian'),
          ],
        ),
        content: const Text(
          'Hết thời gian thanh toán.\n'
          'Sản phẩm đã được hoàn lại giỏ hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quay về giỏ hàng'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(); // back to cart
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─────────────────────────────────────────────
  // PAYMENT SCREEN
  // ─────────────────────────────────────────────
  Widget _buildPaymentScreen() {
    final color = _secondsLeft <= 60
        ? Colors.red
        : (_secondsLeft <= 120 ? Colors.orange : const Color(0xFF10B981));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(),
        ),
        title: const Text(
          'Thanh toán chuyển khoản',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3EAF5)),
            ),
            child: Column(
              children: [
                const Text(
                  'Thời gian còn lại',
                  style: TextStyle(color: Color(0xFF6B7893), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCountdown(_secondsLeft),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QR Code
          if (_qrData != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3EAF5)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Quét mã QR để thanh toán',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF14213D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE3EAF5)),
                    ),
                    child: Image.network(
                      _qrData!.qrUrl,
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: Text(
                                'Không tải được QR',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _infoRow('Ngân hàng', _qrData!.bankName),
                        const Divider(height: 12),
                        _infoRow('Số tài khoản', _qrData!.accountNumber),
                        const Divider(height: 12),
                        _infoRow('Số tiền', formatCurrency(_qrData!.amount)),
                        const Divider(height: 12),
                        _infoRow(
                          'Nội dung CK',
                          _qrData!.gencode,
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Show order code if available
          if (_orderCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Mã đơn: ${_orderCode!}',
                style: const TextStyle(
                  color: Color(0xFF42506A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Amount
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F67E2).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng thanh toán',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14213D),
                  ),
                ),
                Text(
                  formatCurrency(_totalAmount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F67E2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Hướng dẫn',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Quét mã QR bằng app ngân hàng\n'
                  '2. Nhập đúng số tiền và nội dung chuyển khoản\n'
                  '3. Sau khi chuyển, đơn hàng sẽ tự động xác nhận\n'
                  '4. Hết 30 phút sẽ tự động hủy và hoàn hàng về giỏ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Status badge
          if (_paymentStatus == 'pending')
            OutlinedButton.icon(
              onPressed: _pollPaymentStatus,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Kiểm tra thanh toán'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7893), fontSize: 14),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: highlight ? 15 : 14,
                color: highlight
                    ? const Color(0xFF1F67E2)
                    : const Color(0xFF14213D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hủy thanh toán?'),
        content: const Text(
          'Bạn có chắc muốn rời khỏi trang thanh toán?\n'
          'Đơn hàng sẽ tự động bị hủy sau 30 phút nếu không thanh toán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // back to cart
            },
            child: const Text('Rời đi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CHECKOUT SCREEN
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showPayment) {
      return _buildPaymentScreen();
    }

    final cart = context.watch<CartProvider>().cart;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Thanh toán',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Section(
                  title: 'Địa chỉ giao hàng',
                  child: Column(
                    children: [
                      DropdownButtonFormField<GhnProvince>(
                        initialValue: _selectedProvince,
                        items: _provinces
                            .map(
                              (province) => DropdownMenuItem<GhnProvince>(
                                value: province,
                                child: Text(province.provinceName),
                              ),
                            )
                            .toList(),
                        onChanged: _isLoadingProvinces
                            ? null
                            : _onProvinceChanged,
                        decoration: _inputDecoration(
                          _isLoadingProvinces
                              ? 'Đang tải tỉnh/thành...'
                              : 'Chọn Tỉnh/Thành',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<GhnDistrict>(
                        initialValue: _selectedDistrict,
                        items: _districts
                            .map(
                              (district) => DropdownMenuItem<GhnDistrict>(
                                value: district,
                                child: Text(district.districtName),
                              ),
                            )
                            .toList(),
                        onChanged:
                            (_selectedProvince == null || _isLoadingDistricts)
                            ? null
                            : _onDistrictChanged,
                        decoration: _inputDecoration(
                          _selectedProvince == null
                              ? 'Chọn Tỉnh/Thành trước'
                              : (_isLoadingDistricts
                                    ? 'Đang tải quận/huyện...'
                                    : 'Chọn Quận/Huyện'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<GhnWard>(
                        initialValue: _selectedWard,
                        items: _wards
                            .map(
                              (ward) => DropdownMenuItem<GhnWard>(
                                value: ward,
                                child: Text(ward.wardName),
                              ),
                            )
                            .toList(),
                        onChanged:
                            (_selectedDistrict == null || _isLoadingWards)
                            ? null
                            : (ward) => setState(() => _selectedWard = ward),
                        decoration: _inputDecoration(
                          _selectedDistrict == null
                              ? 'Chọn Quận/Huyện trước'
                              : (_isLoadingWards
                                    ? 'Đang tải phường/xã...'
                                    : 'Chọn Phường/Xã'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) =>
                            setState(() => _previewResponse = null),
                        decoration: _inputDecoration('Số điện thoại'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        maxLines: 3,
                        onChanged: (_) =>
                            setState(() => _previewResponse = null),
                        decoration: _inputDecoration(
                          'Địa chỉ chi tiết, số nhà, tên đường...',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Phương thức thanh toán',
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'COD',
                        groupValue: _paymentMethod,
                        onChanged: (v) => setState(() {
                          _paymentMethod = v!;
                          _previewResponse = null;
                        }),
                        title: const Text('Thanh toán khi nhận hàng (COD)'),
                        activeColor: const Color(0xFF1F67E2),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: 'Pickup',
                        groupValue: _paymentMethod,
                        onChanged: (v) => setState(() {
                          _paymentMethod = v!;
                          _previewResponse = null;
                        }),
                        title: const Text('Lấy tại cửa hàng'),
                        secondary: const Icon(
                          Icons.store,
                          color: Color(0xFF1F67E2),
                          size: 22,
                        ),
                        activeColor: const Color(0xFF1F67E2),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: 'Transfer',
                        groupValue: _paymentMethod,
                        onChanged: (v) => setState(() {
                          _paymentMethod = v!;
                          _previewResponse = null;
                        }),
                        title: const Text('Chuyển khoản ngân hàng'),
                        secondary: const Icon(
                          Icons.qr_code,
                          color: Color(0xFF1F67E2),
                          size: 22,
                        ),
                        activeColor: const Color(0xFF1F67E2),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_paymentMethod != 'Pickup') ...[
                  _Section(
                    title: 'Kiểm tra thông tin GHN',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Kiểm tra phí vận chuyển và thời gian giao dự kiến trước khi đặt hàng.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isCheckingPreview
                              ? null
                              : () => _checkGhnPreview(cart),
                          icon: _isCheckingPreview
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                            _isCheckingPreview
                                ? 'Đang kiểm tra...'
                                : 'Kiểm tra đơn hàng GHN',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1F67E2),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildPreviewCard(),

                  if (_previewResponse?.message != null &&
                      _previewResponse!.message!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _previewResponse!.message!,
                        style: const TextStyle(
                          color: Color(0xFF6B7893),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ] else ...[
                  _Section(
                    title: 'Lấy tại cửa hàng',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          GHN_FROM_ADDRESS,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14213D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Đơn hàng sẽ được tạo và hoàn tất ngay, không cần GHN hay thanh toán online.',
                          style: TextStyle(
                            color: Color(0xFF6B7893),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _Section(
                  title: 'Tóm tắt đơn hàng',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cart?.totalItems ?? 0} sản phẩm',
                        style: const TextStyle(color: Color(0xFF6B7893)),
                      ),
                      const SizedBox(height: 8),
                      if (cart != null && cart.promotionSavings > 0)
                        Text(
                          'Giảm giá khuyến mãi: -${formatCurrency(cart.promotionSavings)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Tổng thanh toán: ${formatCurrency(cart?.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F67E2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (_paymentMethod == 'Pickup') {
                      await _confirmPickupCheckout(cart);
                      return;
                    }
                    if (cart == null || cart.items.isEmpty) {
                      _showSnackBar('Giỏ hàng đang trống');
                      return;
                    }
                    if (_previewResponse?.data == null) {
                      await _checkGhnPreview(cart);
                      return;
                    }
                    await _confirmCheckout(cart);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F67E2),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _paymentMethod == 'Pickup'
                        ? 'Xác nhận lấy tại cửa hàng'
                        : (_previewResponse?.data == null
                              ? 'Kiểm tra đơn hàng GHN'
                              : (_paymentMethod == 'COD'
                                    ? 'Xác nhận đặt hàng'
                                    : 'Xác nhận và tạo QR')),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF14213D),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
