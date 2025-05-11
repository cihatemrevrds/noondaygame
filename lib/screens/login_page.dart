import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import '../widgets/input_field.dart';
import 'main_menu.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                      hintText: 'Enter your username',
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
              MenuButton(
                text: 'LOGIN',
                onPressed: () {
                  if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter both username and password',
                          style: TextStyle(fontFamily: 'Rye'),
                        ),
                      ),
                    );
                    return;
                  }

                  // In a real app, this would check credentials against a backend
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainMenu(
                        username: _usernameController.text,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
