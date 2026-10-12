import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

/// The shared catalogue search input used by the brand and global search tabs.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.accent,
        style: TextStyle(color: palette.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: palette.textMuted, fontSize: 12),
          prefixIcon: Icon(
            Icons.search,
            color: palette.textMuted,
            size: 18,
          ),
          filled: true,
          fillColor: palette.input,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}
