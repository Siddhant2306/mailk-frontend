import 'package:flutter/material.dart';

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

    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF090D13),
        border: Border(top: BorderSide(color: Color(0xFF202832), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onItemTapped(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconForIndex(i),
                        size: 20,
                        color: i == selectedIndex
                            ? const Color(0xFFFFB21A)
                            : const Color(0xFF737C88),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        items[i],
                        style: TextStyle(
                          color: i == selectedIndex
                              ? const Color(0xFFFFB21A)
                              : const Color(0xFF737C88),
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
