import 'package:flutter/material.dart';
import '../widgets/menu_button.dart';
import 'login_or_register_menu.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _soundVolume = 0.8;
  double _musicVolume = 0.6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E2C0B),
        title: const Text(
          'SETTINGS',
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
                    // Sound settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sound Effects',
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 18,
                            color: Colors.brown,
                          ),
                        ),
                        Switch(
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() {
                              _soundEnabled = value;
                            });
                          },
                          activeColor: Colors.brown,
                        ),
                      ],
                    ),
                    if (_soundEnabled)
                      Slider(
                        value: _soundVolume,
                        onChanged: (value) {
                          setState(() {
                            _soundVolume = value;
                          });
                        },
                        activeColor: Colors.brown,
                        inactiveColor: Colors.brown.withOpacity(0.3),
                      ),
                    const Divider(color: Colors.brown),
                    // Music settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Music',
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 18,
                            color: Colors.brown,
                          ),
                        ),
                        Switch(
                          value: _musicEnabled,
                          onChanged: (value) {
                            setState(() {
                              _musicEnabled = value;
                            });
                          },
                          activeColor: Colors.brown,
                        ),
                      ],
                    ),
                    if (_musicEnabled)
                      Slider(
                        value: _musicVolume,
                        onChanged: (value) {
                          setState(() {
                            _musicVolume = value;
                          });
                        },
                        activeColor: Colors.brown,
                        inactiveColor: Colors.brown.withOpacity(0.3),
                      ),
                    const Divider(color: Colors.brown),
                    // Other settings could be added here
                  ],
                ),
              ),
              const SizedBox(height: 30),
              MenuButton(
                text: 'SAVE SETTINGS',
                onPressed: () {
                  // In a real app, this would save settings to local storage
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Settings saved',
                        style: TextStyle(fontFamily: 'Rye'),
                      ),
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              MenuButton(
                text: 'LOG OUT',
                onPressed: () {
                  // In a real app, this would clear the user's session
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginOrRegisterMenu(),
                    ),
                    (route) => false, // Remove all previous routes
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
