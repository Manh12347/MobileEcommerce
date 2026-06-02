import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/ghn_location.dart';
import '../models/warranty.dart';
import '../providers/cart_provider.dart';
import '../providers/login_provider.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import 'login_screen.dart';
import 'main_shell_screen.dart';
import 'staff_orders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _fullName;
  String? _phone;
  String? _email;
  String? _address;
  String? _provinceName;
  String? _districtName;
  String? _wardName;
  String? _avatarUrl;

  List<WarrantyClaim> _warrantyClaims = [];
  bool _isLoadingWarranty = true;

  List<OrderSummary> _orders = [];
  double _totalSpent = 0;
  int _totalOrders = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadWarrantyClaims(),
      _loadSpendingStats(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final resp = await ApiService.getProfile();
      if (!mounted || !resp.success || resp.data == null) return;
      final d = resp.data!;
      setState(() {
        _fullName = d['fullName']?.toString();
        _phone = d['phone']?.toString();
        _email = d['email']?.toString();
        _address = d['address']?.toString();
        _provinceName = d['provinceName']?.toString();
        _districtName = d['districtName']?.toString();
        _wardName = d['wardName']?.toString();
        _avatarUrl = d['avatarUrl']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _loadWarrantyClaims() async {
    final accountId = context.read<LoginProvider>().loginResponse?.accountId;
    if (accountId == null) {
      if (mounted) setState(() => _isLoadingWarranty = false);
      return;
    }
    try {
      final resp = await ApiService.getWarrantyClaimsByAccount(accountId);
      if (!mounted) return;
      setState(() {
        _warrantyClaims = resp.data ?? [];
        _isLoadingWarranty = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingWarranty = false);
    }
  }

  Future<void> _loadSpendingStats() async {
    try {
      final resp = await ApiService.getMyOrders();
      if (!mounted) return;
      final orders = resp.data ?? [];
      double total = 0;
      for (final o in orders) {
        total += o.totalPrice ?? 0;
      }
      setState(() {
        _orders = orders;
        _totalSpent = total;
        _totalOrders = orders.length;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  String get _displayName {
    if (_fullName != null && _fullName!.isNotEmpty) return _fullName!;
    if (_email != null && _email!.isNotEmpty) return _email!;
    return 'Khách hàng';
  }

  String get _fullAddress {
    final parts = <String>[];
    if (_address != null && _address!.isNotEmpty) parts.add(_address!);
    if (_wardName != null && _wardName!.isNotEmpty) parts.add(_wardName!);
    if (_districtName != null && _districtName!.isNotEmpty) parts.add(_districtName!);
    if (_provinceName != null && _provinceName!.isNotEmpty) parts.add(_provinceName!);
    return parts.isEmpty ? 'Chưa cập nhật' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Cá nhân',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1F67E2)),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAll();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Card 1: Thông tin cá nhân ──────────────────────────────────
                  _buildSectionTitle('Thông tin cá nhân'),
                  const SizedBox(height: 8),
              _PersonalInfoCard(
                avatarUrl: _avatarUrl,
                name: _displayName,
                email: _email,
                phone: _phone,
                fullAddress: _fullAddress,
                onEditTap: () => _showEditProfileSheet(context),
              ),
                  const SizedBox(height: 24),

                  // ── Card 2: Bảo hành ─────────────────────────────────────────
                  _buildSectionTitle('Phiếu bảo hành'),
                  const SizedBox(height: 8),
                  _WarrantyCard(
                    claims: _warrantyClaims,
                    isLoading: _isLoadingWarranty,
                  ),
                  const SizedBox(height: 24),

                  // ── Card 3: Chi tiêu ──────────────────────────────────────────
                  _buildSectionTitle('Chi tiêu'),
                  const SizedBox(height: 8),
                  _SpendingCard(
                    orders: _orders,
                    totalSpent: _totalSpent,
                    totalOrders: _totalOrders,
                    isLoading: _isLoadingStats,
                  ),
                  const SizedBox(height: 24),

                  // ── Card 4: Cài đặt ───────────────────────────────────────────
                  _buildSectionTitle('Cài đặt'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    onChangePassword: () => _showChangePasswordSheet(context),
                  ),
                  const SizedBox(height: 24),

                  // ── Quick actions ─────────────────────────────────────────────
                  _MenuTile(
                    icon: Icons.home_outlined,
                    title: 'Trang chủ',
                    onTap: () => _switchTab(context, 0),
                  ),
                  _MenuTile(
                    icon: Icons.grid_view_rounded,
                    title: 'Danh mục',
                    onTap: () => _switchTab(context, 1),
                  ),
                  _MenuTile(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Giỏ hàng',
                    onTap: () => _switchTab(context, 2),
                  ),
                  _MenuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Đơn hàng của tôi',
                    onTap: () => _switchTab(context, 3),
                  ),
                  if (login.isStaff) ...[
                    const SizedBox(height: 8),
                    _MenuTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Xử lý đơn hàng (Staff)',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StaffOrdersScreen()),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded,
                        color: Color(0xFFEF4444)),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF14213D),
      ),
    );
  }

  void _switchTab(BuildContext context, int index) {
    final shell = context.findAncestorStateOfType<MainShellScreenState>();
    shell?.goToTab(index);
  }

  void _showEditProfileSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        initialFullName: _fullName,
        initialPhone: _phone,
        initialAddress: _address,
        initialProvinceName: _provinceName,
        initialDistrictName: _districtName,
        initialWardName: _wardName,
        onSaved: () {
          _loadProfile();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onSaved: () {
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final loginProvider = context.read<LoginProvider>();
    final cartProvider = context.read<CartProvider>();
    await loginProvider.logout();
    cartProvider.clearLocal();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

// ─── Card 1: Thông tin cá nhân ────────────────────────────────────────────────

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({
    required this.avatarUrl,
    required this.name,
    required this.email,
    required this.phone,
    required this.fullAddress,
    required this.onEditTap,
  });

  final String? avatarUrl;
  final String name;
  final String? email;
  final String? phone;
  final String fullAddress;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AvatarWidget(
                avatarUrl: avatarUrl,
                name: name,
                size: 60,
                onTap: () => _pickAndUploadAvatar(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14213D),
                      ),
                    ),
                    if (email != null && email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7893),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF1F67E2), size: 20),
                onPressed: onEditTap,
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow(Icons.phone_outlined, 'Điện thoại', phone ?? 'Chưa cập nhật'),
          const SizedBox(height: 10),
          _infoRow(Icons.location_on_outlined, 'Địa chỉ', fullAddress, maxLines: 3),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1F67E2)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF91A0B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF14213D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Đang tải ảnh lên...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final resp = await ApiService.uploadAvatar(picked);
      if (resp.success) {
        final uploadedUrl = resp.data?['url']?.toString();
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          await ApiService.updateProfile(avatarUrl: uploadedUrl);
        }
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('Cập nhật ảnh đại diện thành công!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(resp.message),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({
    required this.avatarUrl,
    required this.name,
    required this.size,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE3EAF5),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? Image.network(
                      avatarUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initials(),
                    )
                  : _initials(),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1F67E2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt,
                size: size * 0.18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: const Color(0xFF1F67E2),
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ─── Card 4: Cài đặt ────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onChangePassword});

  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFF1F67E2)),
            title: const Text(
              'Đổi mật khẩu',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF91A0B8)),
            onTap: onChangePassword,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.help_outline, color: Color(0xFF1F67E2)),
            title: const Text(
              'Trợ giúp & Hỗ trợ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF91A0B8)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng đang phát triển')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Sheet: Chỉnh sửa thông tin ─────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.initialFullName,
    required this.initialPhone,
    required this.initialAddress,
    required this.initialProvinceName,
    required this.initialDistrictName,
    required this.initialWardName,
    required this.onSaved,
  });

  final String? initialFullName;
  final String? initialPhone;
  final String? initialAddress;
  final String? initialProvinceName;
  final String? initialDistrictName;
  final String? initialWardName;
  final VoidCallback onSaved;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _houseCtrl;

  List<GhnProvince> _provinces = [];
  List<GhnDistrict> _districts = [];
  List<GhnWard> _wards = [];

  GhnProvince? _selectedProvince;
  GhnDistrict? _selectedDistrict;
  GhnWard? _selectedWard;

  // Pending selections to apply after provinces list loads
  int? _pendingProvinceId;
  int? _pendingDistrictId;
  String? _pendingWardCode;

  bool _loadingLocations = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialFullName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _houseCtrl = TextEditingController();

    _pendingProvinceId = null;
    _pendingDistrictId = null;
    _pendingWardCode = null;

    final pId = _toInt(widget.initialProvinceName);
    final dId = _toInt(widget.initialDistrictName);
    if (pId != null) _pendingProvinceId = pId;
    if (dId != null) _pendingDistrictId = dId;
    _pendingWardCode = widget.initialWardName;

    _loadProvinces();
  }

  int? _toInt(String? v) => int.tryParse(v ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _houseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await ApiService.getGhnProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingLocations = false;
      });
      await _applyPendingSelections();
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _applyPendingSelections() async {
    if (_pendingProvinceId == null || _provinces.isEmpty) return;

    final province = _provinces.firstWhere(
      (p) => p.provinceId == _pendingProvinceId,
      orElse: () => _provinces.first,
    );
    await _onProvinceChanged(province);

    if (_pendingDistrictId == null) return;

    while (_loadingLocations && _districts.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final district = _districts.firstWhere(
      (d) => d.districtId == _pendingDistrictId,
      orElse: () => _districts.first,
    );
    await _onDistrictChanged(district);

    if (_pendingWardCode == null) return;

    while (_loadingLocations && _wards.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final ward = _wards.firstWhere(
      (w) => w.wardCode == _pendingWardCode,
      orElse: () => _wards.first,
    );
    if (mounted) {
      setState(() => _selectedWard = ward);
    }
  }

  Future<void> _onProvinceChanged(GhnProvince? province, {bool skipReload = false}) async {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedWard = null;
      _districts = [];
      _wards = [];
      _loadingLocations = province != null && !skipReload;
    });
    if (province == null || skipReload) return;
    try {
      final districts = await ApiService.getGhnDistricts(province.provinceId);
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _loadingLocations = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _onDistrictChanged(GhnDistrict? district, {bool skipReload = false}) async {
    setState(() {
      _selectedDistrict = district;
      _selectedWard = null;
      _wards = [];
      _loadingLocations = district != null && !skipReload;
    });
    if (district == null || skipReload) return;
    try {
      final wards = await ApiService.getGhnWards(district.districtId);
      if (!mounted) return;
      setState(() {
        _wards = wards;
        _loadingLocations = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  String _buildFullAddress() {
    final parts = <String>[];
    if (_houseCtrl.text.trim().isNotEmpty) parts.add(_houseCtrl.text.trim());
    if (_selectedWard != null) parts.add(_selectedWard!.wardName);
    if (_selectedDistrict != null) parts.add(_selectedDistrict!.districtName);
    if (_selectedProvince != null) parts.add(_selectedProvince!.provinceName);
    return parts.isEmpty ? 'Chưa chọn địa chỉ' : parts.join(', ');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh/Thành phố')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final resp = await ApiService.updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _houseCtrl.text.trim(),
        provinceId: _selectedProvince?.provinceId,
        provinceName: _selectedProvince?.provinceName,
        districtId: _selectedDistrict?.districtId,
        districtName: _selectedDistrict?.districtName,
        wardCode: _selectedWard?.wardCode,
        wardName: _selectedWard?.wardName,
      );
      if (!mounted) return;
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thông tin thành công!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp.message),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3EAF5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chỉnh sửa thông tin cá nhân',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14213D),
                ),
              ),
              const SizedBox(height: 20),
              _field('Họ và tên', _nameCtrl, TextInputType.name),
              const SizedBox(height: 14),
              _field('Số điện thoại', _phoneCtrl, TextInputType.phone),
              const SizedBox(height: 14),
              _field('Số nhà, đường', _houseCtrl, TextInputType.text),
              const SizedBox(height: 14),
              _buildDropdown(
                label: 'Tỉnh / Thành phố',
                value: _selectedProvince,
                items: _provinces,
                itemLabel: (p) => p.provinceName,
                onChanged: (p) => _onProvinceChanged(p),
              ),
              const SizedBox(height: 14),
              _buildDropdown(
                label: 'Quận / Huyện',
                value: _selectedDistrict,
                items: _districts,
                itemLabel: (d) => d.districtName,
                onChanged: _selectedProvince == null
                    ? null
                    : (d) => _onDistrictChanged(d as GhnDistrict?),
                enabled: _selectedProvince != null,
              ),
              const SizedBox(height: 14),
              _buildDropdown(
                label: 'Phường / Xã',
                value: _selectedWard,
                items: _wards,
                itemLabel: (w) => w.wardName,
                onChanged: _selectedDistrict == null
                    ? null
                    : (w) => setState(() => _selectedWard = w as GhnWard?),
                enabled: _selectedDistrict != null,
              ),
              if (_selectedProvince != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Color(0xFF1F67E2)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Địa chỉ: ${_buildFullAddress()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7893),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1F67E2),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Lưu thay đổi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    TextInputType keyboard,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7893),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: 'Nhập $label',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1F67E2), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?>? onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7893),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? const Color(0xFFE3EAF5) : const Color(0xFFE3EAF5),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: items.contains(value) ? value : null,
              hint: Text(
                'Chọn $label',
                style: const TextStyle(color: Color(0xFF91A0B8)),
              ),
              isExpanded: true,
              items: items
                  .map((e) => DropdownMenuItem<T>(
                        value: e,
                        child: Text(
                          itemLabel(e),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sheet: Đổi mật khẩu ──────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu mới không khớp'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final resp = await ApiService.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp.message),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3EAF5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đổi mật khẩu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14213D),
                ),
              ),
              const SizedBox(height: 20),
              _passwordField('Mật khẩu hiện tại', _currentCtrl, _obscureCurrent,
                  () => setState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null),
              const SizedBox(height: 14),
              _passwordField('Mật khẩu mới', _newCtrl, _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                    return null;
                  }),
              const SizedBox(height: 14),
              _passwordField('Xác nhận mật khẩu mới', _confirmCtrl, _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu mới';
                    return null;
                  }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1F67E2),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Xác nhận đổi mật khẩu',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController ctrl,
    bool obscure,
    VoidCallback toggleObscure, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7893),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            hintText: label,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF91A0B8), size: 20),
              onPressed: toggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE3EAF5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1F67E2), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Card 2: Bảo hành ────────────────────────────────────────────────────────

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.claims, required this.isLoading});

  final List<WarrantyClaim> claims;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : claims.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    Row(
                      children: [
                        _summaryChip(
                          label: 'Tổng phiếu',
                          value: claims.length.toString(),
                          color: const Color(0xFF1F67E2),
                        ),
                        const SizedBox(width: 8),
                        _summaryChip(
                          label: 'Đang xử lý',
                          value: claims
                              .where((c) =>
                                  c.status?.toLowerCase() == 'processing' ||
                                  c.status?.toLowerCase() == 'pending')
                              .length
                              .toString(),
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        _summaryChip(
                          label: 'Hoàn thành',
                          value: claims
                              .where((c) => c.status?.toLowerCase() == 'completed')
                              .length
                              .toString(),
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...claims.take(3).map((claim) => _WarrantyClaimItem(claim: claim)),
                    if (claims.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+${claims.length - 3} phiếu khác',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF91A0B8),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _emptyState() {
    return const Row(
      children: [
        Icon(Icons.verified_user_outlined, size: 36, color: Color(0xFF91A0B8)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chưa có phiếu bảo hành',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14213D),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Bảo hành sẽ xuất hiện khi bạn mua sản phẩm.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7893)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(
      {required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _WarrantyClaimItem extends StatelessWidget {
  const _WarrantyClaimItem({required this.claim});

  final WarrantyClaim claim;

  Color get _statusColor {
    switch (claim.status?.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'processing':
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7893);
    }
  }

  String get _statusLabel {
    switch (claim.status?.toLowerCase()) {
      case 'completed':
        return 'Hoàn thành';
      case 'processing':
        return 'Đang xử lý';
      case 'pending':
        return 'Chờ duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return claim.status ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  claim.productName ?? claim.serialCode ?? 'Phiếu bảo hành',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF14213D),
                  ),
                ),
                if (claim.issueDescription != null &&
                    claim.issueDescription!.isNotEmpty)
                  Text(
                    claim.issueDescription!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7893),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card 3: Chi tiêu ───────────────────────────────────────────────────────

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.orders,
    required this.totalSpent,
    required this.totalOrders,
    required this.isLoading,
  });

  final List<OrderSummary> orders;
  final double totalSpent;
  final int totalOrders;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: isLoading
          ? const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : orders.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    Row(
                      children: [
                        _summaryChip(
                          label: 'Tổng chi tiêu',
                          value: formatCurrency(totalSpent),
                          color: const Color(0xFF1F67E2),
                        ),
                        const SizedBox(width: 8),
                        _summaryChip(
                          label: 'Tổng đơn',
                          value: totalOrders.toString(),
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        _summaryChip(
                          label: 'TB / đơn',
                          value: formatCurrency(
                              totalOrders > 0 ? totalSpent / totalOrders : 0),
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chi tiêu theo tháng',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14213D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: _SpendingChart(orders: orders),
                    ),
                  ],
                ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 40, color: Color(0xFF91A0B8)),
            SizedBox(height: 8),
            Text(
              'Chưa có dữ liệu chi tiêu',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF14213D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(
      {required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Biểu đồ cột chi tiêu ───────────────────────────────────────────────────

class _SpendingChart extends StatelessWidget {
  const _SpendingChart({required this.orders});

  final List<OrderSummary> orders;

  @override
  Widget build(BuildContext context) {
    final monthlyData = _buildMonthlyData();
    if (monthlyData.isEmpty) return const SizedBox();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxY(monthlyData),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF10284F),
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                formatCurrency(rod.toY.round()),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= monthlyData.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    monthlyData[idx].label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF91A0B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _maxY(monthlyData) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE3EAF5),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(monthlyData.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: monthlyData[i].amount,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F67E2), Color(0xFF10284F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: 22,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  List<_MonthlyBar> _buildMonthlyData() {
    final now = DateTime.now();
    final result = <_MonthlyBar>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final label = _monthLabel(month);
      double amount = 0;
      for (final order in orders) {
        if (order.createdOn == null) continue;
        final created = DateTime.tryParse(order.createdOn!);
        if (created != null &&
            created.year == month.year &&
            created.month == month.month &&
            (order.paymentStatus?.toLowerCase() == 'paid' ||
                order.paymentStatus?.toLowerCase() == 'completed')) {
          amount += order.totalPrice ?? 0;
        }
      }
      result.add(_MonthlyBar(label: label, amount: amount));
    }
    return result;
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'T1', 'T2', 'T3', 'T4', 'T5', 'T6',
      'T7', 'T8', 'T9', 'T10', 'T11', 'T12',
    ];
    return months[dt.month - 1];
  }

  double _maxY(List<_MonthlyBar> data) {
    final max = data.fold<double>(
        0, (prev, item) => item.amount > prev ? item.amount : prev);
    if (max == 0) return 100;
    return (max * 1.2).ceilToDouble();
  }
}

class _MonthlyBar {
  final String label;
  final double amount;
  _MonthlyBar({required this.label, required this.amount});
}

// ─── Shared menu tile ─────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1F67E2)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF91A0B8)),
        onTap: onTap,
      ),
    );
  }
}
