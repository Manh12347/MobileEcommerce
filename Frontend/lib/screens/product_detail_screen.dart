import 'package:flutter/material.dart';

import '../models/product_item.dart';
import '../services/api_service.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.summary,
    this.initialDetail,
  });

  final ProductItemSummary summary;
  final ProductItemDetail? initialDetail;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ProductItemDetail?> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<ProductItemDetail?> _loadDetail() async {
    if (widget.initialDetail != null) {
      return widget.initialDetail;
    }

    final id = widget.summary.id;
    if (id == null) {
      return null;
    }

    try {
      final response = await ApiService.getProductItemDetail(id);
      return response.success ? response.data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _loadDetail();
    });
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chi tiết sản phẩm',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF1F67E2),
        child: FutureBuilder<ProductItemDetail?>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1F67E2),
                ),
              );
            }

            final detail = snapshot.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _ProductHeroCard(
                  summary: widget.summary,
                  detail: detail,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Thông tin chính',
                  child: Column(
                    children: [
                      _InfoRow(label: 'SKU', value: detail?.sku ?? '-'),
                      _InfoRow(
                        label: 'Danh mục',
                        value: widget.summary.category?.name ?? '-',
                      ),
                      _InfoRow(
                        label: 'Thương hiệu',
                        value: widget.summary.brand?.name ?? '-',
                      ),
                      _InfoRow(
                        label: 'Trạng thái',
                        value: _statusLabel(
                          detail?.status ?? widget.summary.status,
                        ),
                      ),
                      _InfoRow(
                        label: 'Tồn kho',
                        value: detail?.stockQuantity != null
                            ? '${detail!.stockQuantity}'
                            : '-',
                      ),
                      _InfoRow(
                        label: 'Sản phẩm gốc',
                        value: detail?.productName ?? widget.summary.name,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Mô tả sản phẩm',
                  child: Text(
                    detail?.description?.isNotEmpty == true
                        ? detail!.description!
                        : 'Chưa có mô tả chi tiết cho sản phẩm này.',
                    style: const TextStyle(
                      color: Color(0xFF42506A),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Giá bán',
                  child: _PriceBlock(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Thông số kỹ thuật',
                  child: _SpecificationsGrid(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Serial',
                  child: _SerialList(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Dữ liệu hệ thống',
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Product item ID',
                        value: detail?.id?.toString() ?? '-',
                      ),
                      _InfoRow(
                        label: 'Created at',
                        value: _formatDate(detail?.createdAt),
                      ),
                      _InfoRow(
                        label: 'Updated at',
                        value: _formatDate(detail?.updatedAt),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductHeroCard extends StatelessWidget {
  const _ProductHeroCard({required this.summary, required this.detail});

  final ProductItemSummary summary;
  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final imageUrl = detail?.mainImageUrl;
    final price = detail?.salePrice ?? detail?.price;
    final originalPrice = detail?.hasSalePrice == true ? detail?.price : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10284F), Color(0xFF1F67E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F67E2).withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.category?.name ?? 'Sản phẩm',
                        style: const TextStyle(
                          color: Color(0xFFDCEBFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.brand?.name ?? '',
                        style: const TextStyle(
                          color: Color(0xFFDCEBFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 104,
                  width: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _HeroImage(url: imageUrl),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Badge(
                  text: _statusLabel(detail?.status ?? summary.status),
                  backgroundColor: const Color(0xFF0C8C71),
                ),
                const SizedBox(width: 10),
                if (detail?.stockQuantity != null)
                  _Badge(
                    text: 'Tồn kho: ${detail!.stockQuantity}',
                    backgroundColor: const Color(0xFF20365D),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (price != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(price),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (originalPrice != null) ...[
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _formatCurrency(originalPrice),
                        style: const TextStyle(
                          color: Color(0xFFBED3FF),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              const Text(
                'Giá đang cập nhật',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const Center(
        child: Icon(
          Icons.memory_rounded,
          size: 54,
          color: Colors.white,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.memory_rounded,
              size: 54,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF14213D),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7893),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17243D),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.detail});

  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    if (detail == null) {
      return const Text(
        'Chưa có dữ liệu giá chi tiết.',
        style: TextStyle(
          color: Color(0xFF42506A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final currentPrice = detail!.salePrice ?? detail!.price;
    final originalPrice = detail!.hasSalePrice ? detail!.price : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentPrice != null)
          Text(
            _formatCurrency(currentPrice),
            style: const TextStyle(
              color: Color(0xFF1F67E2),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        if (originalPrice != null) ...[
          const SizedBox(height: 4),
          Text(
            _formatCurrency(originalPrice),
            style: const TextStyle(
              color: Color(0xFF91A0B8),
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _InfoRow(
          label: 'Sale price',
          value: detail!.salePrice != null
              ? _formatCurrency(detail!.salePrice)
              : '-',
        ),
        _InfoRow(
          label: 'Price',
          value: detail!.price != null ? _formatCurrency(detail!.price) : '-',
        ),
      ],
    );
  }
}

class _SpecificationsGrid extends StatelessWidget {
  const _SpecificationsGrid({required this.detail});

  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final specs = detail?.specifications ?? const {};
    if (specs.isEmpty) {
      return const Text(
        'Chưa có thông số kỹ thuật.',
        style: TextStyle(
          color: Color(0xFF42506A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final entries = specs.entries.toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries
          .map(
            (entry) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Color(0xFF6B7893),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      color: Color(0xFF17243D),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SerialList extends StatelessWidget {
  const _SerialList({required this.detail});

  final ProductItemDetail? detail;

  @override
  Widget build(BuildContext context) {
    final serials = detail?.serials ?? const <ProductSerial>[];
    if (serials.isEmpty) {
      return const Text(
        'Chưa có serial nào được nhập.',
        style: TextStyle(
          color: Color(0xFF42506A),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Column(
      children: serials
          .map(
            (serial) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF1F67E2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serial.serialCode ?? '-',
                          style: const TextStyle(
                            color: Color(0xFF17243D),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serial.status ?? '-',
                          style: const TextStyle(
                            color: Color(0xFF6B7893),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.backgroundColor});

  final String text;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _statusLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'active':
      return 'Hoạt động';
    case 'disable':
      return 'Ngừng bán';
    case 'discontinued':
      return 'Ngưng bán';
    default:
      return status?.isNotEmpty == true ? status! : 'Không xác định';
  }
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return '-';
  }

  return '${dateTime.year.toString().padLeft(4, '0')}-'
      '${dateTime.month.toString().padLeft(2, '0')}-'
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

String _formatCurrency(num? value) {
  if (value == null) {
    return '0đ';
  }

  final rounded = value.round();
  final reversed = rounded.toString().split('').reversed.toList();
  final buffer = StringBuffer();

  for (var i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(reversed[i]);
  }

  return '${buffer.toString().split('').reversed.join()}đ';
}