import 'package:flutter/material.dart';

import '../widgets/home/dashboard_header.dart';
import '../widgets/home/market_chart.dart';
import '../widgets/home/market_period_selector.dart';
import '../widgets/home/metal_price_grid.dart';
import '../widgets/navigation.dart';
import '../core/theme/app_palette.dart';
import '../models/app_user.dart';
import '../models/market_models.dart';
import '../models/metal_price.dart';
import '../services/brand_service.dart';
import '../services/admin_user_service.dart';
import '../services/converter_service.dart';
import '../services/metal_service.dart';
import 'brands_screen.dart';
import 'admin_profile_screen.dart';
import 'catalog_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.metalService,
    this.brandService,
    this.converterService,
    this.currentUser,
    this.adminUserService,
  });

  final MetalService? metalService;
  final BrandService? brandService;
  final ConverterService? converterService;
  final AppUser? currentUser;
  final AdminUserService? adminUserService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MetalService _metalService;

  var _selectedNavIndex = 0;
  int? _catalogBrandId;
  var _selectedPeriod = MarketPeriod.tenDays;
  var _selectedMetal = MetalType.platinum;
  var _selectedUnit = PriceUnit.inr;
  var _snapshot = MarketSnapshot.empty();
  var _isChartLoading = true;
  var _isPriceLoading = true;
  var _hasLoadedPrices = false;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _metalService = widget.metalService ?? MetalService();
    _loadMarketData(reloadLivePrices: true);
  }

  Future<void> _loadMarketData({
    required bool reloadLivePrices,
    bool forceRefresh = false,
  }) async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _isChartLoading = true;
        if (reloadLivePrices) {
          _isPriceLoading = true;
        }
      });
    }

    // Keep the two request groups independent. The previous implementation
    // waited for every history endpoint before showing a single live card.
    // Starting both here gives the chart and the price cards their own loading
    // lifecycle, so either can render as soon as its data arrives.
    final requests = <Future<void>>[
      _loadHistory(requestId, forceRefresh: forceRefresh),
    ];
    if (reloadLivePrices) {
      requests.add(_loadLiveQuotes(requestId, forceRefresh: forceRefresh));
    }
    await Future.wait(requests);
  }

  Future<void> _loadLiveQuotes(
    int requestId, {
    required bool forceRefresh,
  }) async {
    try {
      final quotes = await _metalService.getLiveQuotes(
        unit: _selectedUnit,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _snapshot = _selectedUnit == PriceUnit.inr
            ? _snapshot.copyWith(inrQuotes: quotes)
            : _snapshot.copyWith(usdQuotes: quotes);
        _isPriceLoading = false;
        _hasLoadedPrices = true;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _isPriceLoading = false;
        _hasLoadedPrices = true;
      });
    }
  }

  Future<void> _loadHistory(int requestId, {required bool forceRefresh}) async {
    try {
      final history = await _metalService.getHistoryForMetal(
        metal: _selectedMetal,
        days: _selectedPeriod.days,
        unit: _selectedUnit,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        final histories = _selectedUnit == PriceUnit.inr
            ? Map<MetalType, List<MetalPrice>>.from(_snapshot.inrHistory)
            : Map<MetalType, List<MetalPrice>>.from(_snapshot.usdHistory);
        histories[_selectedMetal] = history;
        _snapshot = _selectedUnit == PriceUnit.inr
            ? _snapshot.copyWith(inrHistory: histories)
            : _snapshot.copyWith(usdHistory: histories);
        _isChartLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() => _isChartLoading = false);
    }
  }

  void _selectPeriod(MarketPeriod period) {
    if (period == _selectedPeriod) {
      return;
    }
    setState(() => _selectedPeriod = period);
    _loadMarketData(reloadLivePrices: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: switch (_selectedNavIndex) {
          0 => _buildDashboard(),
          1 => BrandsScreen(
            brandService: widget.brandService,
            onBrandSelected: (brand) {
              if (brand.id == null) {
                return;
              }
              setState(() {
                _catalogBrandId = brand.id;
                _selectedNavIndex = 3;
              });
            },
          ),
          2 => SearchScreen(
            converterService: widget.converterService,
            brandService: widget.brandService,
            isAdmin: widget.currentUser?.isAdmin == true,
          ),
          3 => CatalogScreen(
            converterService: widget.converterService,
            brandService: widget.brandService,
            initialBrandId: _catalogBrandId,
            isAdmin: widget.currentUser?.isAdmin == true,
          ),
          4 when widget.currentUser != null => AdminProfileScreen(
            user: widget.currentUser!,
            adminUserService: widget.adminUserService,
          ),
          4 => const AdminRestrictedScreen(),
          _ => _PlaceholderPage(index: _selectedNavIndex),
        },
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedNavIndex,
        onItemTapped: _selectNavigation,
      ),
    );
  }

  Widget _buildDashboard() {
    final palette = AppPalette.of(context);
    final history = _snapshot.historyFor(_selectedMetal, _selectedUnit);

    return RefreshIndicator(
      color: palette.accent,
      backgroundColor: palette.surface,
      onRefresh: () =>
          _loadMarketData(reloadLivePrices: true, forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          const DashboardHeader(),
          const SizedBox(height: 16),
          QuickActions(
            onSearchReference: () => _selectNavigation(2),
            onBrowseBrands: () => _selectNavigation(1),
          ),
          const SizedBox(height: 18),
          MarketPeriodSelector(
            selectedPeriod: _selectedPeriod,
            onChanged: _selectPeriod,
          ),
          const SizedBox(height: 14),
          MarketChart(
            selectedMetal: _selectedMetal,
            selectedUnit: _selectedUnit,
            history: history,
            isLoading: _isChartLoading,
            onMetalChanged: _selectMetal,
            onUnitChanged: _selectUnit,
          ),
          const SizedBox(height: 14),
          MetalPriceGrid(
            snapshot: _snapshot,
            selectedUnit: _selectedUnit,
            isLoading: _isPriceLoading,
            hasLoadedOnce: _hasLoadedPrices,
            onRetry: _isPriceLoading
                ? null
                : () => _loadMarketData(
                    reloadLivePrices: true,
                    forceRefresh: true,
                  ),
            onMetalChanged: _selectMetal,
            selectedMetal: _selectedMetal,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _selectUnit(PriceUnit unit) {
    if (unit == _selectedUnit) {
      return;
    }
    setState(() => _selectedUnit = unit);
    _loadMarketData(reloadLivePrices: true);
  }

  void _selectMetal(MetalType metal) {
    if (metal == _selectedMetal) {
      return;
    }
    setState(() => _selectedMetal = metal);
    _loadMarketData(reloadLivePrices: false);
  }

  void _selectNavigation(int index) {
    if (_selectedNavIndex == index) {
      return;
    }
    setState(() => _selectedNavIndex = index);
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    const labels = ['Home', 'Brands', 'Search', 'Catalog', 'Profile'];
    return Center(
      child: Text(
        labels[index],
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
