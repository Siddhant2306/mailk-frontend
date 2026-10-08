import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/converter_import_parser.dart';

class BulkImportSheet extends StatefulWidget {
  const BulkImportSheet({super.key});

  @override
  State<BulkImportSheet> createState() => _BulkImportSheetState();
}

class _BulkImportSheetState extends State<BulkImportSheet> {
  final _parser = ConverterImportParser();
  ConverterImportPreview? _preview;
  var _isPicking = false;

  Future<void> _chooseFile() async {
    setState(() => _isPicking = true);
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
        setState(() => _preview = _parser.parse(file));
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF4A5260),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Bulk import',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Validate a CSV or XLSX file before importing it.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
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
            const _BulkApiNotice(),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF293343)),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${preview.rows.length} valid rows • ${preview.errors.length} rows with errors',
              style: TextStyle(
                color: preview.errors.isEmpty ? AppColors.positive : AppColors.negative,
                fontSize: 12,
              ),
            ),
            if (preview.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final error in preview.errors.take(3))
                Text(error, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulkApiNotice extends StatelessWidget {
  const _BulkApiNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF20180B),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF49340F)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.accent, size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'The file is validated locally. Import is disabled until the backend exposes a protected bulk converter endpoint.',
                style: TextStyle(color: Color(0xFFE0B75F), fontSize: 11, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
