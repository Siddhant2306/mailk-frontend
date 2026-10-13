class CarBrand {
  const CarBrand({
    this.id,
    this.converterCount,
    required this.slug,
    required this.name,
    required this.logoUrl,
  });

  factory CarBrand.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString();
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('A brand is missing its name.');
    }

    final rawSlug =
        json['slug']?.toString() ?? json['external_id']?.toString();
    final slug = rawSlug == null || rawSlug.trim().isEmpty
        ? name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-')
        : rawSlug.trim();
    final rawId = json['id'] ?? json['brand_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final rawConverterCount = json['converter_count'];
    final converterCount = rawConverterCount is int
        ? rawConverterCount
        : int.tryParse(rawConverterCount?.toString() ?? '');
    final logo = (json['logo'] ?? json['logo_url'])?.toString();
    return CarBrand(
      id: id,
      converterCount: converterCount,
      slug: slug,
      name: name.trim(),
      logoUrl: logo == null || logo.trim().isEmpty ? null : logo.trim(),
    );
  }

  final int? id;
  final int? converterCount;
  final String slug;
  final String name;
  final String? logoUrl;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (converterCount != null) 'converter_count': converterCount,
    'slug': slug,
    'name': name,
    'logo': logoUrl,
  };
}
