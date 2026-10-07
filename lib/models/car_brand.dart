class CarBrand {
  const CarBrand({
    required this.slug,
    required this.name,
    required this.logoUrl,
  });

  factory CarBrand.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String?;
    final name = json['name'] as String?;
    if (slug == null ||
        slug.trim().isEmpty ||
        name == null ||
        name.trim().isEmpty) {
      throw const FormatException('A brand is missing its slug or name.');
    }

    final logo = json['logo'] as String?;
    return CarBrand(
      slug: slug.trim(),
      name: name.trim(),
      logoUrl: logo == null || logo.trim().isEmpty ? null : logo.trim(),
    );
  }

  final String slug;
  final String name;
  final String? logoUrl;

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'name': name,
    'logo': logoUrl,
  };
}
