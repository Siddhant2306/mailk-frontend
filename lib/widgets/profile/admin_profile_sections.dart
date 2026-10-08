import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';

class ProfileHeading extends StatelessWidget {
  const ProfileHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MALIK ENTERPRISES',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
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
    return DecoratedBox(
      decoration: _cardDecoration(11),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF2B210C),
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accent,
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
                  const Text('SIGNED IN AS', style: _captionStyle),
                  const SizedBox(height: 3),
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
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
    return const Row(
      children: [
        Expanded(
          child: _CapabilityCard(
            icon: Icons.verified_user_outlined,
            label: 'Access',
            value: 'Approved',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _CapabilityCard(
            icon: Icons.edit_note_outlined,
            label: 'Entry mode',
            value: 'Single',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _CapabilityCard(
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
  Widget build(BuildContext context) => Text(value, style: _captionStyle);
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
    return SizedBox(
      height: 47,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
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
    final color = danger ? AppColors.negative : const Color(0xFFD1D7E0);
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: const BorderSide(color: AppColors.border),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF121A25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your account role is verified with the backend after sign-in. Converter actions include your Firebase access token.',
                style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2B210C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C5017)),
      ),
      child: Text(role.toUpperCase(), style: const TextStyle(
        color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w800,
      )),
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
    return DecoratedBox(
      decoration: _cardDecoration(9),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent, size: 16),
            const SizedBox(height: 13),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 9)),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.border),
);
