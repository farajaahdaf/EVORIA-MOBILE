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

  const CheckoutScreen({
    super.key,
    required this.snapToken,
    required this.orderNumber,
    required this.orderId,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    String message = 'Pembayaran diproses';
    bool success = false;

    if (url.contains('status=success')) {
      message = 'Pembayaran berhasil! Tiket kamu sudah tersedia.';
      success = true;
    } else if (url.contains('status=pending')) {
      message = 'Pembayaran sedang diproses. Cek status di halaman Tiket.';
    } else if (url.contains('status=error')) {
      message = 'Pembayaran gagal. Silakan coba lagi.';
    } else if (url.contains('status=close')) {
      message = 'Pembayaran dibatalkan.';
    }

    // Sync order status
    try {
      await ref.read(orderRepositoryProvider).syncOrderStatus(widget.orderId);
      ref.invalidate(ordersProvider);
    } catch (_) {}

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
        title: const Text('Pembayaran'),
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
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
