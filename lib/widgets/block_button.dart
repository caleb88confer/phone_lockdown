import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isBlocking ? 'TAP TO UNBLOCK' : 'TAP TO BLOCK',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            isBlocking ? Icons.lock : Icons.lock_open,
            size: screenHeight / 5,
            color: isBlocking
                ? AppColors.secondary
                : AppColors.primaryContainer,
          ),
        ],
      ),
    );
  }
}
