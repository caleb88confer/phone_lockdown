import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

class UnlockCodeSection extends StatelessWidget {
  final String? unlockCode;
  final VoidCallback onScan;
  final VoidCallback onClear;

  const UnlockCodeSection({
    super.key,
    required this.unlockCode,
    required this.onScan,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UNLOCK CODE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: Bevel.sunken(fill: AppColors.surfaceContainerLowest),
          child: Row(
            children: [
              Icon(
                unlockCode != null ? Icons.vpn_key : Icons.vpn_key_off,
                size: 20,
                color: unlockCode != null
                    ? const Color(0xFF2E7D32)
                    : AppColors.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unlockCode != null
                      ? '${unlockCode!.substring(0, unlockCode!.length.clamp(0, 12))}...'
                      : 'No code set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: unlockCode != null
                        ? AppColors.onSurface
                        : AppColors.outline,
                  ),
                ),
              ),
              if (unlockCode != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.outline),
                  onPressed: onClear,
                  tooltip: 'Clear code',
                ),
              Container(
                decoration: Bevel.raised(fill: AppColors.primaryContainer),
                child: IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    size: 20,
                    color: AppColors.onPrimaryContainer,
                  ),
                  onPressed: onScan,
                  tooltip: 'Scan code',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
