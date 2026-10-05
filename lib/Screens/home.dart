import 'package:flutter/material.dart';
import 'dart:math';

//import '../core/constants/constants.dart';
import '../services/metal_service.dart';
import '../models/metal_price.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

int _selectedIndex = 0;
String _selectedPeriod = '10 Days';
String _selectedMetal = 'Pt';

final MetalService _metalService = MetalService();

MetalLivePrice? _platinumPrice;
MetalLivePrice? _palladiumPrice;
MetalLivePrice? _rhodiumPrice;

List<MetalPrice> _platinumHistory = [];
List<MetalPrice> _palladiumHistory = [];
List<MetalPrice> _rhodiumHistory = [];

//bool _loadingPrices = true;
bool _loadingChart = true;



  final List<String> _periods = [
    '10 Days',
    '1 Month',
    '6 Months',
    '1 Year',
  ];

  int _selectedPeriodDays() {
    switch (_selectedPeriod) {
      case '10 Days':
        return 10;

      case '1 Month':
        return 30;

      case '6 Months':
        return 180;

      case '1 Year':
        return 365;

      default:
        return 10;
    }
  }

  Future<void> _loadMarketData() async {
  // 1. Load live prices
  try {
    final prices = await Future.wait([
      _metalService.getLivePrice(
        symbol: 'PT',
        currency: 'USD',
      ),
      _metalService.getLivePrice(
        symbol: 'PD',
        currency: 'USD',
      ),
      _metalService.getLivePrice(
        symbol: 'RH',
        currency: 'USD',
      ),
    ]);

    if (!mounted) return;

    debugPrint('PT PRICE: ${prices[0].price}');
    debugPrint('PD PRICE: ${prices[1].price}');
    debugPrint('RH PRICE: ${prices[2].price}');

    setState(() {
      _platinumPrice = prices[0];
      _palladiumPrice = prices[1];
      _rhodiumPrice = prices[2];
    });
  } catch (e) {
    debugPrint('Metal quote API error: $e');
  }

  // 2. Load chart history separately
  try {
    final history = await Future.wait([
      _metalService.getHistory(
        symbol: 'PT',
        currency: 'USD',
        days: _selectedPeriodDays(),
      ),
      _metalService.getHistory(
        symbol: 'PD',
        currency: 'USD',
        days: _selectedPeriodDays(),
      ),
      _metalService.getHistory(
        symbol: 'RH',
        currency: 'USD',
        days: _selectedPeriodDays(),
      ),
    ]);

    if (!mounted) return;

    setState(() {
      _platinumHistory = history[0];
      _palladiumHistory = history[1];
      _rhodiumHistory = history[2];
      _loadingChart = false;
    });
  } catch (e) {
    debugPrint('Metal history API error: $e');

    if (!mounted) return;

    setState(() {
      _loadingChart = false;
    });
  }
}


  @override
  void initState() {
    super.initState();

    _loadMarketData();
  }

  String _formatChartDate(List<MetalPrice> data) {
    if (data.isEmpty) {
      return '--';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(
      data.first.timestamp * 1000,
    );

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatLatestChartDate(List<MetalPrice> data) {
    if (data.isEmpty) {
      return '--';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(
      data.last.timestamp * 1000,
    );

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      body: SafeArea(
        child: _selectedIndex == 0
            ? SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildHome(),
              )
            : _buildPlaceholder(_navTitle(_selectedIndex)),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  String _navTitle(int index) {
    switch (index) {
      case 1:
        return 'Brands';
      case 2:
        return 'Search';
      case 3:
        return 'Catalog';
      case 4:
        return 'Profile';
      default:
        return 'Home';
    }
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.search,
                  title: 'Search a\nReference',
                  subtitle: 'By code / marking',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.directions_car_outlined,
                  title: 'Search by\nCar Model',
                  subtitle: 'Browse brands',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildPeriodSelector(),

          const SizedBox(height: 14),

          _buildMarketChart(),

          const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildLiveMetalCard(
                        symbol: 'Pt',
                        name: 'Platinum',
                        metal: _platinumPrice,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLiveMetalCard(
                        symbol: 'Pd',
                        name: 'Palladium',
                        metal: _palladiumPrice,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLiveMetalCard(
                        symbol: 'Rh',
                        name: 'Rhodium',
                        metal: _rhodiumPrice,
                      ),
                    ),
                  ],
                ),
                
          const SizedBox(height: 10),

          const Center(
            child: Text(
              'Illustrative reference prices, updated daily. Verify with your\nbroker before quoting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF69717D),
                fontSize: 8,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/Logo.png',
          width: 62,
          height: 62,
          fit: BoxFit.contain,
        ),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'MALIK ENTERPRISES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Catalytic Converter Reference Catalog',
              style: TextStyle(
                color: Color(0xFF858D99),
                fontSize: 13,
              ),
            ),
          ],
        ),

        const Spacer(),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 165,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF1D2734),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2027),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: const Color(0xFFFFB21A),
              size: 29,
            ),
          ),

          const Spacer(),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.12,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF707985),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
  return Row(
    children: [
      for (int i = 0; i < _periods.length; i++) ...[
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (_selectedPeriod == _periods[i]) {
                return;
              }

              setState(() {
                _selectedPeriod = _periods[i];
                _loadingChart = true;
              });

              await _loadMarketData();
            },
            child: Container(
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedPeriod == _periods[i]
                    ? const Color(0xFF2A2412)
                    : const Color(0xFF151A21),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedPeriod == _periods[i]
                      ? const Color(0xFFFFB21A)
                      : const Color(0xFF202832),
                ),
              ),
              child: Text(
                _periods[i],
                style: TextStyle(
                  color: _selectedPeriod == _periods[i]
                      ? const Color(0xFFFFC23D)
                      : const Color(0xFFB3B8C0),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        if (i != _periods.length - 1)
          const SizedBox(width: 6),
      ],
    ],
  );
}

  Widget _buildMarketChart() {
    final List<MetalPrice> selectedHistory =
        _selectedMetal == 'Pt'
            ? _platinumHistory
            : _selectedMetal == 'Pd'
                ? _palladiumHistory
                : _rhodiumHistory;

    final String selectedMetalName =
        _selectedMetal == 'Pt'
            ? 'Platinum'
            : _selectedMetal == 'Pd'
                ? 'Palladium'
                : 'Rhodium';

    return Container(
      height: 225,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10161F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF202A36),
        ),
      ),
      child: Column(
        children: [
          // --------------------------------------------------
          // HEADER
          // --------------------------------------------------
          Row(
            children: [
              const Text(
                'PGM MARKET - EUR',
                style: TextStyle(
                  color: Color(0xFF8F98A5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: 6),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14251D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF63C18A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Platinum
              _buildMetalSelector(
                symbol: 'Pt',
                color: const Color(0xFFB9D5FF),
              ),

              const SizedBox(width: 7),

              // Palladium
              _buildMetalSelector(
                symbol: 'Pd',
                color: const Color(0xFFE4B94C),
              ),

              const SizedBox(width: 7),

              // Rhodium
              _buildMetalSelector(
                symbol: 'Rh',
                color: const Color(0xFFE75A7D),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // --------------------------------------------------
          // SELECTED METAL TITLE
          // --------------------------------------------------
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$selectedMetalName trend',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 5),

          // --------------------------------------------------
          // GRAPH
          // --------------------------------------------------
          Expanded(
            child: _loadingChart
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFB21A),
                      strokeWidth: 2,
                    ),
                  )
                : CustomPaint(
                    painter: _MarketChartPainter(
                      data: selectedHistory,
                      metal: _selectedMetal,
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),

          // --------------------------------------------------
          // DATES
          // --------------------------------------------------
          Row(
            children: [
              Text(
                _formatChartDate(selectedHistory),
                style: const TextStyle(
                  color: Color(0xFF697381),
                  fontSize: 11,
                ),
              ),

              const Spacer(),

              Text(
                _formatLatestChartDate(selectedHistory),
                style: const TextStyle(
                  color: Color(0xFF697381),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // --------------------------------------------------
          // UNIT + TIME
          // --------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF332711),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  '€/Kilo',
                  style: TextStyle(
                    color: Color(0xFFFFC34A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              const Text(
                '8:02T',
                style: TextStyle(
                  color: Color(0xFF737D8A),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _legendDot({
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 3),

        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC0C6CE),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMetalCard({
    required String symbol,
    required String name,
    required MetalLivePrice? metal,
  }) {

      debugPrint(
      'BUILD CARD: $symbol | metal=${metal?.price} | '
      'change=${metal?.changePercentage}',
    );

    final Color symbolColor = symbol == 'Pt'
        ? const Color(0xFFB8D4FF)
        : symbol == 'Pd'
            ? const Color(0xFFE4B94C)
            : const Color(0xFFE85C7C);

    final bool isPositive =
        (metal?.changePercentage ?? 0) >= 0;

    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(9, 9, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF10161F),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF202A36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: symbolColor,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 5),

              Text(
                symbol,
                style: const TextStyle(
                  color: Color(0xFFE0E4E9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8D96A2),
              fontSize: 13,
            ),
          ),

          const Spacer(),

          if (metal == null)
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            )
          else
            Text(
              '₹${metal.pricePerGram.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 3),

          if (metal != null)
            Text(
              '${isPositive ? '+' : ''}${(metal.changePercentage ?? 0).toStringAsFixed(2)}%',
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFF63C18A)
                    : const Color(0xFFE56A7B),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
  const items = [
    (Icons.home_outlined, 'HOME'),
    (Icons.business_outlined, 'BRANDS'),
    (Icons.search, 'SEARCH'),
    (Icons.grid_view_rounded, 'CATALOG'),
    (Icons.person_outline, 'PROFILE'),
  ];

  return Container(
    height: 70,
    decoration: const BoxDecoration(
      color: Color(0xFF0B0F15),
      border: Border(
        top: BorderSide(
          color: Color(0xFF1E2732),
          width: 1,
        ),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => _onNavTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[i].$1,
                      size: 24, // changed from 28
                      color: i == _selectedIndex
                          ? const Color(0xFFFFB21A)
                          : const Color(0xFF7E8793),
                    ),
                    const SizedBox(height: 2), // changed from 4
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        color: i == _selectedIndex
                            ? const Color(0xFFFFB21A)
                            : const Color(0xFF7E8793),
                        fontSize: 10,
                        fontWeight: i == _selectedIndex
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildMetalSelector({
    required String symbol,
    required Color color,
  }) {
    final bool selected = _selectedMetal == symbol;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMetal = symbol;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 3),

          Text(
            symbol,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFE5E9EF)
                  : const Color(0xFF697381),
              fontSize: 9,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MarketChartPainter extends CustomPainter {
  final List<MetalPrice> data;
  final String metal;

  _MarketChartPainter({
    required this.data,
    required this.metal,
  });

  Color get lineColor {
    switch (metal) {
      case 'Pd':
        return const Color(0xFFE4B94C);

      case 'Rh':
        return const Color(0xFFE75A7D);

      case 'Pt':
      default:
        return const Color(0xFFB9D5FF);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    const double leftPadding = 34;
    const double rightPadding = 6;
    const double topPadding = 8;
    const double bottomPadding = 5;

    final double chartWidth =
        size.width - leftPadding - rightPadding;

    final double chartHeight =
        size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) {
      return;
    }

    // --------------------------------------------------
    // GET PRICES FOR SELECTED METAL ONLY
    // --------------------------------------------------

    final List<double> prices = data
        .map((item) => item.price)
        .where((price) => price.isFinite)
        .toList();

    if (prices.isEmpty) {
      return;
    }

    double minPrice = prices.reduce(min);
    double maxPrice = prices.reduce(max);

    // --------------------------------------------------
    // CREATE A SMALL RANGE IF PRICES ARE VERY CLOSE
    // --------------------------------------------------

    double range = maxPrice - minPrice;

    if (range <= 0) {
      range = maxPrice.abs() * 0.02;

      if (range == 0) {
        range = 1;
      }
    }

    // Add 15% visual padding above and below.
    final double chartMin =
        minPrice - (range * 0.15);

    final double chartMax =
        maxPrice + (range * 0.15);

    final double finalRange =
        chartMax - chartMin;

    // --------------------------------------------------
    // GRID
    // --------------------------------------------------

    final Paint gridPaint = Paint()
      ..color = const Color(0xFF27313D)
      ..strokeWidth = 0.7;

    const int horizontalLines = 4;

    for (int i = 0; i <= horizontalLines; i++) {
      final double y =
          topPadding +
          (chartHeight * i / horizontalLines);

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(
          size.width - rightPadding,
          y,
        ),
        gridPaint,
      );
    }

    // --------------------------------------------------
    // Y AXIS LABELS
    // --------------------------------------------------

    for (int i = 0; i <= horizontalLines; i++) {
      final double value =
          chartMax -
          (finalRange * i / horizontalLines);

      final double y =
          topPadding +
          (chartHeight * i / horizontalLines);

      _drawText(
        canvas,
        value.toStringAsFixed(0),
        Offset(1, y - 5),
        const TextStyle(
          color: Color(0xFF687381),
          fontSize: 7,
        ),
      );
    }

    // --------------------------------------------------
    // PRICE LINE
    // --------------------------------------------------

    final Path path = Path();

    for (int i = 0; i < data.length; i++) {
      final double price = data[i].price;

      if (!price.isFinite) {
        continue;
      }

      final double x = data.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding +
              (chartWidth *
                  i /
                  (data.length - 1));

      final double normalized =
          (price - chartMin) / finalRange;

      final double y =
          topPadding +
          chartHeight -
          (normalized * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // --------------------------------------------------
    // DRAW LINE
    // --------------------------------------------------

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // --------------------------------------------------
    // LAST DATA POINT
    // --------------------------------------------------

    final double lastPrice = data.last.price;

    if (lastPrice.isFinite) {
      final double x = data.length == 1
          ? leftPadding + chartWidth / 2
          : leftPadding + chartWidth;

      final double normalized =
          (lastPrice - chartMin) / finalRange;

      final double y =
          topPadding +
          chartHeight -
          (normalized * chartHeight);

      final Paint pointPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        2,
        pointPaint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      offset,
    );
  }

  @override
  bool shouldRepaint(
    covariant _MarketChartPainter oldDelegate,
  ) {
    return oldDelegate.data != data ||
        oldDelegate.metal != metal;
  }
}
