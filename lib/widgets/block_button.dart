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

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isBlocking ? 'Tap to unblock' : 'Tap to block',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: 8),
          Icon(
            isBlocking ? Icons.lock : Icons.lock_open,
            size: screenHeight / 5,
            color: isBlocking ? Colors.red.shade300 : Colors.green.shade300,
          ),
        ],
      ),
    );
  }
}
