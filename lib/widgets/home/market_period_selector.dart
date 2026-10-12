import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../models/market_models.dart';

class MarketPeriodSelector extends StatelessWidget {
  const MarketPeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
    super.key,
  });

  final MarketPeriod selectedPeriod;
  final ValueChanged<MarketPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final period in MarketPeriod.values) ...[
          Expanded(
            child: _PeriodButton(
              period: period,
              isSelected: period == selectedPeriod,
              onPressed: () => onChanged(period),
            ),
          ),
          if (period != MarketPeriod.values.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.period,
    required this.isSelected,
    required this.onPressed,
  });

  final MarketPeriod period;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = isSelected
        ? palette.accent
        : palette.textSecondary;

    return Semantics(
      selected: isSelected,
      button: true,
      label: '${period.label} history',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: 30,
            decoration: BoxDecoration(
              color: isSelected ? palette.accentSoft : palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFB21A)
                    : palette.border,
              ),
            ),
            child: Center(
              child: Text(
                period.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
