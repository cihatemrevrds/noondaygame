import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import '../widgets/input_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'REGISTER',
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
                      'Username',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputField(
                      controller: _usernameController,
                      hintText: 'Choose a username',
                    ),
                    const SizedBox(height: 20),
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
                      hintText: 'Choose a password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontFamily: 'Rye',
                        fontSize: 16,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm your password',
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              MenuButton(
                text: 'REGISTER',
                onPressed: () {
                  // Validate fields
                  if (_usernameController.text.isEmpty ||
                      _emailController.text.isEmpty ||
                      _passwordController.text.isEmpty ||
                      _confirmPasswordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please fill in all fields',
                          style: TextStyle(fontFamily: 'Rye'),
                        ),
                      ),
                    );
                    return;
                  }

                  if (_passwordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Passwords do not match',
                          style: TextStyle(fontFamily: 'Rye'),
                        ),
                      ),
                    );
                    return;
                  }                  // In a real app, this would register the user with a backend
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Registration successful! Please login with your credentials.',
                        style: TextStyle(fontFamily: 'Rye'),
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // Navigate back to login screen after a short delay
                  Future.delayed(const Duration(seconds: 2), () {
                    Navigator.pop(context); // Go back to LoginOrRegisterMenu
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
