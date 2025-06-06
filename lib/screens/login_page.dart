import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import '../widgets/input_field.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter both email and password',
            style: TextStyle(fontFamily: 'Rye'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });    try {
      final result = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );      if (result['success'] == true) {
        // Successfully logged in - AuthWrapper will automatically handle navigation
        // Just show success message and let the stream handle the navigation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Login successful!',
                style: TextStyle(fontFamily: 'Rye'),
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Login failed with specific error
        final errorMessage = result['errorMessage'] ?? 'Login failed. Please check your credentials.';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: const TextStyle(fontFamily: 'Rye'),
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.redAccent,
            ),
          );
          
          // Log detailed error information
          print('Login failed: ${result['errorCode'] ?? 'Unknown error'} - $errorMessage');
        }
      }
    } catch (e) {
      print('Unexpected login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Rye'),
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'LOGIN',
          style: TextStyle(
            fontFamily: 'Rye',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/saloon_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputField(
                      controller: _passwordController,
                      hintText: 'Enter your password',
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF4E2C0B))
                : MenuButton(
                    text: 'LOGIN',
                    onPressed: _login,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
