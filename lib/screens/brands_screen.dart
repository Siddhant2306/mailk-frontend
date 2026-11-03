import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../models/car_brand.dart';
import '../services/brand_service.dart';
import '../widgets/brands/brand_card.dart';
import '../widgets/search/catalog_search_field.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key, this.brandService, this.onBrandSelected});

  final BrandService? brandService;
  final ValueChanged<CarBrand>? onBrandSelected;

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
    _restoreBrandsThenRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreBrandsThenRefresh() async {
    final cachedBrands = await _brandService.getCachedConverterBrands();
    if (!mounted) {
      return;
    }
    if (cachedBrands == null) {
      await _loadBrands();
      return;
    }

    setState(() {
      _brands = _displayBrands(cachedBrands);
      _isLoading = false;
      _errorMessage = null;
    });
    _loadBrands(keepExisting: true);
  }

  Future<void> _loadBrands({
    bool forceRefresh = false,
    bool keepExisting = false,
  }) async {
    setState(() {
      _isLoading = !keepExisting;
      _errorMessage = null;
    });

    try {
      final brands = await _brandService.getConverterBrands(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _brands = _displayBrands(brands);
        _isLoading = false;
      });
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        _setLoadError('Sign in again to load brands.');
      } else if (statusCode == 403) {
        _setLoadError(
          'The backend denied access to brands. Check the account status and access policy.',
        );
      } else {
        _setLoadError(
          'Unable to load brands. Check your connection and retry.',
        );
      }
    } on FormatException {
      _setLoadError('The brand catalogue could not be read. Please retry.');
    } catch (_) {
      _setLoadError('Unable to load brands. Please try again.');
    }
  }

  List<CarBrand> _displayBrands(Iterable<CarBrand> brands) {
    return brands
        // The backend's built-in Unknown brand intentionally has no logo, but
        // it must remain visible so unclassified converters are discoverable.
        .where(
          (brand) =>
              brand.logoUrl?.trim().isNotEmpty == true || brand.isUnknown,
        )
        .toList()
      ..sort((first, second) {
        final countOrder = (second.converterCount ?? 0).compareTo(
          first.converterCount ?? 0,
        );
        return countOrder != 0 ? countOrder : first.name.compareTo(second.name);
      });
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
    final palette = AppPalette.of(context);
    final brands = _filteredBrands;
    return RefreshIndicator(
      color: palette.accent,
      backgroundColor: palette.surface,
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
                converterCount: _brands.fold<int>(
                  0,
                  (total, brand) => total + (brand.converterCount ?? 0),
                ),
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
                  (context, index) => BrandCard(
                    brand: brands[index],
                    onTap: widget.onBrandSelected == null
                        ? null
                        : () => widget.onBrandSelected!(brands[index]),
                  ),
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
    required this.converterCount,
    required this.searchController,
    required this.onSearchChanged,
  });

  final int brandCount;
  final int converterCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MALIK ENTERPRISES',
          style: TextStyle(
            color: palette.accent,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Brands',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          brandCount == 0
              ? 'Loading catalogue…'
              : '$brandCount brands • $converterCount converters',
          style: TextStyle(color: palette.textMuted, fontSize: 11),
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
    final palette = AppPalette.of(context);
    return Center(
      child: CircularProgressIndicator(color: palette.accent, strokeWidth: 2),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: palette.textMuted, size: 34),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
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
    final palette = AppPalette.of(context);
    return Center(
      child: Text(
        'No brands match “${query.trim()}”.',
        style: TextStyle(color: palette.textMuted, fontSize: 13),
      ),
    );
  }
}
