import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/order_repository.dart';
import '../../providers/orders_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String snapToken;
  final String orderNumber;
  final int orderId;
  final DateTime? paymentExpiresAt;
  final int paymentTimeoutMinutes;

  const CheckoutScreen({
    super.key,
    required this.snapToken,
    required this.orderNumber,
    required this.orderId,
    this.paymentExpiresAt,
    this.paymentTimeoutMinutes = 30,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _paymentPending = false; // true jika user sudah memilih metode bayar (onPending)

  // ── countdown ──
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _initCountdown();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.contains('finish') ||
                url.contains('success') ||
                url.contains('unfinish') ||
                url.contains('error') ||
                url.contains('evoria.life')) {
              _handlePaymentResult(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_buildSnapHtml());
  }

  void _initCountdown() {
    DateTime expiresAt;
    if (widget.paymentExpiresAt != null) {
      expiresAt = widget.paymentExpiresAt!;
    } else {
      expiresAt = DateTime.now().add(Duration(minutes: widget.paymentTimeoutMinutes));
    }

    final now = DateTime.now();
    _remaining = expiresAt.isAfter(now) ? expiresAt.difference(now) : Duration.zero;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final newRemaining = expiresAt.difference(DateTime.now());
      if (newRemaining.isNegative || newRemaining == Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
          _expired = true;
        });
        _countdownTimer?.cancel();
        _showExpiredDialog();
      } else {
        setState(() => _remaining = newRemaining);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Format sisa waktu → "29:45" atau "1:02:15"
  String _formatRemaining() {
    final total = _remaining.inSeconds;
    if (total <= 0) return '00:00';
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _countdownColor() {
    final mins = _remaining.inMinutes;
    if (mins <= 5) return AppColors.error;
    if (mins <= 10) return AppColors.warning;
    return AppColors.success;
  }

  void _showExpiredDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Waktu Pembayaran Habis'),
        content: const Text(
          'Batas waktu pembayaran telah habis. Order Anda akan dibatalkan otomatis.\n\n'
          'Silakan beli tiket lagi jika masih tersedia.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/orders');
            },
            child: const Text('Lihat Pesanan'),
          ),
        ],
      ),
    );
  }

  String _buildSnapHtml() {
    final snapJs = AppConstants.midtransSnapUrlSandbox;
    final clientKey = AppConstants.midtransClientKeySandbox;
    final token = widget.snapToken;

    return '''<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script type="text/javascript" src="$snapJs" data-client-key="$clientKey"></script>
  <style>
    body { margin: 0; padding: 0; background: #f5f5f5; }
    .loading { display: flex; justify-content: center; align-items: center; height: 100vh; }
  </style>
</head>
<body>
  <div class="loading" id="loading"><p>Memuat pembayaran...</p></div>
  <script>
    window.onload = function() {
      snap.pay('$token', {
        onSuccess: function(r){ window.location='https://evoria.life?status=success&order=${widget.orderNumber}'; },
        onPending: function(r){ window.location='https://evoria.life?status=pending&order=${widget.orderNumber}'; },
        onError: function(r){ window.location='https://evoria.life?status=error&order=${widget.orderNumber}'; },
        onClose: function(){ window.location='https://evoria.life?status=close&order=${widget.orderNumber}'; }
      });
    };
  </script>
</body>
</html>''';
  }

  Future<void> _handlePaymentResult(String url) async {
    _countdownTimer?.cancel();

    String message = 'Pembayaran diproses';
    bool success = false;

    if (url.contains('status=success')) {
      message = 'Pembayaran berhasil! Tiket kamu sudah tersedia.';
      success = true;
      // Sync final status
      try {
        await ref.read(orderRepositoryProvider).syncOrderStatus(widget.orderId);
        ref.invalidate(ordersProvider);
      } catch (_) {}
    } else if (url.contains('status=pending')) {
      // User memilih metode bayar (transfer dll) — order pending sah, jangan cancel.
      _paymentPending = true;
      message = 'Pembayaran sedang diproses. Cek status di halaman Tiket.';
      try {
        await ref.read(orderRepositoryProvider).syncOrderStatus(widget.orderId);
        ref.invalidate(ordersProvider);
      } catch (_) {}
    } else if (url.contains('status=error')) {
      // Pembayaran gagal → batalkan & kembalikan stok
      message = 'Pembayaran gagal. Silakan coba lagi.';
      await ref.read(orderRepositoryProvider).cancelOrder(widget.orderId);
      ref.invalidate(ordersProvider);
    } else if (url.contains('status=close')) {
      if (!_paymentPending) {
        // Tutup tanpa bayar → batalkan & kembalikan stok
        message = 'Pembayaran dibatalkan.';
        await ref.read(orderRepositoryProvider).cancelOrder(widget.orderId);
        ref.invalidate(ordersProvider);
      } else {
        message = 'Pembayaran sedang diproses.';
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : null,
      ),
    );
    context.go('/orders');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pembayaran', style: TextStyle(fontSize: 16)),
            // ── countdown row ──
            Row(
              children: [
                Icon(
                  _expired ? Icons.timer_off_rounded : Icons.timer_rounded,
                  size: 13,
                  color: _expired ? AppColors.error : _countdownColor(),
                ),
                const SizedBox(width: 4),
                Text(
                  _expired
                      ? 'Waktu habis'
                      : 'Bayar dalam ${_formatRemaining()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _expired ? AppColors.error : _countdownColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Batalkan Pembayaran?'),
                content: const Text(
                    'Order kamu akan tetap tersimpan dengan status pending.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Lanjutkan Bayar'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/orders');
                    },
                    child: const Text('Keluar',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _expired
              ? const SizedBox.shrink()
              : LinearProgressIndicator(
                  value: _remaining.inSeconds /
                      (widget.paymentTimeoutMinutes * 60),
                  backgroundColor: AppColors.primaryLight,
                  valueColor: AlwaysStoppedAnimation<Color>(_countdownColor()),
                  minHeight: 3,
                ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
