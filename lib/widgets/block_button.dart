import 'package:flutter/material.dart';

class BlockButton extends StatelessWidget {
  final bool isBlocking;
  final VoidCallback onTap;

  const BlockButton({
    super.key,
    required this.isBlocking,
    required this.onTap,
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
            child: Image.asset(
              'assets/sprites/padlock_bronze.png',
              filterQuality: FilterQuality.none,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
