import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../customization/key_catalog.dart';
import '../customization/lock_catalog.dart';
import '../customization/unlock_order.dart';
import '../services/unlock_state_service.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import '../widgets/bobbing_sprite.dart';
import '../widgets/key_display.dart';
import '../widgets/lock_picker_sprite.dart';

/// Reveal screen shown when a lockdown ends with one or more unlocks queued
/// (chunk 8 of the unlockables architecture). One swipeable card per pending
/// claim; the final card carries the CLAIM ALL button that drains the queue
/// into ownedItemIds.
class UnlockRevealScreen extends StatefulWidget {
  const UnlockRevealScreen({super.key});

  @override
  State<UnlockRevealScreen> createState() => _UnlockRevealScreenState();
}

class _UnlockRevealScreenState extends State<UnlockRevealScreen> {
  late final PageController _controller;
  late final List<String> _claims;
  int _page = 0;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    // Snapshot the queue once on entry so the reveal stays stable even if
    // the underlying service changes mid-screen.
    _claims = context.read<UnlockStateService>().pendingClaimIds.toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claimAndPop() async {
    if (_claimed) return;
    _claimed = true;
    final svc = context.read<UnlockStateService>();
    await svc.drainPendingClaims();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final count = _claims.length;
    final isLast = _page == count - 1;

    return PopScope(
      // Intercept back so the queue is always drained — the user can't bail
      // out of the reveal with claims still pending.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _claimAndPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.nonBlockingBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Column(
                  children: [
                    Text(
                      'YOU HAVE UNLOCKED',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.surfaceContainerLowest.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 1 ? '1 ITEM' : '$count ITEMS',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.surfaceContainerLowest,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _RevealCard(id: _claims[i]),
                ),
              ),
              _PageDots(count: count, current: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isLast ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !isLast,
                      child: Container(
                        decoration: Bevel.raised(fill: AppColors.primaryContainer),
                        child: TextButton(
                          onPressed: _claimAndPop,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.onPrimaryContainer,
                          ),
                          child: const Text(
                            'CLAIM ALL',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  final String id;
  const _RevealCard({required this.id});

  UnlockType _typeOf(String id) {
    if (id.startsWith('kc_')) return UnlockType.keyColor;
    if (id.startsWith('lc_')) return UnlockType.lockColor;
    if (id.startsWith('key_')) return UnlockType.key;
    return UnlockType.lock;
  }

  String _labelOf(String id, UnlockType type) {
    switch (type) {
      case UnlockType.key:
        return keyStyleById(id).displayName;
      case UnlockType.lock:
        return lockStyleById(id).displayName;
      case UnlockType.keyColor:
        final raw = id.substring(3);
        for (final style in kKeyCatalog) {
          for (final c in style.colors) {
            if (c.id == raw) return '${c.displayName} keys';
          }
        }
        return raw;
      case UnlockType.lockColor:
        final raw = id.substring(3);
        for (final style in kLockCatalog) {
          for (final c in style.colors) {
            if (c.id == raw) return '${c.displayName} locks';
          }
        }
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _typeOf(id);
    final label = _labelOf(id, type);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(child: _RevealVisual(id: id, type: type)),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.surfaceContainerLowest,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealVisual extends StatelessWidget {
  final String id;
  final UnlockType type;
  const _RevealVisual({required this.id, required this.type});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case UnlockType.key:
        final style = keyStyleById(id);
        final color = keyColorForRender(style, kDefaultKeyColorId);
        return BobbingSprite(
          amplitude: 6,
          child: KeyDisplay(style: style, color: color, size: 160),
        );
      case UnlockType.lock:
        final style = lockStyleById(id);
        final color = lockColorById(style, kDefaultLockColorId);
        return LockPickerSprite(
          style: style,
          color: color,
          size: 180,
          playing: true,
        );
      case UnlockType.keyColor:
        return _ColorSamplesRow.keys(rawColorId: id.substring(3));
      case UnlockType.lockColor:
        return _ColorSamplesRow.locks(rawColorId: id.substring(3));
    }
  }
}

/// Three sample items rendered in the freshly-unlocked colour, no animation.
class _ColorSamplesRow extends StatelessWidget {
  final List<Widget> samples;
  const _ColorSamplesRow._(this.samples);

  factory _ColorSamplesRow.keys({required String rawColorId}) {
    final styles = kKeyCatalog
        .where((s) => s.colors.any((c) => c.id == rawColorId))
        .take(3)
        .toList();
    return _ColorSamplesRow._(
      styles
          .map(
            (s) => KeyDisplay(
              style: s,
              color: keyColorById(s, rawColorId),
              size: 90,
              staticFrame: 0,
            ),
          )
          .toList(),
    );
  }

  factory _ColorSamplesRow.locks({required String rawColorId}) {
    final styles = kLockCatalog
        .where((s) => s.colors.any((c) => c.id == rawColorId))
        .take(3)
        .toList();
    return _ColorSamplesRow._(
      styles
          .map(
            (s) => LockPickerSprite(
              style: s,
              color: lockColorById(s, rawColorId),
              size: 90,
              playing: false,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: samples,
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 12);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.surfaceContainerLowest
                : AppColors.surfaceContainerLowest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
