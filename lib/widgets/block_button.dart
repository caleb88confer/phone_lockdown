import 'package:flutter/material.dart';
import '../customization/lock_catalog.dart';
import 'lock_display.dart';

class BlockButton extends StatelessWidget {
  final bool isBlocking;
  final VoidCallback onTap;
  final LockStyle lockStyle;
  final LockColorOption lockColor;

  const BlockButton({
    super.key,
    required this.isBlocking,
    required this.onTap,
    required this.lockStyle,
    required this.lockColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final spriteSize = screenHeight / 5;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isBlocking ? 'TAP TO UNLOCK' : 'TAP TO LOCK',
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
        ],
      ),
    );
  }
}
