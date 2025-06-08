import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_settings.dart';

class UserSettingsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the current user settings
  Future<UserSettings> getUserSettings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Try to get settings from Firestore
      final doc = await _firestore.collection('user_settings').doc(user.uid).get();
      
      if (doc.exists && doc.data() != null) {
        // Return settings from Firestore
        return UserSettings.fromMap(doc.data()!);
      } else {
        // Create default settings
        final defaultSettings = UserSettings(
          nickname: user.displayName ?? 'Cowboy',
          email: user.email ?? '',
          profilePicture: 'normal_man.png',
          soundEnabled: true,
          soundVolume: 0.8,
          musicEnabled: true,
          musicVolume: 0.6,
        );
        
        // Save the default settings to Firestore
        await saveUserSettings(defaultSettings);
        
        return defaultSettings;
      }
    } catch (e) {
      // Return default settings if there's any error
      return UserSettings(
        nickname: _auth.currentUser?.displayName ?? 'Cowboy',
        email: _auth.currentUser?.email ?? '',
      );
    }
  }

  // Save user settings to Firestore
  Future<void> saveUserSettings(UserSettings settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Update display name if nickname has changed
      if (user.displayName != settings.nickname) {
        await user.updateDisplayName(settings.nickname);
      }
      
      // Save settings to Firestore
      await _firestore.collection('user_settings').doc(user.uid).set(settings.toMap());
      
    } catch (e) {
      print('Error saving user settings: $e');
      rethrow;
    }
  }

  // Update user password
  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No authenticated user found or email is missing');
      }

      // Re-authenticate the user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Change password
      await user.updatePassword(newPassword);
      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }
}
