import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/explosion_settings.dart';
import '../theme/app_colors.dart';

/// Live tuner for the lock-landing pixel burst. Reached from the gear button on
/// the lock transition while "Explosion animation setup" is on. Every change is
/// persisted immediately; exit to replay the burst with the new values.
class ExplosionSettingsScreen extends StatelessWidget {
  const ExplosionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EXPLOSION',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
      ),
      body: Consumer<ExplosionSettings>(
        builder: (context, s, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Slider(
                label: 'Density',
                valueLabel: '${s.count} shards',
                value: s.count.toDouble(),
                min: 2,
                max: 60,
                divisions: 58,
                onChanged: (v) => s.count = v.round(),
              ),
              _Slider(
                label: 'Shard size',
                valueLabel: '${s.sizeScale.toStringAsFixed(2)}×',
                value: s.sizeScale,
                min: 0.3,
                max: 3.0,
                divisions: 27,
                onChanged: (v) => s.sizeScale = v,
              ),
              _Slider(
                label: 'Size randomizer',
                valueLabel: s.sizeRandomizer == 0
                    ? 'uniform'
                    : '±${(s.sizeRandomizer * 100).round()}%',
                value: s.sizeRandomizer,
                min: 0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) => s.sizeRandomizer = v,
              ),
              _Slider(
                label: 'Explosion speed',
                valueLabel: '${s.explosionSpeed.toStringAsFixed(2)}×',
                value: s.explosionSpeed,
                min: 0.3,
                max: 3.0,
                divisions: 27,
                onChanged: (v) => s.explosionSpeed = v,
              ),
              _Slider(
                label: 'Speed randomizer',
                valueLabel: s.speedRandomizer == 0
                    ? 'uniform'
                    : '±${(s.speedRandomizer * 100).round()}%',
                value: s.speedRandomizer,
                min: 0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) => s.speedRandomizer = v,
              ),
              _Slider(
                label: 'Spin rate',
                valueLabel: '${s.spinTurns.toStringAsFixed(2)} turns',
                value: s.spinTurns,
                min: 0,
                max: 6,
                divisions: 24,
                onChanged: (v) => s.spinTurns = v,
              ),
              _Slider(
                label: 'Spin randomizer',
                valueLabel: s.spinRandomizer == 0
                    ? 'uniform'
                    : '±${(s.spinRandomizer * 100).round()}%',
                value: s.spinRandomizer,
                min: 0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) => s.spinRandomizer = v,
              ),
              _Slider(
                label: 'Duration',
                valueLabel: '${s.durationMs} ms',
                value: s.durationMs.toDouble(),
                min: 150,
                max: 2000,
                divisions: 37,
                onChanged: (v) => s.durationMs = v.round(),
              ),
              const SizedBox(height: 16),
              Text(
                'Colors',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Shards pick at random from the selected colours.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < kExplosionPalette.length; i++)
                    _Swatch(
                      option: kExplosionPalette[i],
                      selected: s.colorIndices.contains(i),
                      onTap: () => s.toggleColor(i),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reset to defaults'),
                onPressed: s.resetToDefaults,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _Slider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(valueLabel, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final ExplosionColorOption option;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checkColor = option.color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: option.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? AppColors.primaryContainer
                    : AppColors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 22, color: checkColor)
                : null,
          ),
          const SizedBox(height: 4),
          Text(option.label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
