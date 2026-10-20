import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../models/converter_record.dart';
import '../services/authenticated_api_client.dart';
import '../services/brand_service.dart';
import '../services/converter_service.dart';
import '../widgets/profile/converter_form_sheet.dart';

class ConverterDetailScreen extends StatefulWidget {
  const ConverterDetailScreen({
    required this.converterId,
    required this.converterService,
    required this.brandsById,
    this.brandService,
    this.isAdmin = false,
    this.onChanged,
    super.key,
  });

  final int converterId;
  final ConverterService converterService;
  final Map<int, String> brandsById;
  final BrandService? brandService;
  final bool isAdmin;
  final VoidCallback? onChanged;

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

  Future<void> _editConverter() async {
    final converter = _converter;
    if (!widget.isAdmin || converter == null) {
      return;
    }
    final converterId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ConverterFormSheet(
        converterService: widget.converterService,
        brandService: widget.brandService,
        converter: converter,
      ),
    );
    if (!mounted || converterId == null) {
      return;
    }
    widget.onChanged?.call();
    await _loadConverter();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Converter updated.')));
  }

  Future<void> _deleteConverter() async {
    if (!widget.isAdmin) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete converter?'),
        content: const Text(
          'This will permanently remove the converter from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await widget.converterService.deleteConverter(widget.converterId);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_deleteMessageFor(error))));
    }
  }

  String _deleteMessageFor(Object error) {
    if (error is AuthenticationRequiredException) {
      return 'Please sign in again before deleting this converter.';
    }
    if (error is DioException && error.response?.statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if (error is DioException && error.response?.statusCode == 403) {
      return 'Admin permission is required to delete converters.';
    }
    return 'Could not delete this converter. Check your connection and retry.';
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
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _DetailTopBar(
                      onBack: () => Navigator.of(context).pop(),
                      isAdmin: widget.isAdmin && converter != null,
                      onEdit: _editConverter,
                      onDelete: _deleteConverter,
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _DetailLoadingState(),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _DetailErrorState(
                        message: _error!,
                        onRetry: _loadConverter,
                      ),
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
          ],
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.onBack,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onBack;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
          if (isAdmin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit converter',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, color: palette.accent),
                ),
                IconButton(
                  tooltip: 'Delete converter',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            )
          else
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
    final title = converter.model?.isNotEmpty == true
        ? converter.model!
        : converter.codeReference;
    final converterCode = converter.converterCode.isNotEmpty
        ? converter.converterCode
        : converter.codeReference.isNotEmpty
        ? converter.codeReference
        : converter.id.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConverterHero(
          images: converter.images,
          converterCode: converterCode,
          title: title.isEmpty ? 'Converter ${converter.id}' : title,
          brandName: brandName,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      lableColor: const Color.fromARGB(255, 255, 183, 0),
                      lableFontSize: 15,
                      value: converter.ptPpm,
                      symbol: 'Pt',

                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetalContentCard(
                      label: 'PALLADIUM',
                      lableColor: const Color.fromARGB(255, 255, 183, 0),
                      lableFontSize: 15,
                      value: converter.pdPpm,
                      symbol: 'Pd',
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _MetalContentCard(
                      label: 'RHODIUM',
                      lableColor: const Color.fromARGB(255, 255, 183, 0),
                      lableFontSize: 15,
                      value: converter.rhPpm,
                      symbol: 'Rh',
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

class _ConverterHero extends StatefulWidget {
  const _ConverterHero({
    required this.images,
    required this.converterCode,
    required this.title,
    required this.brandName,
  });

  final List<String> images;
  final String converterCode;
  final String title;
  final String? brandName;

  @override
  State<_ConverterHero> createState() => _ConverterHeroState();
}

class _ConverterHeroState extends State<_ConverterHero> {
  var _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _ConverterHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_imageIndex >= widget.images.length) {
      _imageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final uri = widget.images.isEmpty
        ? null
        : _resolveImageUrl(widget.images[_imageIndex]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = (constraints.maxWidth * 0.9)
            .clamp(340.0, 480.0)
            .toDouble();
        return SizedBox(
          key: const ValueKey('converter-detail-image-hero'),
          height: heroHeight,
          child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: palette.surfaceElevated,
            child: uri == null
                ? Icon(Icons.image_outlined, color: palette.textMuted, size: 42)
                : Image.network(
                    uri,
                    fit: BoxFit.contain,
                    key: ValueKey(uri),
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: palette.textMuted,
                        size: 36,
                      ),
                    ),
                  ),
          ),
          if (widget.images.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  tooltip: 'Previous image',
                  onPressed: () => setState(
                    () => _imageIndex =
                        (_imageIndex - 1 + widget.images.length) %
                        widget.images.length,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: palette.accentSoft,
                    foregroundColor: palette.accent,
                    side: BorderSide(
                      color: palette.accent.withValues(alpha: 0.7),
                    ),
                    shape: const CircleBorder(),
                    fixedSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  tooltip: 'Next image',
                  onPressed: () => setState(
                    () =>
                        _imageIndex = (_imageIndex + 1) % widget.images.length,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: palette.accentSoft,
                    foregroundColor: palette.accent,
                    side: BorderSide(
                      color: palette.accent.withValues(alpha: 0.7),
                    ),
                    shape: const CircleBorder(),
                    fixedSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  child: Text(
                    '${_imageIndex + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x1A000000),
                    Color(0xD9000000),
                  ],
                  stops: [0.25, 0.58, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent, width: 1.2),
                    borderRadius: BorderRadius.circular(5),
                    color: const Color(0x3310141C),
                  ),
                  child: Text(
                    'ID  ${widget.converterCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
                if (widget.brandName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    widget.brandName!,
                    style: TextStyle(
                      color: palette.textPrimary.withValues(alpha: 0.9),
                      fontSize: 14,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
            ],
          ),
        );
      },
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
  const _MetalContentCard({
    required this.label,
    required this.value,
    required this.symbol,
    this.lableColor,
    this.lableFontSize,

  });

  final String label;
  final double? value;
  final String symbol;
  final Color? lableColor;
  final double? lableFontSize;

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
          //_ElementBadge(symbol: symbol, color: palette.accent),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: lableColor ?? palette.textMuted,
              fontSize: lableFontSize ?? 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.45,
              fontFamily: 'assets/fonts/LiberationSans-Regular.ttf',
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
                    fontWeight: FontWeight.w400,
                    fontFamily: 'assets/fonts/LiberationSans-Regular.ttf',
                  ),
                ),
                if (value != null)
                  TextSpan(
                    text: '  ppm',
                    style: TextStyle(color: palette.textMuted, fontSize: 8, fontFamily: 'assets/fonts/LiberationSans-Regular.ttf'),
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
          fontFamily: 'assets/fonts/LiberationSans-Regular.ttf',
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
          Icon(Icons.cloud_off_outlined, color: palette.textMuted, size: 32),
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
