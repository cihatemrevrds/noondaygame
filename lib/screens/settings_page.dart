import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/menu_button.dart';
import '../widgets/editable_field.dart';
import '../widgets/profile_picture_selector.dart';
import '../widgets/password_change_dialog.dart';
import '../models/user_settings.dart';
import '../services/user_settings_service.dart';
import 'login_or_register_menu.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final UserSettingsService _settingsService = UserSettingsService();
  bool _isLoading = true;
  late UserSettings _userSettings;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getUserSettings();
      setState(() {
        _userSettings = settings;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to default settings
      setState(() {
        _userSettings = UserSettings(
          nickname: FirebaseAuth.instance.currentUser?.displayName ?? 'Cowboy',
          email: FirebaseAuth.instance.currentUser?.email ?? 'user@example.com',
          profilePicture: 'sheriff.jpg',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserSettings() async {
    try {
      setState(() => _isLoading = true);
      await _settingsService.saveUserSettings(_userSettings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Settings saved',
              style: TextStyle(fontFamily: 'Rye'),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving settings: $e',
              style: const TextStyle(fontFamily: 'Rye'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  void _showProfilePictureSelector() {
    showDialog(
      context: context,
      builder: (context) => ProfilePictureSelector(
        currentImage: _userSettings.profilePicture,
        onImageSelected: (image) {
          setState(() {
            _userSettings = _userSettings.copyWith(profilePicture: image);
          });
        },
      ),
    );
  }
  
  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => PasswordChangeDialog(
        onPasswordChange: (currentPassword, newPassword) async {
          setState(() => _isLoading = true);
          try {
            final result = await _settingsService.updatePassword(
              currentPassword, 
              newPassword
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result 
                      ? 'Password changed successfully' 
                      : 'Failed to change password. Check your current password.',
                    style: const TextStyle(fontFamily: 'Rye'),
                  ),
                  backgroundColor: result ? Colors.green : Colors.red,
                ),
              );
              setState(() => _isLoading = false);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error changing password: $e',
                    style: const TextStyle(fontFamily: 'Rye'),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => _isLoading = false);
            }
          }
        },
      ),
    );
  }

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
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.brown),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User Profile Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
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
                          'USER PROFILE',
                          style: TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 18,
                            color: Colors.brown,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Profile picture and edit button
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.brown, width: 3),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/roles/${_userSettings.profilePicture}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback image if the asset doesn't exist
                                      return Image.asset(
                                        'assets/images/roles/sheriff.jpg',
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _showProfilePictureSelector,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.brown,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Editable user fields
                        EditableField(
                          label: 'nickname',
                          value: _userSettings.nickname,
                          onChanged: (value) {
                            setState(() {
                              _userSettings = _userSettings.copyWith(nickname: value);
                            });
                          },
                        ),
                        
                        EditableField(
                          label: 'e-mail:',
                          value: _userSettings.email,
                          onChanged: (value) {
                            setState(() {
                              _userSettings = _userSettings.copyWith(email: value);
                            });
                          },
                          isEditable: false, // Email can't be edited in this simple version
                        ),
                          Row(
                          children: [
                            Expanded(
                              child: EditableField(
                                label: 'şifre:',
                                value: '********', // Placeholder, not the real password
                                onChanged: (_) {
                                  // Not actually changing the password through this field
                                },
                                isPassword: true,
                                isEditable: false,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.brown,
                              ),
                              onPressed: _showPasswordChangeDialog,
                              tooltip: 'Change Password',
                            ),
                          ],
                        ),
                        
                        const Divider(color: Colors.brown),
                      ],
                    ),
                  ),

                  // Sound Settings Card
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
                              value: _userSettings.soundEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _userSettings = _userSettings.copyWith(soundEnabled: value);
                                });
                              },
                              activeColor: Colors.brown,
                            ),
                          ],
                        ),
                        if (_userSettings.soundEnabled)
                          Slider(
                            value: _userSettings.soundVolume,
                            onChanged: (value) {
                              setState(() {
                                _userSettings = _userSettings.copyWith(soundVolume: value);
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
                              value: _userSettings.musicEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _userSettings = _userSettings.copyWith(musicEnabled: value);
                                });
                              },
                              activeColor: Colors.brown,
                            ),
                          ],
                        ),
                        if (_userSettings.musicEnabled)
                          Slider(
                            value: _userSettings.musicVolume,
                            onChanged: (value) {
                              setState(() {
                                _userSettings = _userSettings.copyWith(musicVolume: value);
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
                    onPressed: _saveUserSettings,
                  ),
                  const SizedBox(height: 20),                  MenuButton(
                    text: 'LOG OUT',
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        // Navigate to login screen after sign out
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginOrRegisterMenu(),
                            ),
                            (route) => false, // Remove all previous routes
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error logging out: $e',
                                style: const TextStyle(fontFamily: 'Rye'),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
