import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../models/converter_record.dart';
import 'converter_image_hero.dart';

/// Read-only converter data and image gallery used by the detail screen.
class ConverterDetailContent extends StatelessWidget {
  const ConverterDetailContent({
    required this.converter,
    required this.brandName,
    required this.isAdmin,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ConverterRecord converter;
  final String? brandName;
  final bool isAdmin;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final code = converter.converterCode.isNotEmpty
        ? converter.converterCode
        : converter.codeReference.isNotEmpty
        ? converter.codeReference
        : converter.id.toString();
    final title = converter.model?.trim().isNotEmpty == true
        ? converter.model!.trim()
        : converter.codeReference.isNotEmpty
        ? converter.codeReference
        : 'Converter ${converter.id}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConverterImageHero(
          images: converter.images,
          isAdmin: isAdmin,
          onBack: onBack,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityHeader(code: code, title: title, brandName: brandName),
              const SizedBox(height: 24),
              const _SectionTitle('DETAILS'),
              const SizedBox(height: 9),
              _DetailCard(
                rows: [
                  _DetailRow('Reference', _orDash(converter.codeReference)),
                  _DetailRow('Make', _orDash(brandName)),
                  _DetailRow('Model', _orDash(converter.model)),
                  _DetailRow('Country', _orDash(converter.country)),
                  _DetailRow(
                    'Monolith Wt',
                    converter.monolithWeightGrams == null
                        ? '—'
                        : '${_formatNumber(converter.monolithWeightGrams!)} g',
                  ),
                  _DetailRow(
                    'Converter Type',
                    _orDash(converter.converterType),
                  ),
                  _DetailRow('Category', _orDash(converter.category)),
                  _DetailRow('Local Lingo', _orDash(converter.localLingo)),
                  if (converter.markings.isNotEmpty)
                    _DetailRow(
                      'Markings',
                      converter.markings.join('\n'),
                      valueAlignment: TextAlign.left,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle('PGM CONTENT'),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _MetalContentCard(
                      label: 'PLATINUM',
                      value: converter.ptPpm,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetalContentCard(
                      label: 'PALLADIUM',
                      value: converter.pdPpm,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetalContentCard(
                      label: 'RHODIUM',
                      value: converter.rhPpm,
                    ),
                  ),
                ],
              ),
              if (converter.remarks?.isNotEmpty == true) ...[
                const SizedBox(height: 24),
                const _SectionTitle('REMARKS'),
                const SizedBox(height: 9),
                _TextDetailCard(text: converter.remarks!),
              ],
              if (converter.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 24),
                const _SectionTitle('NOTES'),
                const SizedBox(height: 9),
                _TextDetailCard(text: converter.notes!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.code,
    required this.title,
    required this.brandName,
  });

  final String code;
  final String title;
  final String? brandName;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ID  $code',
          style: TextStyle(
            color: palette.accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          brandName?.trim().isNotEmpty == true ? brandName! : 'Unknown',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: AppPalette.of(context).textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: index == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      rows[index].value,
                      textAlign: rows[index].valueAlignment,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(
    this.label,
    this.value, {
    this.valueAlignment = TextAlign.right,
  });

  final String label;
  final String value;
  final TextAlign valueAlignment;
}

class _MetalContentCard extends StatelessWidget {
  const _MetalContentCard({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _PgmContentIcon(),
            ),
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value == null ? '—' : _formatNumber(value!),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        'ppm',
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _PgmContentIcon extends StatelessWidget {
  const _PgmContentIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/pgm_content_icon_cropped.png',
      width: 20,
      height: 16,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _TextDetailCard extends StatelessWidget {
  const _TextDetailCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

String _orDash(String? value) =>
    value?.trim().isNotEmpty == true ? value! : '—';

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
