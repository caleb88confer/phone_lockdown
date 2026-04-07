import 'package:flutter/material.dart';

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
        Text('Unlock Code', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(
                unlockCode != null ? Icons.vpn_key : Icons.vpn_key_off,
                size: 20,
                color: unlockCode != null ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unlockCode != null
                      ? '${unlockCode!.substring(0, unlockCode!.length.clamp(0, 12))}...'
                      : 'No code set',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: unlockCode != null ? Colors.white : Colors.grey,
                  ),
                ),
              ),
              if (unlockCode != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                  tooltip: 'Clear code',
                ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                onPressed: onScan,
                tooltip: 'Scan code',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
