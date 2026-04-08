import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_manager.dart';
import '../theme/app_colors.dart';
import 'profile_cell.dart';
import 'profile_form/profile_form_dialog.dart';

class ProfilePicker extends StatelessWidget {
  const ProfilePicker({super.key});

  void _openProfileForm(BuildContext context, {profile}) {
    final profileManager = context.read<ProfileManager>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileFormDialog(
          profile: profile,
          profileManager: profileManager,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileManager>(
      builder: (context, profileManager, _) {
        return Container(
          color: AppColors.surfaceContainerLow,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'PROFILES',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 100,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: profileManager.profiles.length + 1,
                    itemBuilder: (context, index) {
                      if (index < profileManager.profiles.length) {
                        final profile = profileManager.profiles[index];
                        return ProfileCell(
                          profile: profile,
                          onTap: () =>
                              _openProfileForm(context, profile: profile),
                        );
                      }
                      return NewProfileCell(
                        onTap: () => _openProfileForm(context),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
