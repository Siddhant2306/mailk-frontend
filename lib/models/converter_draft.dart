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

  Map<String, dynamic> toJson({bool includeNulls = false}) => {
    'brand_id': brandId,
    'code_reference': codeReference,
    if (includeNulls || model != null) 'model': model,
    if (includeNulls || converterType != null) 'converter_type': converterType,
    if (includeNulls || category != null) 'category': category,
    if (includeNulls || localLingo != null) 'local_lingo': localLingo,
    if (includeNulls || monolithWeightGrams != null)
      'monolith_weight_g': monolithWeightGrams,
    if (includeNulls || ptPpm != null) 'pt_ppm': ptPpm,
    if (includeNulls || pdPpm != null) 'pd_ppm': pdPpm,
    if (includeNulls || rhPpm != null) 'rh_ppm': rhPpm,
    'markings': markings,
    'images': images,
    if (includeNulls || remarks != null) 'remarks': remarks,
    if (includeNulls || notes != null) 'notes': notes,
  };
}
