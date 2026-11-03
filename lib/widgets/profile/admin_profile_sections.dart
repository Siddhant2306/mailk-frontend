import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../models/app_user.dart';

class ProfileHeading extends StatelessWidget {
  const ProfileHeading({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MALIK ENTERPRISES',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Profile',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('profile-theme-toggle'),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: appThemeController.toggle,
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: _cardDecoration(11, palette),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: palette.accentSoft,
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIGNED IN AS',
                    style: _captionStyle.copyWith(color: palette.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _RolePill(role: user.role),
          ],
        ),
      ),
    );
  }
}

class AdminCapabilities extends StatelessWidget {
  const AdminCapabilities({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: const _CapabilityCard(
            icon: Icons.verified_user_outlined,
            label: 'Access',
            value: 'Approved',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: const _CapabilityCard(
            icon: Icons.edit_note_outlined,
            label: 'Entry mode',
            value: 'Single',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: const _CapabilityCard(
            icon: Icons.table_chart_outlined,
            label: 'Files',
            value: 'CSV / XLSX',
          ),
        ),
      ],
    );
  }
}

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: _captionStyle.copyWith(color: AppPalette.of(context).textMuted),
  );
}

class ProfilePrimaryAction extends StatelessWidget {
  const ProfilePrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 47,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class ProfileSecondaryAction extends StatelessWidget {
  const ProfileSecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = danger ? AppColors.negative : palette.textSecondary;
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class AdminSecurityCard extends StatelessWidget {
  const AdminSecurityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: palette.accent, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your account role is verified with the backend after sign-in. Converter actions include your Firebase access token.',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: palette.accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: _cardDecoration(9, palette),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: palette.accent, size: 16),
            const SizedBox(height: 13),
            Text(
              label,
              style: TextStyle(color: palette.textMuted, fontSize: 9),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _captionStyle = TextStyle(
  color: AppColors.muted,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: .8,
);

BoxDecoration _cardDecoration(double radius, AppPalette palette) => BoxDecoration(
  color: palette.surfaceElevated,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: palette.border),
);
