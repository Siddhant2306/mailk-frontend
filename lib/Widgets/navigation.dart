import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('assets/HOME.png', 'HOME'),
      ('assets/BRANDS.png', 'BRANDS'),
      ('assets/SEARCH.png', 'SEARCH'),
      ('assets/CATALOG.png', 'CATALOG'),
      ('assets/PROFILE.png', 'PROFILE'),
    ];

    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xFF090D13),
        border: Border(
          top: BorderSide(
            color: Color(0xFF202832),
            width: 1,
          ),
        ),
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
                      Image.asset(
                        items[i].$1,
                        width: 18,
                        height: 18,
                        color: i == selectedIndex
                            ? const Color(0xFFFFB21A)
                            : const Color(0xFF737C88),
                        colorBlendMode: BlendMode.srcIn,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        items[i].$2,
                        style: TextStyle(
                          color: i == selectedIndex
                              ? const Color(0xFFFFB21A)
                              : const Color(0xFF737C88),
                          fontSize: 6,
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
}