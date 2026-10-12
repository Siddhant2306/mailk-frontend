import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../models/converter_draft.dart';
import '../../services/converter_service.dart';

class ConverterFormSheet extends StatefulWidget {
  const ConverterFormSheet({required this.converterService, super.key});

  final ConverterService converterService;

  @override
  State<ConverterFormSheet> createState() => _ConverterFormSheetState();
}

class _ConverterFormSheetState extends State<ConverterFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _brandIdController = TextEditingController();
  final _codeController = TextEditingController();
  final _modelController = TextEditingController();
  final _typeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _localLingoController = TextEditingController();
  final _weightController = TextEditingController();
  final _ptController = TextEditingController();
  final _pdController = TextEditingController();
  final _rhController = TextEditingController();
  final _markingsController = TextEditingController();
  final _remarksController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_PendingConverterImage> _pendingImages = [];

  var _isSaving = false;
  var _isPickingImage = false;
  var _step = 0;

  @override
  void dispose() {
    for (final controller in [
      _brandIdController,
      _codeController,
      _modelController,
      _typeController,
      _categoryController,
      _localLingoController,
      _weightController,
      _ptController,
      _pdController,
      _rhController,
      _markingsController,
      _remarksController,
      _notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final imageUrls = <String>[];
      for (final image in _pendingImages) {
        imageUrls.add(
          await widget.converterService.uploadConverterImage(
            bytes: image.bytes,
            fileName: image.fileName,
          ),
        );
      }

      final converterId = await widget.converterService.createConverter(
        ConverterDraft(
          brandId: int.parse(_brandIdController.text.trim()),
          codeReference: _codeController.text.trim(),
          model: _optional(_modelController),
          converterType: _optional(_typeController),
          category: _optional(_categoryController),
          localLingo: _optional(_localLingoController),
          monolithWeightGrams: _optionalNumber(_weightController),
          ptPpm: _optionalNumber(_ptController),
          pdPpm: _optionalNumber(_pdController),
          rhPpm: _optionalNumber(_rhController),
          markings: _items(_markingsController),
          images: imageUrls,
          remarks: _optional(_remarksController),
          notes: _optional(_notesController),
        ),
      );
      if (mounted) {
        Navigator.pop(context, converterId);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.converterService.messageFor(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _optionalNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  List<String> _items(TextEditingController controller) {
    return controller.text
        .split(RegExp(r'[,\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _pickDeviceImages() async {
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;

      final selectedImages = <_PendingConverterImage>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw const FormatException('The selected image could not be read.');
        }
        selectedImages.add(
          _PendingConverterImage(bytes: bytes, fileName: file.name),
        );
      }
      setState(() => _pendingImages.addAll(selectedImages));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select images: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _captureImage() async {
    setState(() => _isPickingImage = true);
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingImages.add(
          _PendingConverterImage(bytes: bytes, fileName: image.name),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  void _continueToMetrics() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 1);
  }

  void _goToIdentification() {
    setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardInset;
    final palette = AppPalette.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: availableHeight * 0.94,
          child: ColoredBox(
            color: palette.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: _step == 0
                            ? _buildIdentificationStep()
                            : _buildMetricsStep(),
                      ),
                    ),
                    _buildBottomAction(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final palette = AppPalette.of(context);
    return Column(
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
        const SizedBox(height: 14),
        Row(
          children: [
            IconButton(
              onPressed: _step == 0
                  ? () => Navigator.pop(context)
                  : _goToIdentification,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: palette.surfaceElevated,
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.border),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MALIK ENTERPRISES',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Add Converter',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                'STEP ${_step + 1} OF 2',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdentificationStep() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('PHOTOS'),
        Row(
          children: [
            Expanded(
              child: _PhotoAction(
                icon: Icons.photo_library_outlined,
                title: 'Gallery',
                subtitle: 'Pick from storage',
                onPressed: _isSaving || _isPickingImage
                    ? null
                    : _pickDeviceImages,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoAction(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                subtitle: 'Take a photo',
                onPressed: _isSaving || _isPickingImage ? null : _captureImage,
              ),
            ),
          ],
        ),
        if (_isPickingImage) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 2,
            color: palette.accent,
            backgroundColor: palette.border,
          ),
        ],
        if (_pendingImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = _pendingImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        image.bytes,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _isSaving ? null : () => _removeImage(index),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black87,
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        const _InfoNotice(
          'Clear stamp engravings ensure instant automated grading.',
        ),
        const _SectionLabel('IDENTIFICATION'),
        const _SectionLabel('REQUIRED FIELDS'),
        _AdminField(
          controller: _codeController,
          label: 'Code / Reference *',
          hintText: 'e.g., DCAT-4472',
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter a converter reference'
              : null,
        ),
        _AdminField(
          controller: _brandIdController,
          label: 'Make / Brand database ID *',
          hintText: 'Enter the required numeric brand ID',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (int.tryParse(value?.trim() ?? '') == null) {
              return 'Enter a numeric database brand ID';
            }
            return null;
          },
        ),
        const _FieldHint(
          'The catalogue API links converters using the internal brand database ID.',
        ),
        _AdminField(
          controller: _modelController,
          label: 'Vehicle model',
          hintText: 'e.g., Camry 2.4',
        ),
        _buildCountryOfOrigin(),
        const _SectionLabel('CLASSIFICATION'),
        const _SectionLabel('CONVERTER TYPE'),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final type in const [
              'Standard',
              'Ceramic',
              'Metallic',
              'DPF',
              'Universal',
            ])
              ChoiceChip(
                label: Text(type),
                selected: _typeController.text == type,
                onSelected: (_) {
                  setState(() {
                    _typeController.text = _typeController.text == type
                        ? ''
                        : type;
                  });
                },
                selectedColor: AppPalette.of(context).accent,
                backgroundColor: AppPalette.of(context).surfaceElevated,
                labelStyle: TextStyle(
                  color: _typeController.text == type
                      ? AppPalette.of(context).surface
                      : AppPalette.of(context).textSecondary,
                  fontSize: 11,
                ),
                side: BorderSide(color: AppPalette.of(context).border),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _AdminField(
          controller: _categoryController,
          label: 'Category',
          hintText: 'OEM, aftermarket, etc.',
        ),
        _AdminField(
          controller: _localLingoController,
          label: 'Local name / alias',
          hintText: 'Trade nickname',
        ),
      ],
    );
  }

  Widget _buildMetricsStep() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('METRICS & MARKINGS'),
        const _SectionLabel('MARKINGS & STAMP CODES'),
        _AdminField(
          controller: _markingsController,
          label: 'Markings',
          hintText: 'Comma or line-separated codes',
          maxLines: 2,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('ASSAY METRICS & LOADINGS'),
              _AdminField(
                controller: _weightController,
                label: 'Monolith weight (g)',
                hintText: 'Optional numeric value',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _numberValidator,
              ),
              Row(
                children: [
                  Expanded(
                    child: _AdminField(
                      controller: _ptController,
                      label: 'Pt PPM',
                      hintText: 'Optional',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminField(
                      controller: _pdController,
                      label: 'Pd PPM',
                      hintText: 'Optional',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminField(
                      controller: _rhController,
                      label: 'Rh PPM',
                      hintText: 'Optional',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_pendingImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          const _SectionLabel('PHOTOS ATTACHED'),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(
                    _pendingImages.first.bytes,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pendingImages.first.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pendingImages.length == 1
                            ? '1 image selected'
                            : '${_pendingImages.length} images selected',
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppColors.accent),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _AdminField(
          controller: _remarksController,
          label: 'Remarks',
          hintText: 'Optional',
          maxLines: 2,
        ),
        _AdminField(
          controller: _notesController,
          label: 'Internal notes',
          hintText: 'Optional',
          maxLines: 3,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBottomAction() {
    final isFinalStep = _step == 1;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _isSaving
              ? null
              : isFinalStep
              ? _submit
              : _continueToMetrics,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Icon(
                  isFinalStep ? Icons.save_outlined : Icons.arrow_forward,
                  size: 19,
                ),
          label: Text(
            _isSaving
                ? 'Saving…'
                : isFinalStep
                ? 'SAVE CONVERTER'
                : 'CONTINUE TO METRICS',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryOfOrigin() {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Country of Origin',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: palette.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'India',
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  ),
                ),
                Icon(Icons.public, color: palette.textMuted, size: 17),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _numberValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty && double.tryParse(text) == null) {
      return 'Use a number';
    }
    return null;
  }
}

class _PendingConverterImage {
  const _PendingConverterImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 132,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surfaceElevated,
          foregroundColor: palette.accent,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: palette.accent, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminField extends StatelessWidget {
  const _AdminField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            scrollPadding: const EdgeInsets.all(24),
            style: TextStyle(color: palette.textPrimary, fontSize: 13),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
              ),
              filled: true,
              fillColor: palette.surfaceSubtle,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          color: palette.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(color: palette.textMuted, fontSize: 10),
      ),
    );
  }
}
