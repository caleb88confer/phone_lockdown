import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../services/master_key_service.dart';

const String _kMasterKeyAssetPath = 'assets/sprites/keys/Master Key.png';

class MasterKeyDisplay extends StatelessWidget {
  final double size;

  /// When true, renders the sprite as a solid black silhouette (using the
  /// sprite's alpha mask). Used to show empty inventory slots.
  final bool silhouette;

  const MasterKeyDisplay({
    super.key,
    required this.size,
    this.silhouette = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _kMasterKeyAssetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
    if (!silhouette) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      child: image,
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
        return GestureDetector(
          onTap: mk.count > 0 ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(kMasterKeyMaxCount, (i) {
              // Fill slots right-to-left: with count=1, only the rightmost
              // slot is filled; consumption walks back left-to-right.
              final filled = i >= kMasterKeyMaxCount - mk.count;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: MasterKeyDisplay(
                  size: iconSize,
                  silhouette: !filled,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
