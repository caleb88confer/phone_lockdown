import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/master_key_service.dart';

const String _kMasterKeyAssetPath = 'assets/sprites/keys/Master Key.png';

class MasterKeyDisplay extends StatelessWidget {
  final double size;

  const MasterKeyDisplay({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _kMasterKeyAssetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
  }
}

class MasterKeyInventory extends StatelessWidget {
  final VoidCallback onTap;
  final double iconSize;

  const MasterKeyInventory({
    super.key,
    required this.onTap,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MasterKeyService>(
      builder: (ctx, mk, _) {
        if (mk.count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              mk.count,
              (_) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: MasterKeyDisplay(size: iconSize),
              ),
            ),
          ),
        );
      },
    );
  }
}
