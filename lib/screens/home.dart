import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/navigation/app_routes.dart';
import '../core/theme/app_palette.dart';
import '../models/app_user.dart';
import '../models/market_models.dart';
import '../models/metal_price.dart';
import '../services/admin_user_service.dart';
import '../services/auth_service.dart';
import '../services/authenticated_api_client.dart';
import '../services/brand_service.dart';
import '../services/converter_service.dart';
import '../services/metal_service.dart';
import '../services/session_cache.dart';
import '../widgets/home/dashboard_header.dart';
import '../widgets/home/market_chart.dart';
import '../widgets/home/market_period_selector.dart';
import '../widgets/home/metal_price_grid.dart';
import '../widgets/navigation.dart';
import 'admin_profile_screen.dart';
import 'brands_screen.dart';
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
    this.authService,
    this.sessionCache,
    this.firebaseUid,
    this.isSessionVerified = true,
  });

  final MetalService? metalService;
  final BrandService? brandService;
  final ConverterService? converterService;
  final AppUser? currentUser;
  final AdminUserService? adminUserService;
  final AuthService? authService;
  final SessionCache? sessionCache;
  final String? firebaseUid;
  final bool isSessionVerified;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MetalService _metalService;
  AuthService? _authService;
  late final SessionCache _sessionCache;
  late AppUser? _currentUser;
  late bool _isSessionVerified;

  var _selectedNavIndex = 0;
  int? _catalogBrandId;
  var _selectedPeriod = MarketPeriod.tenDays;
  var _selectedMetal = MetalType.platinum;
  var _selectedUnit = PriceUnit.inr;
  var _snapshot = MarketSnapshot.empty();
  var _isChartLoading = true;
  var _isPriceLoading = true;
  var _hasLoadedPrices = false;
  var _hasLoadedHistory = false;
  var _pricesAreStale = true;
  var _historyIsStale = true;
  var _marketHydrated = false;
  var _quotesNeedRefresh = true;
  var _historyNeedsRefresh = true;
  var _isSessionRefreshing = false;
  String? _sessionStatus;
  var _requestId = 0;

  bool get _canUseAdmin =>
      _isSessionVerified && (_currentUser?.isAdmin ?? false);

  @override
  void initState() {
    super.initState();
    _metalService = widget.metalService ?? MetalService();
    _authService = widget.authService;
    _sessionCache = widget.sessionCache ?? SessionCache();
    _currentUser = widget.currentUser;
    _isSessionVerified = widget.isSessionVerified;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateMarketFromCache());
      if (!_isSessionVerified) {
        unawaited(_validateCachedSession());
      }
    });
  }

  Future<void> _hydrateMarketFromCache() async {
    final requestId = ++_requestId;
    final cachedQuotesFuture = _metalService.readCachedLiveQuotes(
      _selectedUnit,
    );
    final cachedHistoryFuture = _metalService.readCachedHistoryForMetal(
      metal: _selectedMetal,
      days: _selectedPeriod.days,
      unit: _selectedUnit,
    );
    final cachedQuotes = await cachedQuotesFuture;
    final cachedHistory = await cachedHistoryFuture;
    if (!mounted || requestId != _requestId) {
      return;
    }

    setState(() {
      if (cachedQuotes != null) {
        _snapshot = _selectedUnit == PriceUnit.inr
            ? _snapshot.copyWith(inrQuotes: cachedQuotes.value)
            : _snapshot.copyWith(usdQuotes: cachedQuotes.value);
        _hasLoadedPrices = true;
        _isPriceLoading = false;
        _pricesAreStale = !cachedQuotes.isFresh;
      }
      if (cachedHistory != null) {
        final histories = _selectedUnit == PriceUnit.inr
            ? Map<MetalType, List<MetalPrice>>.from(_snapshot.inrHistory)
            : Map<MetalType, List<MetalPrice>>.from(_snapshot.usdHistory);
        histories[_selectedMetal] = cachedHistory.value;
        _snapshot = _selectedUnit == PriceUnit.inr
            ? _snapshot.copyWith(inrHistory: histories)
            : _snapshot.copyWith(usdHistory: histories);
        _hasLoadedHistory = true;
        _isChartLoading = false;
        _historyIsStale = !cachedHistory.isFresh;
      }
      _quotesNeedRefresh = cachedQuotes == null || !cachedQuotes.isFresh;
      _historyNeedsRefresh = cachedHistory == null || !cachedHistory.isFresh;
      _marketHydrated = true;
    });

    _refreshStaleMarketData();
  }

  void _refreshStaleMarketData() {
    if (!_marketHydrated || !_isSessionVerified) {
      return;
    }
    final refreshQuotes = _quotesNeedRefresh;
    final refreshHistory = _historyNeedsRefresh;
    if (!refreshQuotes && !refreshHistory) {
      return;
    }
    _quotesNeedRefresh = false;
    _historyNeedsRefresh = false;
    unawaited(
      _loadMarketData(
        reloadLivePrices: refreshQuotes,
        reloadHistory: refreshHistory,
        forceRefresh: true,
      ),
    );
  }

  Future<void> _validateCachedSession() async {
    if (_isSessionVerified || widget.firebaseUid == null) {
      return;
    }
    setState(() {
      _isSessionRefreshing = true;
      _sessionStatus = null;
    });

    try {
      final user = await (_authService ??= AuthService()).getCurrentUser(
        allowColdStart: true,
      );
      if (!user.isActive || user.status != 'approved') {
        await _endCachedSession();
        return;
      }
      await _sessionCache.write(firebaseUid: widget.firebaseUid!, user: user);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUser = user;
        _isSessionVerified = true;
        _isSessionRefreshing = false;
        _sessionStatus = null;
      });
      _refreshStaleMarketData();
    } on AuthenticationRequiredException {
      await _endCachedSession();
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
        await _endCachedSession();
      } else {
        _keepCachedSession('Showing saved data while the service reconnects.');
      }
    } on Object {
      _keepCachedSession('Showing saved data while the service reconnects.');
    }
  }

  void _keepCachedSession(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSessionRefreshing = false;
      _sessionStatus = message;
    });
  }

  Future<void> _endCachedSession() async {
    await _sessionCache.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _loadMarketData({
    required bool reloadLivePrices,
    required bool reloadHistory,
    bool forceRefresh = false,
  }) async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        if (reloadHistory && !_hasLoadedHistory) {
          _isChartLoading = true;
        }
        if (reloadLivePrices && !_hasLoadedPrices) {
          _isPriceLoading = true;
        }
      });
    }

    final requests = <Future<void>>[];
    if (reloadHistory) {
      requests.add(_loadHistory(requestId, forceRefresh: forceRefresh));
    }
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
        _pricesAreStale = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() => _isPriceLoading = false);
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
        _hasLoadedHistory = true;
        _historyIsStale = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() => _isChartLoading = false);
    }
  }

  Future<void> _refreshDashboard() async {
    if (!_isSessionVerified) {
      _keepCachedSession('Connect to the secure service before refreshing.');
      return;
    }
    await _loadMarketData(
      reloadLivePrices: true,
      reloadHistory: true,
      forceRefresh: true,
    );
  }

  void _selectPeriod(MarketPeriod period) {
    if (period == _selectedPeriod) {
      return;
    }
    setState(() {
      _selectedPeriod = period;
      _hasLoadedHistory = false;
      _isChartLoading = true;
      _historyIsStale = true;
      _marketHydrated = false;
    });
    unawaited(_hydrateMarketFromCache());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (_sessionStatus != null)
              _SessionStatusBanner(
                message: _sessionStatus!,
                isRefreshing: false,
                onRetry: _isSessionRefreshing
                    ? null
                    : () => unawaited(_validateCachedSession()),
              ),
            Expanded(
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
                  isAdmin: _canUseAdmin,
                ),
                3 => CatalogScreen(
                  converterService: widget.converterService,
                  brandService: widget.brandService,
                  initialBrandId: _catalogBrandId,
                  isAdmin: _canUseAdmin,
                ),
                4 when _currentUser != null => AdminProfileScreen(
                  user: _currentUser!,
                  isSessionVerified: _isSessionVerified,
                  brandService: widget.brandService,
                  adminUserService: widget.adminUserService,
                ),
                4 => const AdminRestrictedScreen(),
                _ => _PlaceholderPage(index: _selectedNavIndex),
              },
            ),
          ],
        ),
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
      onRefresh: _refreshDashboard,
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
            isStale: _historyIsStale,
            onMetalChanged: _selectMetal,
            onUnitChanged: _selectUnit,
          ),
          const SizedBox(height: 14),
          MetalPriceGrid(
            snapshot: _snapshot,
            selectedUnit: _selectedUnit,
            isLoading: _isPriceLoading,
            isStale: _pricesAreStale,
            hasLoadedOnce: _hasLoadedPrices,
            onRetry: _isPriceLoading ? null : _refreshDashboard,
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
    setState(() {
      _selectedUnit = unit;
      _hasLoadedPrices = _snapshot.quoteFor(_selectedMetal, unit) != null;
      _isPriceLoading = !_hasLoadedPrices;
      _hasLoadedHistory = _snapshot.historyFor(_selectedMetal, unit).isNotEmpty;
      _isChartLoading = !_hasLoadedHistory;
      _pricesAreStale = true;
      _historyIsStale = true;
      _marketHydrated = false;
    });
    unawaited(_hydrateMarketFromCache());
  }

  void _selectMetal(MetalType metal) {
    if (metal == _selectedMetal) {
      return;
    }
    setState(() {
      _selectedMetal = metal;
      _hasLoadedHistory = _snapshot.historyFor(metal, _selectedUnit).isNotEmpty;
      _isChartLoading = !_hasLoadedHistory;
      _historyIsStale = true;
      _marketHydrated = false;
    });
    unawaited(_hydrateMarketFromCache());
  }

  void _selectNavigation(int index) {
    if (_selectedNavIndex == index) {
      return;
    }
    setState(() => _selectedNavIndex = index);
  }
}

class _SessionStatusBanner extends StatelessWidget {
  const _SessionStatusBanner({
    required this.message,
    required this.isRefreshing,
    required this.onRetry,
  });

  final String message;
  final bool isRefreshing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (isRefreshing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.cloud_off_outlined,
                color: palette.textMuted,
                size: 16,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
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
