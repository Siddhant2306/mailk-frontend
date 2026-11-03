import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../services/converter_import_parser.dart';
import '../../services/converter_service.dart';

class BulkImportSheet extends StatefulWidget {
  const BulkImportSheet({required this.converterService, super.key});

  final ConverterService converterService;

  @override
  State<BulkImportSheet> createState() => _BulkImportSheetState();
}

class _BulkImportSheetState extends State<BulkImportSheet> {
  final _parser = ConverterImportParser();
  ConverterImportPreview? _preview;
  var _isPicking = false;
  var _isImporting = false;
  String? _submitError;

  Future<void> _chooseFile() async {
    setState(() {
      _isPicking = true;
      _preview = null;
      _submitError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      final file = result == null || result.files.isEmpty
          ? null
          : result.files.first;
      if (file != null && mounted) {
        final preview = await _parser.parseAsync(file);
        if (mounted) {
          setState(() => _preview = preview);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || !preview.isReady || _isImporting) {
      return;
    }

    setState(() {
      _isImporting = true;
      _submitError = null;
    });
    try {
      final ids = await widget.converterService.createConvertersBulk(
        preview.rows,
      );
      if (mounted) {
        Navigator.of(context).pop(ids.length);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _submitError = widget.converterService.messageFor(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bulk import',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Validate a CSV or XLSX file before importing it.',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _chooseFile,
                icon: _isPicking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(_isPicking ? 'Reading file…' : 'Choose CSV / XLSX'),
              ),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              _PreviewCard(preview: _preview!),
            ],
            const SizedBox(height: 14),
            const _BulkImportNotice(),
            if (_submitError != null) ...[
              const SizedBox(height: 10),
              Text(
                _submitError!,
                style: const TextStyle(color: AppColors.negative, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed:
                    _preview?.isReady == true && !_isPicking && !_isImporting
                    ? _import
                    : null,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isImporting
                      ? 'Importing…'
                      : 'Import ${_preview?.rows.length ?? 0} converters',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final ConverterImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${preview.rows.length} valid rows • ${preview.errors.length} rows with errors',
              style: TextStyle(
                color: preview.errors.isEmpty
                    ? AppColors.positive
                    : AppColors.negative,
                fontSize: 12,
              ),
            ),
            if (preview.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final error in preview.errors.take(3))
                Text(
                  error,
                  style: TextStyle(color: palette.textMuted, fontSize: 10),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulkImportNotice extends StatelessWidget {
  const _BulkImportNotice();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: palette.accent, size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Files are limited to 2 MB and 100 rows. The protected import is all-or-nothing: correct every row before submitting.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
