import 'package:flutter/material.dart';

import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080706),
      body: SafeArea(
        child: Stack(
          children: [
            // BACKGROUND
            Positioned.fill(
              child: Image.asset('assets/bg.png', fit: BoxFit.cover),
            ),

            // TOP METAL PRICE CARDS
            Positioned(
              left: 15,
              top: 30,
              child: Column(
                children: [
                  Image.asset('assets/pt.png'),
                  const SizedBox(height: 8),
                  Image.asset('assets/pd.png'),
                  const SizedBox(height: 8),
                  Image.asset('assets/rh.png'),
                ],
              ),
            ),

            Positioned(
              top: 30,
              right: 20,
              child: Image.asset(
                'assets/graph.png',
                width: 120,
                fit: BoxFit.contain,
              ),
            ),

            // MAIN CONTENT
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.17),

                        // LOGO
                        Image.asset('assets/Logo.png', width: 95, height: 95),

                        const SizedBox(height: 8),

                        // MALIK
                        const Text(
                          'MALIK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 35,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // BRAND TAGLINE
                        const Text(
                          'CATALYTIC CONVERTER SOLUTIONS',
                          style: TextStyle(
                            color: Color(0xFFD4A72C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 30),

                        const Text(
                          'Your Complete Guide to',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),

                        const SizedBox(height: 3),

                        const Text(
                          'Catalytic Converter',
                          style: TextStyle(
                            color: Color(0xFFFFB21A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Text(
                          'Pricing & Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Real Prices  •  Accurate Data  •  Smarter Decisions',
                          style: TextStyle(
                            color: Color(0xFFB5B5B5),
                            fontSize: 12,
                          ),
                        ),

                        SizedBox(height: size.height * 0.03),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // GET STARTED
            Positioned(
              left: 20,
              right: 20,
              bottom: 45,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB21A),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            // FOOTER
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: const Text(
                  'CATALYTIC CONVERTERS  |  PRICING  |  REFERENCE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Liberation Sans',
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
