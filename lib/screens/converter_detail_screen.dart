import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../models/converter_record.dart';
import '../services/authenticated_api_client.dart';
import '../services/brand_service.dart';
import '../services/converter_service.dart';
import '../widgets/converter_detail/converter_detail_content.dart';
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
  var _isLoading = true;

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
      if (!mounted) return;
      setState(() {
        _converter = converter;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
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
      return 'The backend denied access to this converter.';
    }
    if (error is FormatException) {
      return 'The converter details could not be read.';
    }
    return 'Unable to load converter details. Check your connection and retry.';
  }

  Future<void> _editConverter() async {
    final converter = _converter;
    if (!widget.isAdmin || converter == null) return;

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
    if (!mounted || converterId == null) return;

    widget.onChanged?.call();
    await _loadConverter();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Converter updated.')));
    }
  }

  Future<void> _deleteConverter() async {
    if (!widget.isAdmin) return;
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
    if (shouldDelete != true || !mounted) return;

    try {
      await widget.converterService.deleteConverter(widget.converterId);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_deleteMessageFor(error))));
      }
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
    final converter = _converter;
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _isLoading || _error != null
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        children: [
                          _FallbackTopBar(
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          if (_isLoading)
                            const _DetailLoadingState()
                          else
                            _DetailErrorState(
                              message: _error!,
                              onRetry: _loadConverter,
                            ),
                        ],
                      ),
                    ),
                  )
                : ConverterDetailContent(
                    converter: converter!,
                    brandName:
                        converter.brandName ??
                        (converter.brandId == null
                            ? null
                            : widget.brandsById[converter.brandId]),
                    isAdmin: widget.isAdmin,
                    onBack: () => Navigator.of(context).pop(),
                    onEdit: _editConverter,
                    onDelete: _deleteConverter,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FallbackTopBar extends StatelessWidget {
  const _FallbackTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        style: IconButton.styleFrom(
          backgroundColor: palette.surfaceElevated,
          foregroundColor: palette.textSecondary,
          side: const BorderSide(color: AppColors.border),
        ),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }
}

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 100),
    child: Center(
      child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
    ),
  );
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
