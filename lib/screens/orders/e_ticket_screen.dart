import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/evoria_app_bar.dart';

class ETicketScreen extends StatelessWidget {
  final String ticketCode;
  final String eventTitle;
  final String ticketName;
  final String status;

  const ETicketScreen({
    super.key,
    required this.ticketCode,
    required this.eventTitle,
    required this.ticketName,
    required this.status,
  });

  bool get _isValid => status == 'issued' || status == 'active';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: EvoriaAppBar(title: 'E-Ticket'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTicketCard(context),
            const SizedBox(height: 20),
            _buildNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isValid ? AppColors.primary : AppColors.textSecondary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', height: 36),
                const SizedBox(height: 12),
                Text(
                  eventTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  ticketName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Tear line
          _buildTearLine(),
          // QR Code
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                if (_isValid) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: ticketCode,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.darkFooter,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.darkFooter,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.cancel_outlined,
                            size: 60, color: AppColors.error),
                        SizedBox(height: 8),
                        Text(
                          'Tiket Tidak Valid',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: ticketCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kode tiket disalin')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ticketCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isValid
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isValid ? 'Tiket Valid — Tunjukkan ke petugas' : 'Tiket ${status.toUpperCase()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isValid ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTearLine() {
    return Row(
      children: [
        const _HalfCircle(left: true),
        Expanded(
          child: LayoutBuilder(
            builder: (_, c) => Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                (c.maxWidth / 10).floor(),
                (_) => const SizedBox(
                  width: 6,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ),
        ),
        const _HalfCircle(left: false),
      ],
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tunjukkan QR code ini kepada petugas saat masuk venue. Satu kode hanya bisa digunakan satu kali.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfCircle extends StatelessWidget {
  final bool left;
  const _HalfCircle({required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRect(
        child: Align(
          alignment: left ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: 0.5,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
