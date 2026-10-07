import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.accent,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF758090), fontSize: 12),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF798494),
            size: 18,
          ),
          filled: true,
          fillColor: const Color(0xFF10111B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF272B3A)),
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
