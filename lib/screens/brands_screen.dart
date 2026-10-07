import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/car_brand.dart';
import '../services/brand_service.dart';
import '../widgets/brands/brand_card.dart';
import '../widgets/search/catalog_search_field.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key, this.brandService});

  final BrandService? brandService;

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  late final BrandService _brandService;
  final _searchController = TextEditingController();

  var _brands = <CarBrand>[];
  var _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _brandService = widget.brandService ?? BrandService();
    _loadBrands();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final brands = await _brandService.getBrands(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }
      setState(() {
        // The catalogue design relies on a recognisable brand mark. Records
        // without a logo are intentionally not presented until the API has
        // one available for them.
        _brands = brands.where((brand) => brand.logoUrl != null).toList();
        _isLoading = false;
      });
    } on DioException {
      _setLoadError('Unable to load brands. Check your connection and retry.');
    } on FormatException {
      _setLoadError('The brand catalogue could not be read. Please retry.');
    } catch (_) {
      _setLoadError('Unable to load brands. Please try again.');
    }
  }

  void _setLoadError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  List<CarBrand> get _filteredBrands {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _brands;
    }
    return _brands
        .where(
          (brand) =>
              brand.name.toLowerCase().contains(query) ||
              brand.slug.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final brands = _filteredBrands;
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => _loadBrands(forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            sliver: SliverToBoxAdapter(
              child: _BrandsHeader(
                brandCount: _brands.length,
                searchController: _searchController,
                onSearchChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: _LoadingState())
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: _ErrorState(
                message: _errorMessage!,
                onRetry: () => _loadBrands(forceRefresh: true),
              ),
            )
          else if (brands.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(query: _searchController.text),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => BrandCard(brand: brands[index]),
                  childCount: brands.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BrandsHeader extends StatelessWidget {
  const _BrandsHeader({
    required this.brandCount,
    required this.searchController,
    required this.onSearchChanged,
  });

  final int brandCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MALIK ENTERPRISES',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Brands',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          brandCount == 0 ? 'Loading catalogue…' : '$brandCount brands',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        CatalogSearchField(
          controller: searchController,
          hintText: 'Search auto brands, codes…',
          onChanged: onSearchChanged,
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No brands match “${query.trim()}”.',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}
