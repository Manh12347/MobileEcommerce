import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../models/chat_message.dart';
import '../models/product_item.dart';
import '../providers/chat_session_provider.dart';
import '../screens/product_detail_screen.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';
import '../utils/app_globals.dart';

class ChatBubbleButton extends StatefulWidget {
  const ChatBubbleButton({super.key});

  @override
  State<ChatBubbleButton> createState() => _ChatBubbleButtonState();
}

class _ChatBubbleButtonState extends State<ChatBubbleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _AnimatedBubble();
  }
}

class _AnimatedBubble extends StatefulWidget {
  const _AnimatedBubble();

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F67E2), Color(0xFF10284F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F67E2).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => _showChatWindow(context),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  void _showChatWindow(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => const ChatWindowOverlay(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// ─── Chat Window Overlay ───────────────────────────────────────────────────────

class ChatWindowOverlay extends StatefulWidget {
  const ChatWindowOverlay({super.key});

  @override
  State<ChatWindowOverlay> createState() => _ChatWindowOverlayState();
}

class _ChatWindowOverlayState extends State<ChatWindowOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final ValueNotifier<int> _sessionVersion = ValueNotifier(0);

  @override
  void initState() {
    super.initState();

    // Init session from provider (persisted across app restarts)
    final provider = context.read<ChatSessionProvider>();
    provider.init();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _sessionVersion.dispose();
    _slideController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final provider = context.read<ChatSessionProvider>();

    _textController.clear();
    provider.addUserMessage(text);
    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      final resp = await ApiService.sendChat(
        text: text,
        sessionId: provider.sessionId,
        activeScreen: ChatbotContext.activeScreen,
        activeProductId: ChatbotContext.activeProductId,
        activeProductDetails: ChatbotContext.activeProductDetails,
      );
      if (!mounted) return;
      provider.addAssistantMessage(ChatMessageVM(
        role: 'assistant',
        text: resp.answer,
        products: resp.retrievedProducts,
        decisionAction: resp.decisionAction,
      ));
      provider.updateSessionId(resp.sessionId);
      setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      provider.addAssistantMessage(ChatMessageVM(
        role: 'assistant',
        text: 'Xin lỗi bạn, đã có lỗi xảy ra. Bạn thử lại nhé!',
      ));
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionProvider>();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _dismiss(),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: 90,
            right: 16,
            child: SlideTransition(
              position: _slideAnim,
              child: _ChatWindow(
                messages: provider.messages,
                isLoading: _isLoading,
                textController: _textController,
                scrollController: _scrollController,
                onSend: _sendMessage,
                onClose: () => _dismiss(),
                onClear: () {
                  provider.resetSession();
                  _sessionVersion.value++;
                },
                sessionVersion: _sessionVersion,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }
}

// ─── Chat Window ───────────────────────────────────────────────────────────────

class _ChatWindow extends StatelessWidget {
  const _ChatWindow({
    required this.messages,
    required this.isLoading,
    required this.textController,
    required this.scrollController,
    required this.onSend,
    required this.onClose,
    required this.onClear,
    required this.sessionVersion,
  });

  final List<ChatMessageVM> messages;
  final bool isLoading;
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final ValueNotifier<int> sessionVersion;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenW > 480 ? 380 : screenW - 32,
          height: math.min(520, maxH),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
            child: Column(
            children: [
              _ChatHeader(
                onClose: onClose,
                onClear: onClear,
                sessionVersion: sessionVersion,
              ),
              Expanded(child: _MessageList(
                messages: messages,
                isLoading: isLoading,
                scrollController: scrollController,
              )),
              _ChatInputBar(
                controller: textController,
                isLoading: isLoading,
                onSend: onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatefulWidget {
  const _ChatHeader({
    required this.onClose,
    required this.onClear,
    required this.sessionVersion,
  });

  final VoidCallback onClose;
  final VoidCallback onClear;
  final ValueNotifier<int> sessionVersion;

  @override
  State<_ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<_ChatHeader> {
  Timer? _countdownTimer;
  int _remainingSeconds = 30 * 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    widget.sessionVersion.addListener(_onSessionVersionChanged);
  }

  void _onSessionVersionChanged() {
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() => _remainingSeconds = 30 * 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.sessionVersion.removeListener(_onSessionVersionChanged);
    super.dispose();
  }

  String get _timeLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12 + MediaQuery.of(context).padding.top,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F67E2), Color(0xFF10284F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trợ lý TechShop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white54, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      _timeLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClear,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            iconSize: 20,
            tooltip: 'Xóa tin nhắn & reset 30p',
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  final List<ChatMessageVM> messages;
  final bool isLoading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F8FC),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: messages.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return const _TypingIndicator();
          }
          final msg = messages[index];
          return msg.isUser
              ? _UserBubble(text: msg.text)
              : _AssistantBubble(
                  text: msg.text, 
                  products: msg.products,
                  decisionAction: msg.decisionAction,
                );
        },
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.62,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F67E2), Color(0xFF10284F)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.text,
    this.products,
    this.decisionAction,
  });

  final String text;
  final List<RetrievedProduct>? products;
  final String? decisionAction;

  String _normalizeBuildCategory(String value) {
    const marks = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const replacements = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var text = value.toLowerCase();
    for (var i = 0; i < marks.length; i++) {
      text = text.replaceAll(marks[i], replacements[i]);
    }
    return text.trim();
  }

  String _resolveCategory(RetrievedProduct p) {
    final cat = p.categoryName?.trim().toLowerCase() ?? '';
    if (cat.contains('mainboard') || cat.contains('bo mach chu') || cat.contains('motherboard')) return 'mainboard';
    if (cat.contains('cpu') || cat.contains('vi xu ly') || cat.contains('processor')) return 'cpu';
    if (cat.contains('ram') || cat.contains('bo nho trong') || cat.contains('memory')) return 'ram';
    if (cat.contains('gpu') || cat.contains('vga') || cat.contains('card man hinh') || cat.contains('card do hoa')) return 'gpu';
    if (cat.contains('psu') || cat.contains('nguon')) return 'psu';
    if (cat.contains('case') || cat.contains('vo may') || cat.contains('thung may')) return 'case';
    if (cat.contains('tan nhiet') || cat.contains('cooler') || cat.contains('quat')) return 'tan nhiet';
    if (cat.contains('ssd') || cat.contains('hdd') || cat.contains('o cung') || cat.contains('storage')) return 'ssd/hdd';

    // Fallback to name-based classification
    final name = p.productName.toLowerCase();
    if (name.contains('mainboard') || name.contains('h610') || name.contains('b760') || name.contains('z790')) return 'mainboard';
    if (name.contains('cpu') || name.contains('intel core') || name.contains('ryzen')) return 'cpu';
    if (name.contains('ram') || name.contains('ddr4') || name.contains('ddr5')) return 'ram';
    if (name.contains('rtx') || name.contains('gtx') || name.contains('radeon') || name.contains('vga') || name.contains('geforce')) return 'gpu';
    if (name.contains('psu') || name.contains('nguon') || name.contains('msi mag a650bn') || name.contains('corsair rm850e')) return 'psu';
    if (name.contains('case') || name.contains('vo may') || name.contains('thung may')) return 'case';
    if (name.contains('tan nhiet') || name.contains('cooler') || name.contains('thermalright') || name.contains('kraken')) return 'tan nhiet';
    if (name.contains('ssd') || name.contains('hdd') || name.contains('samsung 990') || name.contains('kingston nv2') || name.contains('seagate')) return 'ssd/hdd';

    return 'unknown';
  }

  Future<void> _applyBuild(BuildContext context, List<RetrievedProduct> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final existingJson = prefs.getString('build_selected_new_products');
      final data = <String, dynamic>{};
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(existingJson);
          if (decoded is Map<String, dynamic>) {
            data.addAll(decoded);
          }
        } catch (_) {}
      }

      int appliedCount = 0;
      int skippedCount = 0;

      for (final p in products) {
        if (p.productItemId == null || p.productItemId == 0) {
          skippedCount++;
          continue;
        }

        final categoryKey = _resolveCategory(p);
        if (categoryKey == 'unknown') continue;

        // Fetch full product details from API
        try {
          final resp = await ApiService.getProductItemDetail(p.productItemId!);
          if (resp.success && resp.data != null) {
            final detail = resp.data!;
            data[categoryKey] = {
              'productItemId': detail.productItemId,
              'productId': detail.productId,
              'sku': detail.sku ?? p.sku ?? 'SKU-${detail.productItemId}',
              'description': detail.description ?? p.description ?? '',
              'stockQuantity': detail.stockQuantity ?? p.stock,
              'soldQuantity': 0,
              'status': detail.status ?? 'active',
              'price': detail.price ?? p.price,
              'salePrice': detail.salePrice ?? p.salePrice,
              'mainImageUrl': detail.mainImageUrl ?? p.mainImageUrl ?? '',
              'productName': detail.productName ?? p.productName,
              'categoryName': detail.categoryName ?? p.categoryName ?? categoryKey.toUpperCase(),
            };
            appliedCount++;
          } else {
            // Fallback: store with chatbot data if API fails
            data[categoryKey] = {
              'productItemId': p.productItemId,
              'productId': p.productItemId,
              'sku': p.sku ?? 'SKU-${p.productItemId}',
              'description': p.description ?? '',
              'stockQuantity': p.stock,
              'soldQuantity': 0,
              'status': 'active',
              'price': p.price,
              'salePrice': p.salePrice,
              'mainImageUrl': p.mainImageUrl ?? '',
              'productName': p.productName,
              'categoryName': p.categoryName ?? categoryKey.toUpperCase(),
            };
            appliedCount++;
          }
        } catch (_) {
          // Fallback: store with chatbot data if request fails
          data[categoryKey] = {
            'productItemId': p.productItemId,
            'productId': p.productItemId,
            'sku': p.sku ?? 'SKU-${p.productItemId}',
            'description': p.description ?? '',
            'stockQuantity': p.stock,
            'soldQuantity': 0,
            'status': 'active',
            'price': p.price,
            'salePrice': p.salePrice,
            'mainImageUrl': p.mainImageUrl ?? '',
            'productName': p.productName,
            'categoryName': p.categoryName ?? categoryKey.toUpperCase(),
          };
          appliedCount++;
        }
      }

      await prefs.setString('build_selected_new_products', jsonEncode(data));

      if (!context.mounted) return;

      String message = 'Đã áp dụng cấu hình ($appliedCount linh kiện) thành công!';
      if (skippedCount > 0) {
        message += ' ($skippedCount sản phẩm không xác định được ID, đã bỏ qua.)';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi áp dụng cấu hình: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBuildRecommendation = decisionAction == 'pc_build' && products != null && products!.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFE3EAF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    size: 14,
                    color: Color(0xFF1F67E2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF14213D),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (isBuildRecommendation) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _applyBuild(context, products!),
                  icon: const Icon(Icons.build_circle_outlined, size: 18),
                  label: const Text(
                    'Áp dụng cấu hình vào Trình dựng PC',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F67E2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (products != null && products!.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE3EAF5)),
              const SizedBox(height: 8),
              Text(
                isBuildRecommendation ? 'Linh kiện được đề xuất:' : 'Sản phẩm gợi ý:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              ...products!.map((p) => _ProductChip(product: p)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.product});

  final RetrievedProduct product;

  @override
  Widget build(BuildContext context) {
    final price = product.salePrice ?? product.price;
    final hasDiscount = product.salePrice != null;
    final discountPct = hasDiscount && product.price > 0
        ? (((product.price - price) / product.price) * 100).round()
        : 0;
    final hasStock = product.stock > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ProductDetailFromChat(productItemId: product.productItemId),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3EAF5)),
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 22,
                  color: Color(0xFF1F67E2),
                ),
              ),
              const SizedBox(width: 10),
              // Info: name + price row + stock
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14213D),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Price + discount + original stacked, then stock badge
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child: Text(
                            formatCurrency(price),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD28A00),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasDiscount) ...[
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              formatCurrency(product.price),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF91A0B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD28A00),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-$discountPct%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Stock badge (always below price, not to the right)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: hasStock
                                ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                : const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hasStock ? 'Còn hàng' : 'Hết hàng',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: hasStock ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Arrow
              const Icon(Icons.chevron_right, color: Color(0xFF91A0B8), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Navigate to Product Detail from Chat ─────────────────────────────────────

class _ProductDetailFromChat extends StatelessWidget {
  const _ProductDetailFromChat({required this.productItemId});

  final int productItemId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProductDetailData>(
      future: _loadProductDetail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
            body: const Center(child: Text('Không tải được sản phẩm')),
          );
        }
        // Import and show product detail screen
        return _buildProductDetailScreen(context, snapshot.data!);
      },
    );
  }

  Future<_ProductDetailData> _loadProductDetail() async {
    final resp = await ApiService.getProductItemDetail(productItemId);
    if (!resp.success || resp.data == null) {
      throw Exception('Không tìm thấy sản phẩm');
    }
    return _ProductDetailData(
      productItem: resp.data!,
      summary: ProductItemSummary(
        productItemId: resp.data!.productItemId,
        productId: resp.data!.productId,
        sku: resp.data!.sku,
        description: resp.data!.description,
        stockQuantity: resp.data!.stockQuantity,
        soldQuantity: 0,
        status: resp.data!.status,
        price: resp.data!.price,
        salePrice: resp.data!.salePrice,
        mainImageUrl: resp.data!.mainImageUrl,
        productName: resp.data!.productName,
        category: ProductCategory(name: resp.data!.categoryName ?? ''),
      ),
    );
  }

  Widget _buildProductDetailScreen(BuildContext context, _ProductDetailData data) {
    return ProductDetailScreen(
      summary: data.summary,
      initialDetail: data.productItem,
    );
  }
}

class _ProductDetailData {
  final ProductItemDetail productItem;
  final ProductItemSummary summary;
  _ProductDetailData({required this.productItem, required this.summary});
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFE3EAF5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE3EAF5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Nhắn tin cho TechShop...',
                  hintStyle: const TextStyle(color: Color(0xFF91A0B8), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF4F8FC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1F67E2), Color(0xFF10284F)],
              ),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                  ),
          ),
        ],
      ),
    );
  }
}

