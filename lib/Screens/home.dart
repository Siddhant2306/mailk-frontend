import 'package:flutter/material.dart';
import '../Widgets/navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _selectedPeriod = '6 Months';

  final List<String> _periods = [
    '10 Days',
    '1 Month',
    '6 Months',
    '1 Year',
  ];

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
            ? _buildHome()
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
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.search,
                  title: 'Search a\nReference',
                  subtitle: 'By code / marking',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.directions_car_outlined,
                  title: 'Search by\nCar Model',
                  subtitle: 'Browse brands',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildPeriodSelector(),

          const SizedBox(height: 10),

          _buildMarketChart(),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildMetalCard(
                  symbol: 'Pt',
                  name: 'Platinum',
                  price: '₹29.92/L',
                  change: '+1.24%',
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetalCard(
                  symbol: 'Pd',
                  name: 'Palladium',
                  price: '₹30.29/L',
                  change: '-0.94%',
                  isPositive: false,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetalCard(
                  symbol: 'Rh',
                  name: 'Rhodium',
                  price: '₹153.94/L',
                  change: '+1.78%',
                  isPositive: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          const Center(
            child: Text(
              'Illustrative reference prices, updated daily. Verify with your\nbroker before quoting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF69717D),
                fontSize: 6.5,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 9),

          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF111720),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFF26303D),
                ),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF929AA6),
                size: 14,
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
          width: 55,
          height: 55,
          fit: BoxFit.contain,
        ),

        const SizedBox(width: 9),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'MALIK ENTERPRISES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Catalytic Converter Reference Catalog',
              style: TextStyle(
                color: Color(0xFF858D99),
                fontSize: 12,
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
      height: 140,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF1D2734),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2027),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFB21A),
              size: 25,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF707985),
              fontSize: 12,
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
              onTap: () {
                setState(() {
                  _selectedPeriod = _periods[i];
                });
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
          if (i != _periods.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildMarketChart() {
    return Container(
      height: 194,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 7),
      decoration: BoxDecoration(
        color: const Color(0xFF10161F),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF202A36),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'PGM MARKET - EUR',
                style: TextStyle(
                  color: Color(0xFF8F98A5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF19202A),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Color(0xFF8C96A4),
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              _legendDot(
                color: const Color(0xFFB9D5FF),
                label: 'Pt',
              ),
              const SizedBox(width: 5),
              _legendDot(
                color: const Color(0xFFE4B94C),
                label: 'Pd',
              ),
              const SizedBox(width: 5),
              _legendDot(
                color: const Color(0xFFE75A7D),
                label: 'Rh',
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Platinum trend',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              painter: _MarketChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          Row(
            children: [
              const Text(
                '2026-03-01',
                style: TextStyle(
                  color: Color(0xFF697381),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              const Text(
                '2026-06-25',
                style: TextStyle(
                  color: Color(0xFF697381),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF332711),
                  borderRadius: BorderRadius.circular(4),
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
              const SizedBox(width: 5),
              const Text(
                '8:02T',
                style: TextStyle(
                  color: Color(0xFF737D8A),
                  fontSize: 12,
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC0C6CE),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMetalCard({
    required String symbol,
    required String name,
    required String price,
    required String change,
    required bool isPositive,
  }) {
    final Color symbolColor = symbol == 'Pt'
        ? const Color(0xFFB8D4FF)
        : symbol == 'Pd'
            ? const Color(0xFFE4B94C)
            : const Color(0xFFE85C7C);

    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(7, 7, 6, 5),
      decoration: BoxDecoration(
        color: const Color(0xFF10161F),
        borderRadius: BorderRadius.circular(8),
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
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: symbolColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                symbol,
                style: const TextStyle(
                  color: Color(0xFFE0E4E9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8D96A2),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            change,
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
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F15),
        border: Border(
          top: BorderSide(
            color: Color(0xFF1E2732),
            width: 1,
          ),
        ),
      ),
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
                      size: 25,
                      color: i == _selectedIndex
                          ? const Color(0xFFFFB21A)
                          : const Color(0xFF7E8793),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        color: i == _selectedIndex
                            ? const Color(0xFFFFB21A)
                            : const Color(0xFF7E8793),
                        fontSize: 12,
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
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1B2430)
      ..strokeWidth = 0.7;

    final platinumPaint = Paint()
      ..color = const Color(0xFFD84C6B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final palladiumPaint = Paint()
      ..color = const Color(0xFFE2B53F)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rhodiumPaint = Paint()
      ..color = const Color(0xFF6BA2D8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines.
    for (int i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Vertical grid lines.
    for (int i = 0; i < 7; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    final platinum = [
      0.35, 0.33, 0.37, 0.34, 0.40, 0.36, 0.43, 0.39,
      0.44, 0.48, 0.45, 0.52, 0.49, 0.54, 0.57, 0.53,
      0.60, 0.56, 0.51, 0.47, 0.42, 0.46, 0.50, 0.55,
      0.52, 0.49, 0.44, 0.39, 0.36, 0.40, 0.44, 0.48,
      0.46, 0.42, 0.39, 0.43, 0.47, 0.52, 0.55, 0.59,
    ];

    final palladium = List<double>.filled(40, 0.82);
    final rhodium = List<double>.filled(40, 0.85);

    _drawLine(canvas, size, platinum, platinumPaint);
    _drawLine(canvas, size, palladium, palladiumPaint);
    _drawLine(canvas, size, rhodium, rhodiumPaint);

    final labelStyle = const TextStyle(
      color: Color(0xFF59626F),
      fontSize: 12,
    );

    _drawText(canvas, '15.2', const Offset(1, 1), labelStyle);
    _drawText(
      canvas,
      '11.2',
      Offset(1, size.height * .28),
      labelStyle,
    );
    _drawText(
      canvas,
      '7.01',
      Offset(1, size.height * .58),
      labelStyle,
    );
    _drawText(
      canvas,
      '2.01',
      Offset(1, size.height * .87),
      labelStyle,
    );
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<double> values,
    Paint paint,
  ) {
    final path = Path();

    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * values[i];

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
