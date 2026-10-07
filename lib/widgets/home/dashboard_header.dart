import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/Logo.png',
          width: 58,
          height: 58,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MALIK ENTERPRISES',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Catalytic Converter Reference Catalog',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFF858D99), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, this.onBrowseBrands});

  final VoidCallback? onBrowseBrands;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: QuickActionCard(
            icon: Icons.search,
            title: 'Search a\nReference',
            subtitle: 'By code / marking',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: QuickActionCard(
            icon: Icons.directions_car_outlined,
            title: 'Search by\nCar Model',
            subtitle: 'Browse brands',
            onTap: onBrowseBrands,
          ),
        ),
      ],
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: title.replaceAll('\n', ' '),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF111720),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1D2734)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 154,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2027),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFFFFB21A),
                        size: 27,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF707985),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
