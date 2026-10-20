import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../models/car_brand.dart';
import '../../models/converter_draft.dart';
import '../../models/converter_record.dart';
import '../../services/brand_service.dart';
import '../../services/converter_service.dart';

class ConverterFormSheet extends StatefulWidget {
  const ConverterFormSheet({
    required this.converterService,
    this.converter,
    this.brandService,
    super.key,
  });

  final ConverterService converterService;
  final ConverterRecord? converter;
  final BrandService? brandService;

  @override
  State<ConverterFormSheet> createState() => _ConverterFormSheetState();
}

class _ConverterFormSheetState extends State<ConverterFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final BrandService _brandService;
  final _brandIdController = TextEditingController();
  int? _originalBrandId;
  String? _originalBrandName;
  final _codeController = TextEditingController();
  final _modelController = TextEditingController();
  final _typeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _localLingoController = TextEditingController();
  final _weightController = TextEditingController();
  final _ptController = TextEditingController();
  final _pdController = TextEditingController();
  final _rhController = TextEditingController();
  final List<TextEditingController> _markingControllers = [
    TextEditingController(),
  ];
  final TextEditingController _markingInputController = TextEditingController();
  final List<String> _markings = [];
  final List<_FormConverterImage> _images = [];
  final _remarksController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  var _isSaving = false;
  var _isPickingImage = false;
  var _step = 0;
  var _isLoadingBrands = true;
  List<CarBrand> _brands = const [];
  String? _brandLoadError;
  String? _imageError;
  String? _uploadStatus;

  @override
  void initState() {
    super.initState();
    _brandService = widget.brandService ?? BrandService();
    final converter = widget.converter;
    if (converter != null) {
      _brandIdController.text = converter.brandId?.toString() ?? '';
      _originalBrandId = converter.brandId;
      _originalBrandName = converter.brandName;
      _codeController.text = converter.codeReference;
      _modelController.text = converter.model ?? '';
      _typeController.text = converter.converterType ?? '';
      _categoryController.text = converter.category ?? '';
      _localLingoController.text = converter.localLingo ?? '';
      _weightController.text = converter.monolithWeightGrams?.toString() ?? '';
      _ptController.text = converter.ptPpm?.toString() ?? '';
      _pdController.text = converter.pdPpm?.toString() ?? '';
      _rhController.text = converter.rhPpm?.toString() ?? '';
      _markings.addAll(converter.markings);
      _images.addAll(converter.images.map(_FormConverterImage.fromUrl));
      _remarksController.text = converter.remarks ?? '';
      _notesController.text = converter.notes ?? '';
    }
    _loadBrands();
  }

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
      _remarksController,
      _notesController,
      ..._markingControllers,
    ]) {
      controller.dispose();
    }
    _markingInputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_images.length > 4) {
      setState(() => _imageError = 'A converter can have at most 4 images.');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _imageError = null;
      _uploadStatus = null;
    });
    try {
      final imageUrls = <String>[];
      for (var index = 0; index < _images.length; index++) {
        final image = _images[index];
        final existingUrl = image.url;
        if (existingUrl != null) {
          imageUrls.add(existingUrl);
          continue;
        }

        setState(
          () => _uploadStatus =
              'Uploading image ${index + 1} of ${_images.length}…',
        );
        final uploadedUrl = await widget.converterService.uploadConverterImage(
          bytes: image.bytes!,
          fileName: image.fileName!,
        );
        imageUrls.add(uploadedUrl);
        _images[index] = _FormConverterImage.fromUrl(uploadedUrl);
      }

      setState(() => _uploadStatus = 'Saving converter…');
      final draft = ConverterDraft(
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
        markings: _markings,
        images: imageUrls,
        remarks: _optional(_remarksController),
        notes: _optional(_notesController),
      );
      final converterId = widget.converter == null
          ? await widget.converterService.createConverter(draft)
          : await _updateConverter(draft);
      if (mounted) {
        Navigator.pop(context, converterId);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _imageError = widget.converterService.messageFor(error);
          _uploadStatus = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.converterService.messageFor(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadStatus = null;
        });
      }
    }
  }

  Future<int> _updateConverter(ConverterDraft draft) async {
    final converter = widget.converter!;
    await widget.converterService.updateConverter(converter.id, draft);
    return converter.id;
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  double? _optionalNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  Future<void> _pickDeviceImages({int? slotIndex}) async {
    final isReplacing = slotIndex != null && slotIndex < _images.length;
    final capacity = isReplacing ? 1 : 4 - _images.length;
    if (capacity <= 0) {
      setState(() => _imageError = 'Remove an image before adding another.');
      return;
    }
    setState(() {
      _isPickingImage = true;
      _imageError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || !mounted) return;
      if (result.files.isEmpty) return;

      if (result.files.length > capacity) {
        throw const FormatException(
          'Select no more than the available image slots.',
        );
      }
      final selectedImages = <_FormConverterImage>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw const FormatException('The selected image could not be read.');
        }
        selectedImages.add(
          _FormConverterImage.pending(bytes: bytes, fileName: file.name),
        );
      }
      setState(() {
        if (isReplacing) {
          _images[slotIndex] = selectedImages.single;
        } else {
          _images.addAll(selectedImages);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _imageError = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select images: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _captureImage({int? slotIndex}) async {
    if (slotIndex == null && _images.length >= 4) {
      setState(() => _imageError = 'Remove an image before adding another.');
      return;
    }
    setState(() {
      _isPickingImage = true;
      _imageError = null;
    });
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        final selectedImage = _FormConverterImage.pending(
          bytes: bytes,
          fileName: image.name,
        );
        if (slotIndex != null && slotIndex < _images.length) {
          _images[slotIndex] = selectedImage;
        } else {
          _images.add(selectedImage);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _imageError = error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _imageError = null;
    });
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoadingBrands = true;
      _brandLoadError = null;
    });
    try {
      final brands = await _brandService.getConverterBrands(forceRefresh: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _brands = brands;
        _isLoadingBrands = false;
      });
    } on DioException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingBrands = false;
        _brandLoadError = 'Unable to load brands. Check your connection.';
      });
    } on FormatException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingBrands = false;
        _brandLoadError = 'The brand catalogue could not be read.';
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingBrands = false;
        _brandLoadError = 'Unable to load brands. Please try again.';
      });
    }
  }

  void _goToIdentification() {
    setState(() => _step = 0);
  }

  void _addMarking() {
    final marking = _markingInputController.text.trim();

    if (marking.isEmpty) return;

    setState(() {
      if (!_markings.contains(marking)) {
        _markings.add(marking);
      }
      _markingInputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - keyboardInset;
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      key: const ValueKey('converter-form-sheet'),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: availableHeight * 0.94 + keyboardInset,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIdentificationStep(),
                          _buildMetricsStep(),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomAction(),
                ],
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
                    widget.converter == null
                        ? 'Add Converter'
                        : 'Edit Converter',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandSelector() {
    final palette = AppPalette.of(context);
    final brandsById = <int, CarBrand>{};
    for (final brand in _brands) {
      final id = brand.id;
      if (id != null) {
        brandsById.putIfAbsent(id, () => brand);
      }
    }

    final selectedBrandId = int.tryParse(_brandIdController.text.trim());
    final brandOptions = brandsById.values.toList(growable: false);
    final brandIds = brandsById.keys.toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make / Brand *',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Autocomplete<CarBrand>(
            key: const ValueKey('converter-brand-selector'),
            initialValue: TextEditingValue(
              text: widget.converter?.brandName ?? '',
            ),
            displayStringForOption: (brand) => brand.name,
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();
              return brandOptions.where(
                (brand) =>
                    query.isEmpty ||
                    brand.name.toLowerCase().contains(query) ||
                    brand.slug.toLowerCase().contains(query),
              );
            },
            onSelected: (brand) {
              _brandIdController.text = brand.id.toString();
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !_isSaving && !_isLoadingBrands,
                    onChanged: (value) {
                      final query = value.trim().toLowerCase();
                      final matchingBrand = brandOptions.where(
                        (brand) => brand.name.toLowerCase() == query,
                      );
                      if (matchingBrand.isNotEmpty) {
                        _brandIdController.text = matchingBrand.first.id
                            .toString();
                      } else if (value.trim() == _originalBrandName &&
                          _originalBrandId != null) {
                        _brandIdController.text = _originalBrandId.toString();
                      } else {
                        _brandIdController.clear();
                      }
                    },
                    validator: (_) =>
                        int.tryParse(_brandIdController.text.trim()) == null
                        ? 'Select a brand from the loaded list'
                        : null,
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      hintText: _isLoadingBrands
                          ? 'Loading brands…'
                          : 'Type or select a brand',
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
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width - 64,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final brand = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(brand.name),
                            onTap: () => onSelected(brand),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isLoadingBrands) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_brandLoadError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _brandLoadError!,
                    style: TextStyle(
                      color: AppPalette.of(context).textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _loadBrands,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ] else if (brandOptions.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'No brands are available. Retry to load the brand catalogue.',
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSaving ? null : _loadBrands,
                child: const Text('Retry'),
              ),
            ),
          ],
          if (!_isLoadingBrands &&
              selectedBrandId != null &&
              !brandIds.contains(selectedBrandId)) ...[
            const SizedBox(height: 4),
            Text(
              'The existing brand is not in the loaded list; leaving it unchanged preserves its database ID.',
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    final palette = AppPalette.of(context);
    final image = _images[index];
    return InkWell(
      onTap: _isSaving || _isPickingImage
          ? null
          : () => _pickDeviceImages(slotIndex: index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.url case final url?)
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes == null
                              ? null
                              : progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!,
                          strokeWidth: 2,
                          color: palette.accent,
                        ),
                      ),
                errorBuilder: (_, _, _) => ColoredBox(
                  color: palette.surfaceSubtle,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: palette.textMuted,
                  ),
                ),
              )
            else
              Image.memory(image.bytes!, fit: BoxFit.cover),
            Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                tooltip: 'Remove image ${index + 1}',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : () => _removeImage(index),
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 6,
              right: 6,
              child: Text(
                image.fileName ?? 'Current image',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentificationStep() {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('PHOTOS'),
            Text(
              '${_images.length}/4 selected',
              style: TextStyle(color: palette.textMuted, fontSize: 11),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _ImageSourceCard(
                icon: Icons.photo_library_outlined,
                title: 'Gallery',
                subtitle: 'Pick from storage',
                onTap: _isSaving || _isPickingImage || _images.length >= 4
                    ? null
                    : () => _pickDeviceImages(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ImageSourceCard(
                icon: Icons.camera_alt_outlined,
                title: 'Photo',
                subtitle: 'Take a photo',
                onTap: _isSaving || _isPickingImage || _images.length >= 4
                    ? null
                    : () => _captureImage(),
              ),
            ),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) => _buildImagePreview(index),
          ),
        ],
        if (_isPickingImage) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 2,
            color: AppPalette.of(context).accent,
            backgroundColor: AppPalette.of(context).border,
          ),
        ],
        if (_imageError != null) ...[
          const SizedBox(height: 8),
          Text(
            _imageError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 11,
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
        _buildBrandSelector(),
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
              'Ceramic + DPF',
              'Metallic + DPF',
              'Ceramic',
              'Metallic',
              'DPF',
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _AdminField(
                    controller: _markingInputController,
                    label: 'Markings & Stamp Codes',
                    hintText: 'e.g., ESH 72, 18160-RNA',
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _addMarking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.add, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _markings.map((marking) {
                return Chip(
                  label: Text(marking),
                  onDeleted: () {
                    setState(() {
                      _markings.remove(marking);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
    final palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_uploadStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _uploadStatus!,
              style: TextStyle(color: palette.textSecondary, fontSize: 11),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
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
                  : const Icon(Icons.save_outlined, size: 19),
              label: Text(
                _isSaving
                    ? 'Saving…'
                    : widget.converter == null
                    ? 'SAVE CONVERTER'
                    : 'SAVE CHANGES',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
        ),
      ],
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

class _FormConverterImage {
  const _FormConverterImage._({this.url, this.bytes, this.fileName});

  factory _FormConverterImage.fromUrl(String url) =>
      _FormConverterImage._(url: url);

  factory _FormConverterImage.pending({
    required Uint8List bytes,
    required String fileName,
  }) => _FormConverterImage._(bytes: bytes, fileName: fileName);

  final String? url;
  final Uint8List? bytes;
  final String? fileName;
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
              hintStyle: TextStyle(color: palette.textMuted, fontSize: 12),
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

class _ImageSourceCard extends StatelessWidget {
  const _ImageSourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 164,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: palette.border),
                ),
                child: Icon(icon, color: palette.accent, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
