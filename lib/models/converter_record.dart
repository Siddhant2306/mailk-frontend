class ConverterRecord {
  const ConverterRecord({
    required this.id,
    required this.codeReference,
    this.converterCode = '',
    this.brandId,
    this.brandName,
    this.model,
    this.country,
    this.converterType,
    this.category,
    this.localLingo,
    this.monolithWeightGrams,
    this.markings = const [],
    this.images = const [],
    this.ptPpm,
    this.pdPpm,
    this.rhPpm,
    this.remarks,
    this.notes,
  });

  factory ConverterRecord.fromJson(
    Map<String, dynamic> json, {
    Map<int, String> brandsById = const {},
  }) {
    final id = _intValue(json['id'] ?? json['converter_id']);
    if (id == null) {
      throw const FormatException('A converter is missing its ID.');
    }

    final rawBrand = json['brand'] ?? json['make'];
    final nestedBrand = rawBrand is Map ? rawBrand : null;
    final brandId = _intValue(json['brand_id'] ?? nestedBrand?['id']);
    final brandName =
        _text(nestedBrand?['name']) ??
        _text(rawBrand) ??
        _text(json['brand_name']) ??
        (brandId == null ? null : brandsById[brandId]);

    return ConverterRecord(
      id: id,
      codeReference:
          _text(json['code_reference']) ??
          _text(json['reference']) ??
          _text(json['code']) ??
          '',
      converterCode: _text(json['converter_code']) ?? '',
      brandId: brandId,
      brandName: brandName,
      model: _text(json['model']),
      country:
          _text(json['country']) ??
          _text(json['country_of_origin']) ??
          _text(json['origin_country']),
      converterType: _text(json['converter_type']),
      category: _text(json['category']),
      localLingo: _text(json['local_lingo']),
      monolithWeightGrams: _number(
        json['monolith_weight_g'] ?? json['monolith_weight_grams'],
      ),
      markings: _strings(json['markings']),
      images: _strings(
        json['images'] ?? json['image_urls'] ?? json['image_url'],
      ),
      ptPpm: _number(json['pt_ppm']),
      pdPpm: _number(json['pd_ppm']),
      rhPpm: _number(json['rh_ppm']),
      remarks: _text(json['remarks']),
      notes: _text(json['notes']),
    );
  }

  final int id;
  final String codeReference;
  final String converterCode;
  final int? brandId;
  final String? brandName;
  final String? model;
  final String? country;
  final String? converterType;
  final String? category;
  final String? localLingo;
  final double? monolithWeightGrams;
  final List<String> markings;
  final List<String> images;
  final double? ptPpm;
  final double? pdPpm;
  final double? rhPpm;
  final String? remarks;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'code_reference': codeReference,
    'converter_code': converterCode,
    if (brandId != null) 'brand_id': brandId,
    if (brandName != null) 'brand_name': brandName,
    if (model != null) 'model': model,
    if (country != null) 'country': country,
    if (converterType != null) 'converter_type': converterType,
    if (category != null) 'category': category,
    if (localLingo != null) 'local_lingo': localLingo,
    if (monolithWeightGrams != null)
      'monolith_weight_grams': monolithWeightGrams,
    'markings': markings,
    'images': images,
    if (ptPpm != null) 'pt_ppm': ptPpm,
    if (pdPpm != null) 'pd_ppm': pdPpm,
    if (rhPpm != null) 'rh_ppm': rhPpm,
    if (remarks != null) 'remarks': remarks,
    if (notes != null) 'notes': notes,
  };
}

class ConverterCatalogPage {
  const ConverterCatalogPage({
    required this.converters,
    required this.hasMore,
    required this.pageSize,
    this.nextCursor,
  });

  factory ConverterCatalogPage.fromJson(
    dynamic responseData, {
    Map<int, String> brandsById = const {},
  }) {
    if (responseData is! Map) {
      throw const FormatException('Invalid converter catalogue response.');
    }

    final response = Map<String, dynamic>.from(responseData);
    dynamic rawConverters =
        response['items'] ??
        response['converters'] ??
        response['results'] ??
        response['data'] ??
        response['records'];
    var metadata = response;
    if (rawConverters is Map) {
      metadata = Map<String, dynamic>.from(rawConverters);
      rawConverters =
          metadata['items'] ??
          metadata['converters'] ??
          metadata['results'] ??
          metadata['records'];
    }
    if (rawConverters is! List) {
      throw const FormatException(
        'The converter catalogue response has no record list.',
      );
    }

    final pageSize = _intValue(metadata['page_size'] ?? metadata['pageSize']);
    final hasMore = metadata['has_more'] ?? metadata['hasMore'];
    if (pageSize == null || pageSize < 1 || hasMore is! bool) {
      throw const FormatException(
        'The converter catalogue response has invalid pagination metadata.',
      );
    }

    final rawNextCursor = metadata['next_cursor'] ?? metadata['nextCursor'];
    final nextCursor = rawNextCursor == null
        ? null
        : rawNextCursor is String || rawNextCursor is num
        ? rawNextCursor.toString().trim()
        : throw const FormatException(
            'The converter catalogue response has an invalid cursor.',
          );
    if (nextCursor != null && nextCursor.isEmpty) {
      throw const FormatException(
        'The converter catalogue response has an invalid cursor.',
      );
    }

    final converters = <ConverterRecord>[];
    for (final item in rawConverters) {
      if (item is! Map) {
        throw const FormatException(
          'The converter catalogue contains an invalid record.',
        );
      }
      converters.add(
        ConverterRecord.fromJson(
          Map<String, dynamic>.from(item),
          brandsById: brandsById,
        ),
      );
    }

    return ConverterCatalogPage(
      converters: List.unmodifiable(converters),
      hasMore: hasMore && nextCursor != null,
      nextCursor: nextCursor,
      pageSize: pageSize,
    );
  }

  final List<ConverterRecord> converters;
  final bool hasMore;
  final String? nextCursor;
  final int pageSize;

  Map<String, dynamic> toJson() => {
    'items': [for (final converter in converters) converter.toJson()],
    'next_cursor': nextCursor,
    'has_more': hasMore,
    'page_size': pageSize,
  };
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _number(dynamic value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

String? _text(dynamic value) {
  if (value is! String && value is! num) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _strings(dynamic value) {
  if (value is String) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is! List) {
    return const [];
  }

  final values = <String>[];
  for (final item in value) {
    final text = item is Map
        ? _text(item['url'] ?? item['image_url'] ?? item['src'])
        : _text(item);
    if (text != null) {
      values.add(text);
    }
  }
  return List.unmodifiable(values);
}
