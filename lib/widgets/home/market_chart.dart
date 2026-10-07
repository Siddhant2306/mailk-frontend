import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/market_formatters.dart';
import '../../models/market_models.dart';
import '../../models/metal_price.dart';
import 'market_chart_painter.dart';

class MarketChart extends StatelessWidget {
  const MarketChart({
    required this.selectedMetal,
    required this.selectedUnit,
    required this.history,
    required this.isLoading,
    required this.onMetalChanged,
    required this.onUnitChanged,
    super.key,
  });

  final MetalType selectedMetal;
  final PriceUnit selectedUnit;
  final List<MetalPrice> history;
  final bool isLoading;
  final ValueChanged<MetalType> onMetalChanged;
  final ValueChanged<PriceUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 312,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _ChartTitle(),
                  const Spacer(),
                  for (final metal in MetalType.values) ...[
                    _MetalSelector(
                      metal: metal,
                      isSelected: selectedMetal == metal,
                      onPressed: () => onMetalChanged(metal),
                    ),
                    if (metal != MetalType.values.last)
                      const SizedBox(width: 5),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${selectedMetal.displayName} trend • ${selectedUnit.chartLabel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _ChartBody(
                  history: history,
                  isLoading: isLoading,
                  unit: selectedUnit,
                  metal: selectedMetal,
                ),
              ),
              const SizedBox(height: 5),
              _DateRange(history: history),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final unit in PriceUnit.values)
                      _UnitButton(
                        unit: unit,
                        isSelected: selectedUnit == unit,
                        onPressed: () => onUnitChanged(unit),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          'PGM MARKET',
          style: TextStyle(
            color: Color(0xFFB8C0CB),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 7),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF14251D),
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              'LIVE',
              style: TextStyle(
                color: Color(0xFF63C18A),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetalSelector extends StatelessWidget {
  const _MetalSelector({
    required this.metal,
    required this.isSelected,
    required this.onPressed,
  });

  final MetalType metal;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${metal.displayName} chart',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.metal(metal),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 7, height: 7),
              ),
              const SizedBox(width: 4),
              Text(
                metal.symbol,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE5E9EF) : AppColors.muted,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.history,
    required this.isLoading,
    required this.unit,
    required this.metal,
  });

  final List<MetalPrice> history;
  final bool isLoading;
  final PriceUnit unit;
  final MetalType metal;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      );
    }
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'History is currently unavailable.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: MarketChartPainter(
          history: history,
          unit: unit,
          lineColor: AppColors.metal(metal),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DateRange extends StatelessWidget {
  const _DateRange({required this.history});

  final List<MetalPrice> history;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          MarketFormatters.date(history.isEmpty ? null : history.first),
          style: const TextStyle(color: Color(0xFF697381), fontSize: 10),
        ),
        const Spacer(),
        Text(
          MarketFormatters.date(history.isEmpty ? null : history.last),
          style: const TextStyle(color: Color(0xFF697381), fontSize: 10),
        ),
      ],
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({
    required this.unit,
    required this.isSelected,
    required this.onPressed,
  });

  final PriceUnit unit;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: unit.chartLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF332711)
                : const Color(0xFF151B23),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.accent : const Color(0xFF303947),
            ),
          ),
          child: Text(
            unit.chartLabel,
            style: TextStyle(
              color: isSelected ? AppColors.accentLight : AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
