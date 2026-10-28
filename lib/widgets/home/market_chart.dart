import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
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
    required this.isStale,
    required this.onMetalChanged,
    required this.onUnitChanged,
    super.key,
  });

  final MetalType selectedMetal;
  final PriceUnit selectedUnit;
  final List<MetalPrice> history;
  final bool isLoading;
  final bool isStale;
  final ValueChanged<MetalType> onMetalChanged;
  final ValueChanged<PriceUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
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
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: _ChartTitle(isStale: isStale),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${selectedMetal.displayName} • ${selectedUnit.chartLabel}',
                style: TextStyle(
                  color: palette.textPrimary,
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
                child: _UnitSelector(
                  selectedUnit: selectedUnit,
                  onUnitChanged: onUnitChanged,
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
  const _ChartTitle({required this.isStale});

  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PGM MARKET',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 7),
        DecoratedBox(
          decoration: BoxDecoration(
            color: isStale
                ? (isDark ? const Color(0xFF2A2420) : const Color(0xFFFFF3DA))
                : (isDark ? const Color(0xFF14251D) : const Color(0xFFE8F6EC)),
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              isStale ? 'CACHED' : 'LIVE',
              style: TextStyle(
                color: isStale
                    ? (isDark
                          ? const Color(0xFFF1BF64)
                          : const Color(0xFF9A6400))
                    : (isDark
                          ? const Color(0xFF63C18A)
                          : const Color(0xFF267B46)),
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
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${metal.displayName} chart',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? palette.accentSoft : palette.background,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected ? AppColors.metal(metal) : palette.border,
            ),
          ),
          child: InkWell(
            key: ValueKey('chart-metal-${metal.symbol}'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  const SizedBox(width: 5),
                  Text(
                    metal.symbol,
                    style: TextStyle(
                      color: isSelected
                          ? palette.textPrimary
                          : palette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
    final palette = AppPalette.of(context);
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      );
    }
    if (history.isEmpty) {
      return Center(
        child: Text(
          'History is currently unavailable.',
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
      );
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: MarketChartPainter(
          history: history,
          unit: unit,
          lineColor: AppColors.metal(metal),
          gridColor: palette.border,
          labelColor: palette.textMuted,
          surfaceColor: palette.surface,
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
    final palette = AppPalette.of(context);
    return Row(
      children: [
        Text(
          MarketFormatters.date(history.isEmpty ? null : history.first),
          style: TextStyle(color: palette.textMuted, fontSize: 10),
        ),
        const Spacer(),
        Text(
          MarketFormatters.date(history.isEmpty ? null : history.last),
          style: TextStyle(color: palette.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.selectedUnit,
    required this.onUnitChanged,
  });

  final PriceUnit selectedUnit;
  final ValueChanged<PriceUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnitSegment(
              unit: PriceUnit.inr,
              isSelected: selectedUnit == PriceUnit.inr,
              onPressed: () => onUnitChanged(PriceUnit.inr),
            ),
            Container(width: 1, height: 24, color: palette.border),
            _UnitSegment(
              unit: PriceUnit.usd,
              isSelected: selectedUnit == PriceUnit.usd,
              onPressed: () => onUnitChanged(PriceUnit.usd),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitSegment extends StatelessWidget {
  const _UnitSegment({
    required this.unit,
    required this.isSelected,
    required this.onPressed,
  });

  final PriceUnit unit;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: unit.chartLabel,
      child: Ink(
        color: isSelected ? palette.accentSoft : Colors.transparent,
        child: InkWell(
          key: ValueKey('chart-unit-${unit.name}'),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              unit.chartLabel,
              style: TextStyle(
                color: isSelected ? palette.accent : palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
