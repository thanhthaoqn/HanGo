import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import '../../data/services/auth_service.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'learner/learner_home_page.dart';
import 'admin/admin_dashboard_page.dart';
import 'trainer/trainer_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  
  final _authService = AuthService();
  
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '793292778359-frlad2ktuqo6mo27fkilqbjqcdqbqko1.apps.googleusercontent.com',
    scopes: const ['email', 'profile'],
  );
  
  StreamSubscription<GoogleSignInAccount?>? _googleSignInSubscription;

  @override
  void initState() {
    super.initState();
    _googleSignInSubscription = _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _handleGoogleSignInSuccess(account);
      }
    });
    _googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _googleSignInSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await _authService.login(email, password);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success']) {
        final roles = List<String>.from(result['data']['roles'] ?? []);
        final isAdmin = roles.any((r) => r.contains('ADMIN'));
        final isTrainer = roles.any((r) => r.contains('TRAINER'));
        debugPrint('Sign in success! Navigating. Admin: $isAdmin, Trainer: $isTrainer. Data: ${result['data']}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in successful!'),
            backgroundColor: Color(0xFF28B79B),
          ),
        );
        Widget destination;
        if (isAdmin) {
          destination = const AdminDashboardPage();
        } else if (isTrainer) {
          destination = const TrainerDashboardPage();
        } else {
          destination = const LearnerHomePage();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => destination,
          ),
        );
      } else {
        debugPrint('Sign in failed! Error: ${result['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sign in failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleGoogleSignInSuccess(GoogleSignInAccount googleUser) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to retrieve ID Token from Google.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final result = await _authService.loginWithGoogle(idToken: idToken);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (result['success']) {
          final String name = googleUser.displayName ?? 'Google User';
          final roles = List<String>.from(result['data']['roles'] ?? []);
          final isAdmin = roles.any((r) => r.contains('ADMIN'));
          final isTrainer = roles.any((r) => r.contains('TRAINER'));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign in successful: Welcome, $name!'),
              backgroundColor: const Color(0xFF28B79B),
            ),
          );
          Widget destination;
          if (isAdmin) {
            destination = const AdminDashboardPage();
          } else if (isTrainer) {
            destination = const TrainerDashboardPage();
          } else {
            destination = const LearnerHomePage();
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => destination,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Google Sign In failed.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign In failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildGoogleSignInButton() {
    if (kIsWeb) {
      try {
        final plugin = GoogleSignInPlatform.instance as web.GoogleSignInPlugin;
        return Center(
          child: plugin.renderButton(
            configuration: web.GSIButtonConfiguration(
              type: web.GSIButtonType.standard,
              theme: web.GSIButtonTheme.outline,
              size: web.GSIButtonSize.large,
              text: web.GSIButtonText.signinWith,
              shape: web.GSIButtonShape.rectangular,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error rendering GIS button: $e');
      }
    }
    
    // Fallback for non-web or if platform rendering fails
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading ? null : () async {
          try {
            final GoogleSignInAccount? account = await _googleSignIn.signIn();
            if (account != null) {
              _handleGoogleSignInSuccess(account);
            }
          } catch (e) {
            debugPrint('Google Sign In Error: $e');
          }
        },
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) => const Text('G'),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isDesktop) ...[
            // Left Panel: Illustration and decoration (50% width)
            Expanded(
              child: Container(
                color: const Color(0xFF28B79B),
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            'https://res.cloudinary.com/diqekap4o/image/upload/v1781621072/login_tolpmx.png',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 100,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Your trusted education\npartner',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Icon(Icons.school_outlined, color: Colors.white70, size: 20),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Right Panel: Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64.0 : 24.0,
                vertical: 36.0,
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HanGo logo
                        Image.network(
                          'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                          height: 60,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE6FFFA),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.school_outlined,
                                      color: Color(0xFF28B79B),
                                      size: 24,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                RichText(
                                  text: const TextSpan(
                                    text: 'Han',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                      fontFamily: 'Outfit',
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Go',
                                        style: TextStyle(
                                          color: Color(0xFF28B79B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 48),
                        
                        // Sign In Title
                        const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Email Field
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter your email address',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                            prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF9CA3AF), size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required';
                            }
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9CA3AF), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: const Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.redAccent),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Remember me & Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF28B79B),
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember me',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF28B79B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        
                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF28B79B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        'Sign In',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Divider
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or continue with',
                                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                              ),
                            ),
                            Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Google Sign In Button
                        _buildGoogleSignInButton(),
                        const SizedBox(height: 36),
                        
                        // Sign Up Link
                        Center(
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const RegisterPage(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Sign up',
                                      style: TextStyle(
                                        color: Color(0xFF28B79B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
