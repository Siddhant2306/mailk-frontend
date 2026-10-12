import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../models/converter_record.dart';
import '../services/authenticated_api_client.dart';
import '../services/converter_service.dart';

class ConverterDetailScreen extends StatefulWidget {
  const ConverterDetailScreen({
    required this.converterId,
    required this.converterService,
    required this.brandsById,
    super.key,
  });

  final int converterId;
  final ConverterService converterService;
  final Map<int, String> brandsById;

  @override
  State<ConverterDetailScreen> createState() => _ConverterDetailScreenState();
}

class _ConverterDetailScreenState extends State<ConverterDetailScreen> {
  ConverterRecord? _converter;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConverter();
  }

  Future<void> _loadConverter() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final converter = await widget.converterService.getConverter(
        widget.converterId,
        brandsById: widget.brandsById,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _converter = converter;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _messageFor(error);
      });
    }
  }

  String _messageFor(Object error) {
    if (error is AuthenticationRequiredException) {
      return 'Sign in to view converter details.';
    }
    if (error is DioException && error.response?.statusCode == 401) {
      return 'Your session could not access this converter. Please sign in again.';
    }
    if (error is DioException && error.response?.statusCode == 403) {
      return 'The backend denied access to this converter. Check the account status and access policy.';
    }
    if (error is FormatException) {
      return 'The converter details could not be read.';
    }
    return 'Unable to load converter details. Check your connection and retry.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final converter = _converter;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailTopBar(onBack: () => Navigator.of(context).pop()),
                    if (_isLoading)
                      const _DetailLoadingState()
                    else if (_error != null)
                      _DetailErrorState(
                        message: _error!,
                        onRetry: _loadConverter,
                      )
                    else if (converter != null)
                      _ConverterDetails(
                        converter: converter,
                        brandName:
                            converter.brandName ??
                            (converter.brandId == null
                                ? null
                                : widget.brandsById[converter.brandId]),
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

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Material(
            color: palette.surfaceElevated,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_left,
                  color: palette.textSecondary,
                  size: 23,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'MALIK ENTERPRISES',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ConverterDetails extends StatelessWidget {
  const _ConverterDetails({required this.converter, required this.brandName});

  final ConverterRecord converter;
  final String? brandName;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final title = converter.model?.isNotEmpty == true
        ? converter.model!
        : converter.codeReference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text(
          title.isEmpty ? 'Converter ${converter.id}' : title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (brandName != null) ...[
          const SizedBox(height: 3),
          Text(
            brandName!,
            style: TextStyle(color: palette.textMuted, fontSize: 14),
          ),
        ],
        if (converter.images.isNotEmpty) ...[
          const SizedBox(height: 22),
          _DetailImages(images: converter.images),
        ],
        const SizedBox(height: 25),
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
            _DetailRow('Converter Type', _orDash(converter.converterType)),
            _DetailRow('Category', _orDash(converter.category)),
            _DetailRow('Local Lingo', _orDash(converter.localLingo)),
          ],
        ),
        if (converter.markings.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('MARKINGS'),
          const SizedBox(height: 9),
          _DetailCard(
            rows: [
              for (var index = 0; index < converter.markings.length; index++)
                _DetailRow('${index + 1}.', converter.markings[index]),
            ],
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('PGM CONTENT'),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _MetalContentCard(
                label: 'PLATINUM',
                value: converter.ptPpm,
                icon: Icons.hub_outlined,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MetalContentCard(
                label: 'PALLADIUM',
                value: converter.pdPpm,
                icon: Icons.refresh,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MetalContentCard(
                label: 'RHODIUM',
                value: converter.rhPpm,
                icon: Icons.wb_sunny_outlined,
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
    );
  }
}

class _DetailImages extends StatelessWidget {
  const _DetailImages({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final uri = _resolveImageUrl(images[index]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: uri == null
                  ? Icon(
                      Icons.broken_image_outlined,
                      color: palette.textMuted,
                    )
                  : Image.network(
                      uri,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Text(
      title,
      style: TextStyle(
        color: palette.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
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
                    : Border(
                        bottom: BorderSide(color: palette.border),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      rows[index].value,
                      textAlign: TextAlign.right,
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
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _MetalContentCard extends StatelessWidget {
  const _MetalContentCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(9, 10, 8, 9),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 16),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.45,
            ),
          ),
          const SizedBox(height: 5),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value == null ? '—' : _formatNumber(value!),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (value != null)
                  TextSpan(
                    text: '  ppm',
                    style: TextStyle(color: palette.textMuted, fontSize: 8),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 100),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: palette.textMuted,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _orDash(String? value) => value?.isNotEmpty == true ? value! : '—';

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String? _resolveImageUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || value.trim().isEmpty) {
    return null;
  }
  if (uri.hasScheme) {
    return uri.toString();
  }
  return Uri.parse(ApiConfig.baseUrl).resolveUri(uri).toString();
}
