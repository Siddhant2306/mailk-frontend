import 'package:flutter/material.dart';

import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050709),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LOGIN BACKGROUND
          Positioned.fill(
            child: Image.asset('assets/login_bg.png', fit: BoxFit.cover),
          ),

          // DARK OVERLAY
          Container(color: Colors.black.withValues(alpha: 0.30)),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 105),

                          // MALIK LOGO
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/Logo.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                                // const SizedBox(height: 2),
                                const Text(
                                  'M A L I K',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 6,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'CATALYTIC CATALOGUE',
                                  style: TextStyle(
                                    color: Color(0xFFFFB21A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // TITLE
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 3),

                          const Text(
                            'Sign in to continue to your account',
                            style: TextStyle(
                              color: Color(0xFF9A9DA5),
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 13),

                          // EMAIL
                          _buildInputField(
                            controller: emailController,
                            hintText: 'Email or Username',
                            icon: Icons.mail_outline,
                          ),

                          const SizedBox(height: 10),

                          // PASSWORD
                          _buildInputField(
                            controller: passwordController,
                            hintText: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: obscurePassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF78808D),
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 34,
                              ),
                            ),
                          ),

                          // FORGOT PASSWORD
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: GestureDetector(
                                onTap: () {},
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Color(0xFFFFC32A),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // LOGIN BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                //TODO: Implement login functionality here.
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HomeScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB21A),
                                foregroundColor: Colors.black,
                                elevation: 8,
                                shadowColor: const Color(0xFFFFB21A)
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 9),
                                  Icon(Icons.arrow_forward, size: 15),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 19),

                          // OR DIVIDER
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFF222933),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Color(0xFF737984),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFF222933),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 13),

                          // GOOGLE BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () {
                                //TODO: Implement Google Sign-In functionality here.
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF202A35),
                                ),
                                backgroundColor: const Color(0xFF080D13)
                                    .withValues(alpha: 0.55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image(
                                    image: AssetImage('assets/google.png'),
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      color: Color(0xFFC5C8CE),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 17),

                          // SIGN UP
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                // Navigate to Sign Up screen.
                              },
                              child: RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Don't have an account? ",
                                      style: TextStyle(
                                        color: Color(0xFF7D838D),
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Sign Up',
                                      style: TextStyle(
                                        color: Color(0xFFFFB21A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: const Color(0xFFFFB21A),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF7F8793), fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xFF8A929E), size: 14),
          suffixIcon: suffixIcon,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 34,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: const Color(0xFF080E15).withValues(alpha: 0.80),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF263342), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF8C6418), width: 1),
          ),
        ),
      ),
    );
  }
}
