import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:malik/screens/sign_in.dart' show SignUpScreen;

import '../config/api_config.dart';
import '../core/constants/constants.dart';
import '../core/theme/app_palette.dart';
import '../models/app_user.dart';
import '../services/session_cache.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final SessionCache _sessionCache = SessionCache();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.apiConnectTimeout,
      receiveTimeout: ApiConfig.sessionReceiveTimeout,
      responseType: ResponseType.json,
    ),
  );

  bool obscurePassword = true;
  bool isLoading = false;
  bool isCheckingSession = true;

  @override
  void initState() {
    super.initState();

    _checkExistingSession();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHECK EXISTING FIREBASE SESSION
  // ============================================================

  Future<void> _checkExistingSession() async {
    final stopwatch = Stopwatch()..start();

    void mark(String message) {
      developer.log(
        '${stopwatch.elapsedMilliseconds} ms | $message',
        name: 'malik.session',
      );
    }

    try {
      mark('Existing-session check started');
      final firebaseUser = _firebaseAuth.currentUser;

      // No previous Firebase session.
      if (firebaseUser == null) {
        mark('No persisted Firebase session');
        if (mounted) {
          setState(() {
            isCheckingSession = false;
          });
        }
        return;
      }

      mark('Persisted Firebase session found');

      final cachedSession = await _sessionCache.readForFirebaseUid(
        firebaseUser.uid,
      );
      if (cachedSession != null) {
        mark('Cached account snapshot restored');
        _openHome(
          cachedSession.user,
          firebaseUid: firebaseUser.uid,
          isSessionVerified: false,
        );
        return;
      }

      await _checkBackendAccount(firebaseUser);
      mark('Existing-session check completed');
      if (mounted && isCheckingSession) {
        setState(() => isCheckingSession = false);
      }
    } on TimeoutException {
      mark('Existing-session check timed out');
      _finishExistingSessionCheck(
        'The secure service is taking too long to respond. Please try again.',
      );
    } on DioException catch (error) {
      mark('Existing-session backend check failed: ${error.type.name}');
      _finishExistingSessionCheck(
        'Could not reach the secure service. Please try again.',
      );
    } on Object catch (error, stackTrace) {
      mark('Existing-session check failed: ${error.runtimeType}');
      developer.log(
        'Existing-session check failed.',
        name: 'malik.session',
        error: error,
        stackTrace: stackTrace,
      );
      _finishExistingSessionCheck(
        'Unable to restore your session. Please sign in again.',
      );
    }
  }

  void _finishExistingSessionCheck(String message) {
    if (!mounted) {
      return;
    }
    setState(() => isCheckingSession = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showMessage(message);
      }
    });
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      // ----------------------------------------------------------
      // 1. LOGIN WITH FIREBASE
      // ----------------------------------------------------------

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('Unable to retrieve Firebase user.');
      }

      developer.log('Firebase sign-in completed.', name: 'malik.session');

      // ----------------------------------------------------------
      // 2. CHECK BACKEND ACCOUNT
      // ----------------------------------------------------------

      await _checkBackendAccount(firebaseUser);
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase login error: ${e.code}');

      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
          message = 'Incorrect password.';
          break;

        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This Firebase account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Login failed.';
      }

      _showMessage(message);
    } on TimeoutException {
      _showMessage(
        'Authentication timed out. Check your connection and try again.',
      );
    } on DioException catch (e) {
      developer.log(
        'Backend sign-in check failed: ${e.type.name} '
        '(status ${e.response?.statusCode ?? 'unavailable'}).',
        name: 'malik.session',
      );

      await _handleBackendError(e);
    } catch (e) {
      debugPrint('Login error: $e');

      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CHECK BACKEND ACCOUNT
  // ============================================================

  Future<void> _checkBackendAccount(User firebaseUser) async {
    try {
      // Firebase ID token.
      final idToken = await firebaseUser.getIdToken().timeout(
        ApiConfig.firebaseTokenTimeout,
      );

      if (idToken == null) {
        throw Exception('Unable to retrieve Firebase ID token.');
      }

      developer.log('Firebase ID token acquired.', name: 'malik.session');

      // ----------------------------------------------------------
      // IMPORTANT:
      //
      // This ONLY calls /me.
      //
      // It does NOT call /register.
      // Therefore normal login will NEVER send an approval email.
      // ----------------------------------------------------------

      final response = await _dio.get(
        ApiConstants.currentUser,
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      developer.log(
        'Backend account response received: ${response.statusCode}.',
        name: 'malik.session',
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception('Invalid backend response.');
      }

      final currentUser = AppUser.fromJson(Map<String, dynamic>.from(data));
      final status = currentUser.status;
      final isActive = currentUser.isActive;

      // ----------------------------------------------------------
      // PENDING
      // ----------------------------------------------------------

      if (status == 'pending') {
        await _signOutAndClearSession();

        if (!mounted) return;

        _showMessage('Your account is waiting for admin approval.');

        return;
      }

      // ----------------------------------------------------------
      // REJECTED
      // ----------------------------------------------------------

      if (status == 'rejected') {
        await _signOutAndClearSession();

        if (!mounted) return;

        _showMessage('Your account has been rejected.');

        return;
      }

      // ----------------------------------------------------------
      // BLOCKED / INACTIVE
      // ----------------------------------------------------------

      if (status == 'blocked' || isActive == false) {
        await _signOutAndClearSession();

        if (!mounted) return;

        _showMessage('Your account has been blocked.');

        return;
      }

      // ----------------------------------------------------------
      // APPROVED
      // ----------------------------------------------------------

      if (status == 'approved' && isActive == true) {
        await _sessionCache.write(
          firebaseUid: firebaseUser.uid,
          user: currentUser,
        );
        _openHome(
          currentUser,
          firebaseUid: firebaseUser.uid,
          isSessionVerified: true,
        );
        return;
      }

      // ----------------------------------------------------------
      // UNKNOWN STATUS
      // ----------------------------------------------------------

      await _signOutAndClearSession();

      if (!mounted) return;

      _showMessage('Your account does not have valid access.');
    } on TimeoutException {
      rethrow;
    } on DioException {
      rethrow;
    } catch (e) {
      debugPrint('Backend account check failed: $e');

      await _signOutAndClearSession();

      if (!mounted) return;

      _showMessage('Unable to verify your MALIK account.');
    }
  }

  // ============================================================
  // HANDLE BACKEND ERRORS
  // ============================================================

  Future<void> _handleBackendError(DioException e) async {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    // ----------------------------------------------------------
    // 404
    //
    // Firebase account exists, but PostgreSQL user doesn't.
    // ----------------------------------------------------------

    if (statusCode == 404) {
      await _signOutAndClearSession();

      if (!mounted) return;

      _showMessage('Your MALIK account has not been registered.');

      return;
    }

    // ----------------------------------------------------------
    // 401
    //
    // Firebase token invalid/expired.
    // ----------------------------------------------------------

    if (statusCode == 401) {
      await _signOutAndClearSession();

      if (!mounted) return;

      _showMessage('Your session has expired. Please sign in again.');

      return;
    }

    // ----------------------------------------------------------
    // 403
    // ----------------------------------------------------------

    if (statusCode == 403) {
      await _signOutAndClearSession();

      String message = 'You do not have access to MALIK.';

      if (responseData is Map) {
        final detail = responseData['detail'];

        if (detail is String && detail.isNotEmpty) {
          message = detail;
        }
      }

      if (!mounted) return;

      _showMessage(message);

      return;
    }

    // ----------------------------------------------------------
    // OTHER SERVER ERRORS
    // ----------------------------------------------------------

    String message =
        e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout
        ? 'The server is taking too long to respond. Please try again.'
        : 'Could not connect to the server.';

    if (responseData is Map) {
      final detail = responseData['detail'];

      if (detail is String && detail.isNotEmpty) {
        message = detail;
      }
    }

    _showMessage(message);
  }

  // ============================================================
  // OPEN HOME
  // ============================================================

  Future<void> _signOutAndClearSession() async {
    await _sessionCache.clear();
    await _firebaseAuth.signOut();
  }

  void _openHome(
    AppUser currentUser, {
    required String firebaseUid,
    required bool isSessionVerified,
  }) {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          currentUser: currentUser,
          firebaseUid: firebaseUid,
          isSessionVerified: isSessionVerified,
        ),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email address first.');
      return;
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      _showMessage('Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code}');

      String message = 'Could not send password reset email.';

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please try again.';
          break;

        default:
          message = e.message ?? message;
      }

      _showMessage(message);
    } catch (e) {
      debugPrint('Password reset failed: $e');

      _showMessage('Could not send password reset email.');
    }
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  void _openSignUp() {
    if (isLoading || isCheckingSession) {
      return;
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ----------------------------------------------------------
    // PERSISTENT LOGIN CHECK
    //
    // While Firebase session is being restored and backend
    // account is being checked, don't show the login form.
    // ----------------------------------------------------------

    if (isCheckingSession) {
      return const _SessionCheckingScreen();
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ------------------------------------------------------
          // BACKGROUND
          // ------------------------------------------------------

          if (isDark)
            Positioned.fill(
              child: Image.asset('assets/login_bg.png', fit: BoxFit.cover),
            ),

          // ------------------------------------------------------
          // DARK OVERLAY
          // ------------------------------------------------------
          if (isDark) Container(color: Colors.black.withValues(alpha: 0.30)),

          // ------------------------------------------------------
          // CONTENT
          // ------------------------------------------------------
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

                          // ------------------------------------------------
                          // LOGO
                          // ------------------------------------------------
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/Logo.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),

                                Text(
                                  'M A L I K',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 6,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  'CATALYTIC CATALOGUE',
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ------------------------------------------------
                          // TITLE
                          // ------------------------------------------------
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            'Sign in to continue to your account',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 13),

                          // ------------------------------------------------
                          // EMAIL
                          // ------------------------------------------------
                          _buildInputField(
                            controller: emailController,
                            hintText: 'Email address',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),

                          const SizedBox(height: 10),

                          // ------------------------------------------------
                          // PASSWORD
                          // ------------------------------------------------
                          _buildInputField(
                            controller: passwordController,
                            hintText: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!isLoading) {
                                _login();
                              }
                            },
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
                                color: palette.textMuted,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 34,
                              ),
                            ),
                          ),

                          // ------------------------------------------------
                          // FORGOT PASSWORD
                          // ------------------------------------------------
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: GestureDetector(
                                onTap: isLoading ? null : _forgotPassword,
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ------------------------------------------------
                          // LOGIN BUTTON
                          // ------------------------------------------------
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _login,
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
                              child: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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

                          // ------------------------------------------------
                          // OR
                          // ------------------------------------------------
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: palette.border,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: palette.border,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 13),

                          // ------------------------------------------------
                          // GOOGLE
                          //
                          // Google authentication is intentionally left
                          // disabled until Google provider configuration
                          // is completed in Firebase.
                          // ------------------------------------------------
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () {
                                _showMessage(
                                  'Google sign-in will be enabled after Firebase Google authentication is configured.',
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: palette.border),
                                backgroundColor: palette.surfaceElevated,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image(
                                    image: const AssetImage(
                                      'assets/google.png',
                                    ),
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 17),

                          // ------------------------------------------------
                          // SIGN UP
                          // ------------------------------------------------
                          Center(
                            child: GestureDetector(
                              onTap: _openSignUp,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Don't have an account? ",
                                      style: TextStyle(
                                        color: palette.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Sign Up',
                                      style: TextStyle(
                                        color: palette.accent,
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

  // ============================================================
  // INPUT FIELD
  // ============================================================

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final palette = AppPalette.of(context);
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(color: palette.textPrimary, fontSize: 15),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: palette.textMuted, fontSize: 15),
          prefixIcon: Icon(icon, color: palette.textMuted, size: 14),
          suffixIcon: suffixIcon,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 34,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: palette.input,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: palette.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: palette.accent, width: 1),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SESSION CHECKING SCREEN
// ================================================================

class _SessionCheckingScreen extends StatelessWidget {
  const _SessionCheckingScreen();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isDark) Image.asset('assets/login_bg.png', fit: BoxFit.cover),

          if (isDark) Container(color: Colors.black.withValues(alpha: 0.45)),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/Logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 8),

                Text(
                  'M A L I K',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'CATALYTIC CATALOGUE',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: palette.accent,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
