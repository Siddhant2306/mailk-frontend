import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_palette.dart';
import '../models/car_brand.dart';
import '../models/converter_record.dart';
import '../services/authenticated_api_client.dart';
import '../services/brand_service.dart';
import '../services/converter_service.dart';
import '../widgets/profile/converter_form_sheet.dart';
import '../widgets/search/catalog_search_field.dart';
import 'converter_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    this.converterService,
    this.brandService,
    this.searchMode = false,
    this.initialBrandId,
    this.isAdmin = false,
  });

  final ConverterService? converterService;
  final BrandService? brandService;
  final bool searchMode;
  final int? initialBrandId;
  final bool isAdmin;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const _pageSize = 20;

  late final ConverterService _converterService;
  late final BrandService _brandService;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<ConverterRecord> _converters = [];
  List<CarBrand> _brands = [];
  int? _selectedBrandId;
  int _total = 0;
  int _page = 0;
  int _requestGeneration = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _brandLoadFailed = false;
  bool _paginationFailed = false;
  String? _initialError;

  Map<int, String> get _brandsById => {
    for (final brand in _brands)
      if (brand.id != null) brand.id!: brand.name,
  };

  @override
  void initState() {
    super.initState();
    _converterService = widget.converterService ?? ConverterService();
    _brandService = widget.brandService ?? BrandService();
    _selectedBrandId = widget.initialBrandId;
    _scrollController.addListener(_onScroll);
    _loadBrands();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadBrands({bool forceRefresh = false}) async {
    try {
      final brands = await _brandService.getConverterBrands(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _brands = brands.where((brand) => brand.id != null).toList();
        _brandLoadFailed = false;
      });
    } on DioException {
      if (mounted) {
        setState(() => _brandLoadFailed = true);
      }
    } on FormatException {
      if (mounted) {
        setState(() => _brandLoadFailed = true);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _requestGeneration++;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      _searchDebounce = null;
      _loadFirstPage();
    });
  }

  void _selectBrand(int? brandId) {
    if (_selectedBrandId == brandId) {
      return;
    }
    setState(() => _selectedBrandId = brandId);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage();
  }

  Future<void> _loadFirstPage({bool forceRefresh = false}) async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _converters = [];
      _total = 0;
      _page = 0;
      _hasMore = true;
      _isLoadingInitial = true;
      _isLoadingMore = false;
      _paginationFailed = false;
      _initialError = null;
    });

    try {
      final result = await _converterService.getConverters(
        page: 1,
        pageSize: _pageSize,
        search: _searchController.text,
        brandId: _selectedBrandId,
        brandsById: _brandsById,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _converters = _uniqueConverters(result.converters);
        _total = result.total;
        _page = result.page;
        _hasMore =
            result.hasMore &&
            result.converters.isNotEmpty &&
            _converters.length < _total;
        _isLoadingInitial = false;
      });
    } on Object catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _isLoadingInitial = false;
        _initialError = _messageFor(error);
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingInitial ||
        _isLoadingMore ||
        !_hasMore ||
        _initialError != null) {
      return;
    }

    final requestGeneration = _requestGeneration;
    final nextPage = _page + 1;
    setState(() {
      _isLoadingMore = true;
      _paginationFailed = false;
    });

    try {
      final result = await _converterService.getConverters(
        page: nextPage,
        pageSize: _pageSize,
        search: _searchController.text,
        brandId: _selectedBrandId,
        brandsById: _brandsById,
      );
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _converters = _uniqueConverters([..._converters, ...result.converters]);
        _total = result.total;
        _page = result.page;
        _hasMore =
            result.hasMore &&
            result.converters.isNotEmpty &&
            _converters.length < _total;
        _isLoadingMore = false;
      });
    } on Object {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
        _paginationFailed = true;
      });
    }
  }

  List<ConverterRecord> _uniqueConverters(Iterable<ConverterRecord> records) {
    final seenIds = <int>{};
    return records.where((record) => seenIds.add(record.id)).toList();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 240) {
      _loadNextPage();
    }
  }

  String _messageFor(Object error) {
    if (error is AuthenticationRequiredException) {
      return 'Sign in to browse the converter catalogue.';
    }
    if (error is DioException &&
        (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403)) {
      return error.response?.statusCode == 403
          ? 'The backend denied access to the converter catalogue. Check the account status and access policy.'
          : 'Your session could not access the catalogue. Please sign in again.';
    }
    if (error is FormatException) {
      return 'The converter catalogue response could not be read.';
    }
    return 'Unable to load converters. Check your connection and retry.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final selectedBrand = _selectedBrandId == null
        ? null
        : _brandName(_selectedBrandId!);

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: palette.surface,
      onRefresh: () async {
        await Future.wait([
          _loadBrands(forceRefresh: true),
          _loadFirstPage(forceRefresh: true),
        ]);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _CatalogHeader(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                searchMode: widget.searchMode,
                isAdmin: widget.isAdmin,
                onAddConverter: _openAddConverter,
              ),
            ),
          ),
          if (!widget.searchMode)
            SliverToBoxAdapter(
              child: _BrandFilters(
                brands: _brands,
                selectedBrandId: _selectedBrandId,
                loadFailed: _brandLoadFailed,
                onSelected: _selectBrand,
                onRetry: _loadBrands,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isLoadingInitial && _initialError == null
                          ? 'Loading converters…'
                          : '$_total ${_total == 1 ? 'converter' : 'converters'}',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (selectedBrand != null)
                    Text(
                      'Filter: $selectedBrand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isLoadingInitial)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverToBoxAdapter(child: _CatalogLoadingState()),
            )
          else if (_initialError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CatalogErrorState(
                message: _initialError!,
                onRetry: _loadFirstPage,
              ),
            )
          else if (_converters.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _CatalogEmptyState(),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ConverterCard(
                      converter: _converters[index],
                      brandName:
                          _converters[index].brandName ??
                          (_converters[index].brandId == null
                              ? null
                              : _brandName(_converters[index].brandId!)),
                      searchQuery: _searchController.text.trim(),
                      onTap: () => _openDetails(_converters[index]),
                    ),
                  ),
                  childCount: _converters.length,
                ),
              ),
            ),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 2, 0, 18),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              )
            else if (_paginationFailed)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: TextButton.icon(
                      onPressed: _loadNextPage,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Could not load more. Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.accent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String? _brandName(int brandId) {
    for (final brand in _brands) {
      if (brand.id == brandId) {
        return brand.name;
      }
    }
    return null;
  }

  Future<void> _openDetails(ConverterRecord converter) async {
    final wasDeleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ConverterDetailScreen(
          converterId: converter.id,
          converterService: _converterService,
          brandService: _brandService,
          brandsById: _brandsById,
          isAdmin: widget.isAdmin,
          onChanged: () {
            if (mounted) {
              _loadBrands(forceRefresh: true);
              _loadFirstPage(forceRefresh: true);
            }
          },
        ),
      ),
    );
    if (!mounted || wasDeleted != true) {
      return;
    }
    await Future.wait([
      _loadBrands(forceRefresh: true),
      _loadFirstPage(forceRefresh: true),
    ]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Converter deleted.')),
      );
    }
  }

  Future<void> _openAddConverter() async {
    if (!widget.isAdmin) {
      return;
    }
    final converterId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ConverterFormSheet(
        converterService: _converterService,
        brandService: _brandService,
      ),
    );
    if (!mounted || converterId == null) {
      return;
    }
    await Future.wait([
      _loadBrands(forceRefresh: true),
      _loadFirstPage(forceRefresh: true),
    ]);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Converter #$converterId was added.')),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.searchMode,
    required this.isAdmin,
    required this.onAddConverter,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool searchMode;
  final bool isAdmin;
  final VoidCallback onAddConverter;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
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
        Row(
          children: [
            Expanded(
              child: Text(
                searchMode ? 'Search' : 'Catalog',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!searchMode && isAdmin)
              IconButton(
                key: const ValueKey('catalog-add-converter'),
                onPressed: onAddConverter,
                tooltip: 'Add converter',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add, color: palette.accent),
              ),
          ],
        ),
        const SizedBox(height: 13),
        CatalogSearchField(
          controller: searchController,
          hintText: 'Search code, marking, make or model',
          onChanged: onSearchChanged,
        ),
      ],
    );
  }
}

