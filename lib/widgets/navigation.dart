import 'package:flutter/material.dart';
import '../core/theme/app_palette.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    const items = ['HOME', 'BRANDS', 'SEARCH', 'CATALOG', 'PROFILE'];
    final palette = AppPalette.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onItemTapped(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _iconForIndex(i),
                          size: 20,
                          color: i == selectedIndex
                              ? palette.accent
                              : palette.textMuted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i],
                          style: TextStyle(
                            color: i == selectedIndex
                                ? palette.accent
                                : palette.textMuted,
                            fontSize: 8,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForIndex(int index) {
    const icons = [
      Icons.home_outlined,
      Icons.business_outlined,
      Icons.search,
      Icons.grid_view_rounded,
      Icons.person_outline,
    ];
    return icons[index];
  }
}
