import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../core/constants/constants.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  var _hidePassword = true;
  var _hideConfirmPassword = true;
  var _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      // ------------------------------------------------------------
      // 1. Create the user in Firebase Authentication
      // ------------------------------------------------------------
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw StateError(
          'Firebase did not return the created user.',
        );
      }

      debugPrint('Firebase user created.');
      debugPrint('Firebase UID: ${firebaseUser.uid}');
      debugPrint('Firebase Email: ${firebaseUser.email}');

      // ------------------------------------------------------------
      // 2. Get Firebase ID token
      // ------------------------------------------------------------
      final idToken = await firebaseUser.getIdToken();

      if (idToken == null) {
        throw StateError(
          'Unable to retrieve Firebase ID token.',
        );
      }

      debugPrint('Firebase ID token received.');

      // ------------------------------------------------------------
      // 3. Register the user in our PostgreSQL database
      //    through FastAPI
      // ------------------------------------------------------------
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

      final response = await dio.post(
        ApiConstants.register,
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
          },
        ),
      );

      debugPrint(
        'Registration API status: ${response.statusCode}',
      );

      debugPrint(
        'Registration API response: ${response.data}',
      );

      // ------------------------------------------------------------
      // 4. Registration succeeded
      //
      // The backend should now have:
      //
      // status = pending
      //
      // and should have sent the approval email.
      // ------------------------------------------------------------
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      _showSuccessDialog();

    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Firebase signup error: ${error.code}',
      );

      String message;

      switch (error.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message = 'Password is too weak.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/password registration is not enabled.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet connection.';
          break;

        default:
          message =
              'Could not create your account. Please try again.';
      }

      _showMessage(message);

    } on DioException catch (error) {
      debugPrint(
        'Registration API failed: ${error.response?.statusCode}',
      );

      debugPrint(
        'Registration API response: ${error.response?.data}',
      );

      String message = 'Could not register your account.';

      final responseData = error.response?.data;

      if (responseData is Map<String, dynamic>) {
        final detail = responseData['detail'];

        if (detail is String && detail.isNotEmpty) {
          message = detail;
        }
      }

      _showMessage(message);

    } catch (error) {
      debugPrint(
        'Signup error: $error',
      );

      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10151C),
          title: const Text(
            'Registration submitted',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Your account has been created successfully. '
            'An administrator needs to approve your account '
            'before you can access MALIK.',
            style: TextStyle(
              color: Color(0xFFB7BEC8),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Back to sign in',
                style: TextStyle(
                  color: Color(0xFFFFB21A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050709),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/login_bg.png',
            fit: BoxFit.cover,
          ),

          ColoredBox(
            color: Colors.black.withValues(alpha: .42),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const _BrandMark(),

                        const SizedBox(height: 38),

                        const Text(
                          'Create your account',
                          style: _titleStyle,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          'Register to request access to MALIK.',
                          style: _subtitleStyle,
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 22),

                        // ------------------------------------------------
                        // Email
                        // ------------------------------------------------
                        _SignUpInput(
                          controller: _emailController,
                          icon: Icons.mail_outline,
                          hintText: 'Email address',
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Enter your email address.';
                            }

                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );

                            if (!emailRegex.hasMatch(
                              value.trim(),
                            )) {
                              return 'Enter a valid email address.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // ------------------------------------------------
                        // Password
                        // ------------------------------------------------
                        _SignUpInput(
                          controller: _passwordController,
                          icon: Icons.lock_outline,
                          hintText: 'Password',
                          obscureText: _hidePassword,
                          textInputAction:
                              TextInputAction.next,
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _hidePassword =
                                    !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                              color: const Color(0xFF8A929E),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Enter a password.';
                            }

                            if (value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // ------------------------------------------------
                        // Confirm password
                        // ------------------------------------------------
                        _SignUpInput(
                          controller:
                              _confirmPasswordController,
                          icon: Icons.lock_outline,
                          hintText: 'Confirm password',
                          obscureText:
                              _hideConfirmPassword,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) {
                              _signUp();
                            }
                          },
                          suffixIcon: IconButton(
                            tooltip: _hideConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _hideConfirmPassword =
                                    !_hideConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _hideConfirmPassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                              color: const Color(0xFF8A929E),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Confirm your password.';
                            }

                            if (value !=
                                _passwordController.text) {
                              return 'Passwords do not match.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // ------------------------------------------------
                        // Sign Up button
                        // ------------------------------------------------
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFFFB21A),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  const Color(0xFFB78013),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(9),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Text(
                                        'Create account',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Your account will remain pending until an administrator approves your access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9AA3B0),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ------------------------------------------------
                        // Back to login
                        // ------------------------------------------------
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context)
                                      .pop();
                                },
                          child: const Text(
                            'Already have an account? Sign in',
                            style: TextStyle(
                              color: Color(0xFFFFB21A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// BRAND MARK
// ============================================================

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/Logo.png',
          width: 96,
          height: 96,
        ),

        const SizedBox(height: 4),

        const Text(
          'M A L I K',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 5,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'CATALYTIC CATALOGUE',
          style: TextStyle(
            color: Color(0xFFFFB21A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}


// ============================================================
// INPUT FIELD
// ============================================================

class _SignUpInput extends StatelessWidget {
  const _SignUpInput({
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
      ),
      cursorColor: const Color(0xFFFFB21A),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF7F8793),
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF8A929E),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            const Color(0xFF080E15).withValues(alpha: .84),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: _border(
          const Color(0xFF263342),
        ),
        focusedBorder: _border(
          const Color(0xFF8C6418),
        ),
        errorBorder: _border(
          const Color(0xFFE75A7D),
        ),
        focusedErrorBorder: _border(
          const Color(0xFFE75A7D),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(
        color: color,
      ),
    );
  }
}


// ============================================================
// STYLES
// ============================================================

const _titleStyle = TextStyle(
  color: Colors.white,
  fontSize: 26,
  fontWeight: FontWeight.w700,
);

const _subtitleStyle = TextStyle(
  color: Color(0xFF9A9DA5),
  fontSize: 13,
);