import 'package:flutter/material.dart';

import '../services/brand_service.dart';
import '../services/converter_service.dart';
import 'catalog_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    this.converterService,
    this.brandService,
    this.isAdmin = false,
  });

  final ConverterService? converterService;
  final BrandService? brandService;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return CatalogScreen(
      converterService: converterService,
      brandService: brandService,
      searchMode: true,
      isAdmin: isAdmin,
    );
  }
}
