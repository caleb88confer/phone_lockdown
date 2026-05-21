import 'package:flutter/material.dart';
import '../../customization/key_catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';
import '../key_display.dart';
import 'carousel/key_style_carousel.dart';
import 'key_color_row.dart';

class SetKeySection extends StatelessWidget {
  final String? unlockCode;
  final VoidCallback onScan;
  final VoidCallback onClear;
  final String selectedStyleId;
  final String selectedColorId;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onColorChanged;

  const SetKeySection({
    super.key,
    required this.unlockCode,
    required this.onScan,
    required this.onClear,
    required this.selectedStyleId,
    required this.selectedColorId,
    required this.onStyleChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = keyStyleById(selectedStyleId);
    final color = keyColorForRender(style, selectedColorId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SET KEY',
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
              if (unlockCode != null)
                SizedBox(
                  height: 32,
                  width: 32,
                  child: Center(
                    child: KeyDisplay(style: style, color: color, size: 28),
                  ),
                )
              else
                Icon(Icons.vpn_key_off, size: 20, color: AppColors.outline),
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
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.outline,
                  ),
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
        const SizedBox(height: 16),
        KeyStyleCarousel(
          selectedStyleId: selectedStyleId,
          selectedColorId: selectedColorId,
          onStyleChanged: onStyleChanged,
        ),
        const SizedBox(height: 12),
        KeyColorRow(
          selectedStyleId: selectedStyleId,
          selectedColorId: selectedColorId,
          onColorChanged: onColorChanged,
        ),
      ],
    );
  }
}
