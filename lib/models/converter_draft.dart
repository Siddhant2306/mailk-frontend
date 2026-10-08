class ConverterDraft {
  const ConverterDraft({
    required this.brandId,
    required this.codeReference,
    this.model,
    this.converterType,
    this.category,
    this.localLingo,
    this.monolithWeightGrams,
    this.ptPpm,
    this.pdPpm,
    this.rhPpm,
    this.markings = const [],
    this.images = const [],
    this.remarks,
    this.notes,
  });

  final int brandId;
  final String codeReference;
  final String? model;
  final String? converterType;
  final String? category;
  final String? localLingo;
  final double? monolithWeightGrams;
  final double? ptPpm;
  final double? pdPpm;
  final double? rhPpm;
  final List<String> markings;
  final List<String> images;
  final String? remarks;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'brand_id': brandId,
    'code_reference': codeReference,
    if (model != null) 'model': model,
    if (converterType != null) 'converter_type': converterType,
    if (category != null) 'category': category,
    if (localLingo != null) 'local_lingo': localLingo,
    if (monolithWeightGrams != null) 'monolith_weight_g': monolithWeightGrams,
    if (ptPpm != null) 'pt_ppm': ptPpm,
    if (pdPpm != null) 'pd_ppm': pdPpm,
    if (rhPpm != null) 'rh_ppm': rhPpm,
    'markings': markings,
    'images': images,
    if (remarks != null) 'remarks': remarks,
    if (notes != null) 'notes': notes,
  };
}
