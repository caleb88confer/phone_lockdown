import 'package:flutter/material.dart';
import '../customization/key_catalog.dart';
import '../customization/lock_catalog.dart';
import 'bobbing_sprite.dart';
import 'key_display.dart';
import 'lock_display.dart';

class BlockButton extends StatelessWidget {
  final bool isBlocking;
  final VoidCallback onTap;
  final LockStyle lockStyle;
  final LockColorOption lockColor;
  final KeyStyle? keyStyle;
  final KeyColorOption? keyColor;

  const BlockButton({
    super.key,
    required this.isBlocking,
    required this.onTap,
    required this.lockStyle,
    required this.lockColor,
    this.keyStyle,
    this.keyColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final spriteSize = screenHeight / 5;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isBlocking) ...[
            Text(
              'TAP TO LOCK',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: spriteSize,
              width: spriteSize,
              child: Center(
                child: LockDisplay(
                  style: lockStyle,
                  color: lockColor,
                  isBlocking: isBlocking,
                  size: spriteSize,
                ),
              ),
            ),
          ] else if (keyStyle != null && keyColor != null) ...[
            SizedBox(
              height: spriteSize,
              width: spriteSize,
              child: Center(
                child: BobbingSprite(
                  child: KeyDisplay(
                    style: keyStyle!,
                    color: keyColor!,
                    size: spriteSize,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TAP TO SCAN KEY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
