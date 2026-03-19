import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../theme/app_colors.dart';

class ProfileCell extends StatelessWidget {
  final Profile profile;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ProfileCell({
    super.key,
    required this.profile,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 90,
        height: 90,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.selectedProfile
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.selectedProfileBorder : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconData(profile.iconCodePoint, fontFamily: 'MaterialIcons'),
              size: 30,
              color: Colors.white,
            ),
            const Divider(height: 8, thickness: 0.5),
            Text(
              profile.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Apps: ${profile.blockedAppPackages.length}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 30, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(height: 4),
            Text(
              'New...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
