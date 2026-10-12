import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/market_formatters.dart';
import '../../models/market_models.dart';
import '../../models/metal_price.dart';

/// A compact, fixed row of the three tracked metals.
///
/// The card layout intentionally follows the home-screen reference: all three
/// prices are visible at once, with no horizontal scrolling required.
class MetalPriceGrid extends StatelessWidget {
  const MetalPriceGrid({
    required this.snapshot,
    required this.selectedUnit,
    required this.isLoading,
    required this.hasLoadedOnce,
    required this.onRetry,
    super.key,
  });

  final MarketSnapshot snapshot;
  final PriceUnit selectedUnit;
  final bool isLoading;
  final bool hasLoadedOnce;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metal in MetalType.values) ...[
          Expanded(
            child: SizedBox(
              height: 112,
              child: MetalPriceCard(
                metal: metal,
                inrQuote: snapshot.quoteFor(metal, PriceUnit.inr),
                usdQuote: snapshot.quoteFor(metal, PriceUnit.usd),
                displayedUnit: selectedUnit,
                isLoading: isLoading,
                hasLoadedOnce: hasLoadedOnce,
                onRetry: onRetry,
              ),
            ),
          ),
          if (metal != MetalType.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class MetalPriceCard extends StatelessWidget {
  const MetalPriceCard({
    required this.metal,
    required this.inrQuote,
    required this.usdQuote,
    required this.displayedUnit,
    required this.isLoading,
    required this.hasLoadedOnce,
    required this.onRetry,
    super.key,
  });

  final MetalType metal;
  final MetalLivePrice? inrQuote;
  final MetalLivePrice? usdQuote;
  final PriceUnit displayedUnit;
  final bool isLoading;
  final bool hasLoadedOnce;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final preferredQuote = displayedUnit == PriceUnit.inr ? inrQuote : usdQuote;
    final quote = preferredQuote;
    final unit = displayedUnit;
    final change = quote?.changePercentage;
    final hasChange = change != null && change.isFinite;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetalHeading(metal: metal),
            const SizedBox(height: 2),
            Text(
              metal.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted, fontSize: 8),
            ),
            const Spacer(),
            _PriceText(quote: quote, unit: unit, isLoading: isLoading),
            const SizedBox(height: 3),
            if (hasChange)
              _PriceChange(change: change)
            else
              _CardStatus(
                isLoading: isLoading,
                hasLoadedOnce: hasLoadedOnce,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

class _CardStatus extends StatelessWidget {
  const _CardStatus({
    required this.isLoading,
    required this.hasLoadedOnce,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasLoadedOnce;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (isLoading || !hasLoadedOnce) {
      return Text(
        'Updating…',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.textMuted, fontSize: 8),
      );
    }

    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          'Tap to retry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.accent,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MetalHeading extends StatelessWidget {
  const _MetalHeading({required this.metal});

  final MetalType metal;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
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
            color: palette.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PriceText extends StatelessWidget {
  const _PriceText({
    required this.quote,
    required this.unit,
    required this.isLoading,
  });

  final MetalLivePrice? quote;
  final PriceUnit unit;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final value = isLoading && quote == null
        ? 'Loading…'
        : unit == PriceUnit.inr
        ? MarketFormatters.cardInrPrice(quote)
        : MarketFormatters.cardUsdPrice(quote);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Column(
        key: ValueKey(unit),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Text(
            unit == PriceUnit.inr ? 'INR / kg' : 'USD / oz',
            style: const TextStyle(color: AppColors.muted, fontSize: 7),
          ),
        ],
      ),
    );
  }
}

class _PriceChange extends StatelessWidget {
  const _PriceChange({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final isPositive = change >= 0;
    return Text(
      '${isPositive ? '↗' : '↘'} ${change.abs().toStringAsFixed(2)}%',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isPositive ? AppColors.positive : AppColors.negative,
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
