import 'package:flutter/material.dart';
import '../customization/lock_catalog.dart';
import '../models/profile.dart';
import '../theme/app_colors.dart';
import '../theme/bevel.dart';
import 'sprite_sheet.dart';

class ProfileCell extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;

  const ProfileCell({
    super.key,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lockStyle = lockStyleById(profile.lockStyleId);
    final lockColor = lockColorById(lockStyle, profile.lockColorId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: Bevel.raised(fill: AppColors.surfaceContainerHigh),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpriteFrame(
                assetPath: lockStyle.spritesheetPath(lockColor.id),
                frameWidth: lockStyle.frameWidth,
                frameHeight: lockStyle.frameHeight,
                frameIndex: lockStyle.lockedFrame,
                size: 36,
              ),
              const SizedBox(height: 4),
              Text(
                profile.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Apps: ${profile.blockedAppPackages.length}',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.outline,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewProfileCell extends StatelessWidget {
  final VoidCallback onTap;

  const NewProfileCell({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: Bevel.ghost(
          fill: AppColors.surfaceContainerLow,
          opacity: 0.3,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 28,
              color: AppColors.outline,
            ),
            const SizedBox(height: 4),
            Text(
              'NEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.outline,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