class _BrandFilters extends StatelessWidget {
  const _BrandFilters({
    required this.brands,
    required this.selectedBrandId,
    required this.loadFailed,
    required this.onSelected,
    required this.onRetry,
  });

  final List<CarBrand> brands;
  final int? selectedBrandId;
  final bool loadFailed;
  final ValueChanged<int?> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 1),
        children: [
          _BrandFilterChip(
            label: 'All',
            selected: selectedBrandId == null,
            onTap: () => onSelected(null),
          ),
          for (final brand in brands)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _BrandFilterChip(
                label: brand.name,
                selected: selectedBrandId == brand.id,
                onTap: () => onSelected(brand.id),
              ),
            ),
          if (loadFailed && brands.isEmpty)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Retry brands', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }
}

class _BrandFilterChip extends StatelessWidget {
  const _BrandFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: selected ? palette.accentSoft : palette.surfaceSubtle,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? palette.accent : palette.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConverterCard extends StatelessWidget {
  const _ConverterCard({
    required this.converter,
    required this.brandName,
    required this.searchQuery,
    required this.onTap,
  });

  final ConverterRecord converter;
  final String? brandName;
  final String searchQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final marking = converter.markings.isEmpty
        ? '—'
        : converter.markings.join(', ');
    final code = converter.converterCode.isNotEmpty
          ? converter.converterCode
          : (converter.codeReference.isNotEmpty
          ? converter.codeReference
          : 'Converter ${converter.id}');
    final weight = converter.monolithWeightGrams == null
        ? '—'
        : _formatWeight(converter.monolithWeightGrams!);

    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageSize = constraints.maxWidth < 340 ? 108.0 : 128.0;
              return Row(
                children: [
                  _ConverterImage(
                    url: converter.images.isEmpty
                        ? null
                        : converter.images.first,
                    size: imageSize,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            color: Color(0xFFFFB02E),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _CatalogField(
                          label: 'Reference:',
                          value:  converter.codeReference.isNotEmpty ? converter.codeReference : '—',
                          searchQuery: searchQuery,
                          valueColor: palette.accent,
                          emphasized: true,
                        ),
                        _CatalogField(
                          label: 'Make:',
                          value: brandName ?? '—',
                          searchQuery: searchQuery,
                        ),
                        _CatalogField(
                          label: 'Model:',
                          value: converter.model ?? '—',
                          searchQuery: searchQuery,
                        ),
                        _CatalogField(
                          label: 'Marking:',
                          value: marking,
                          searchQuery: searchQuery,
                        ),
                        _CatalogField(
                          label: 'Country:',
                          value: converter.country ?? 'India',
                          searchQuery: searchQuery,
                        ),
                        _CatalogField(
                          label: 'Weight:',
                          value: weight,
                          searchQuery: searchQuery,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: palette.textMuted,
                    size: 22,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogField extends StatelessWidget {
  const _CatalogField({
    required this.label,
    required this.value,
    required this.searchQuery,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String searchQuery;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: _HighlightedText(
              value: value,
              query: searchQuery,
              style: TextStyle(
                color: valueColor ?? palette.textPrimary,
                fontSize: 12,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.value,
    required this.query,
    required this.style,
  });

  final String value;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim();
    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toSet();
    final lowerValue = value.toLowerCase();
    final matches = <(int, int)>[];
    for (final term in terms) {
      final lowerTerm = term.toLowerCase();
      var start = 0;
      while (start < lowerValue.length) {
        final index = lowerValue.indexOf(lowerTerm, start);
        if (index < 0) break;
        matches.add((index, index + lowerTerm.length));
        start = index + lowerTerm.length;
      }
    }
    if (matches.isEmpty) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    matches.sort((left, right) => left.$1.compareTo(right.$1));
    final mergedMatches = <(int, int)>[];
    for (final match in matches) {
      if (mergedMatches.isNotEmpty && match.$1 <= mergedMatches.last.$2) {
        final previous = mergedMatches.removeLast();
        mergedMatches.add((previous.$1, previous.$2 > match.$2
            ? previous.$2
            : match.$2));
      } else {
        mergedMatches.add(match);
      }
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in mergedMatches) {
      if (match.$1 > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.$1)));
      }
      spans.add(
        TextSpan(
          text: value.substring(match.$1, match.$2),
          style: style.copyWith(
            backgroundColor: const Color(0xFFFFE082),
            color: const Color(0xFF29251A),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      cursor = match.$2;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ConverterImage extends StatelessWidget {
  const _ConverterImage({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final resolvedUrl = _resolveImageUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: const ValueKey('catalog-converter-image'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF397A9B)
                  : const Color(0xFFD7E8EE),
              palette.surfaceSubtle,
            ],
          ),
        ),
        child: resolvedUrl == null
            ? const _ImagePlaceholder()
            : Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ImagePlaceholder(),
              ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Icon(
        Icons.precision_manufacturing_outlined,
        size: 32,
        color: palette.textMuted,
      ),
    );
  }
}

class _CatalogLoadingState extends StatelessWidget {
  const _CatalogLoadingState();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 137,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: palette.accent,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: palette.textMuted,
              size: 31,
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No converters found.',
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

String _formatWeight(double weight) {
  final value = weight == weight.roundToDouble()
      ? weight.toStringAsFixed(0)
      : weight.toString();
  return '${value}g';
}

String? _resolveImageUrl(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value.trim());
  if (uri == null) {
    return null;
  }
  if (uri.hasScheme) {
    return uri.toString();
  }
  return Uri.parse(ApiConfig.baseUrl).resolveUri(uri).toString();
}
