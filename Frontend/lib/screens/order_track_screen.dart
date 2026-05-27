import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/format_utils.dart';

class OrderTrackScreen extends StatefulWidget {
  const OrderTrackScreen({required this.orderCode, super.key});

  final String orderCode;

  @override
  State<OrderTrackScreen> createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  OrderTrack? _track;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final response = await ApiService.trackOrder(widget.orderCode);
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _track = response.data;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Theo dõi đơn hàng',
          style: TextStyle(
            color: Color(0xFF14213D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        color: const Color(0xFF1F67E2),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _track == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F67E2)),
      );
    }

    if (_error != null && _track == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(child: Text(_error!)),
        ],
      );
    }

    final track = _track;
    if (track == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10284F), Color(0xFF1F67E2)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.orderCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                orderStatusLabel(track.currentStatus),
                style: const TextStyle(
                  color: Color(0xFFBED3FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (track.statusMessage != null && track.statusMessage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    track.statusMessage!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tiến trình giao hàng',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF14213D),
          ),
        ),
        const SizedBox(height: 12),
        ...track.timeline.map((step) => _TimelineStep(step: step)),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Cập nhật tự động mỗi 15 giây',
            style: TextStyle(fontSize: 12, color: Color(0xFF91A0B8)),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.step});

  final OrderStatusStep step;

  @override
  Widget build(BuildContext context) {
    final isDone = step.completed;
    final isCurrent = step.current;
    final color = isCurrent
        ? const Color(0xFF1F67E2)
        : isDone
            ? const Color(0xFF10B981)
            : const Color(0xFFB8C4DA);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: isDone ? 16 : 10,
                  color: color,
                ),
              ),
              Container(
                width: 2,
                height: 36,
                color: const Color(0xFFE3EAF5),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label ?? orderStatusLabel(step.status),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isCurrent
                          ? const Color(0xFF1F67E2)
                          : const Color(0xFF14213D),
                    ),
                  ),
                  if (isCurrent)
                    const Text(
                      'Đang xử lý',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7893),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
