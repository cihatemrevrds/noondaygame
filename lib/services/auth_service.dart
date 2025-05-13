import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Kullanıcıyı email ve şifre ile giriş yaptır
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return {
        'success': true,
        'user': result.user
      };
    } on FirebaseAuthException catch (e) {
      print('Detailed sign in error: $e');
      String errorMessage;

      // Specific error handling for common Firebase Auth errors
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email. Please register first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid. Please enter a proper email.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed login attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection and try again.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message ?? e.code}';
      }
      
      return {
        'success': false,
        'errorMessage': errorMessage,
        'errorCode': e.code
      };
    } catch (e) {
      print('Unexpected sign in error: $e');
      return {
        'success': false,
        'errorMessage': 'An unexpected error occurred. Please try again later.',
        'error': e.toString()
      };
    }
  }  // Yeni kullanıcı oluştur
  Future<Map<String, dynamic>> signUp(String email, String password, String username) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Save the username in the user's profile
      await result.user?.updateDisplayName(username);
      
      return {
        'success': true,
        'user': result.user
      };
    } on FirebaseAuthException catch (e) {
      print('Detailed sign up error: $e');
      String errorMessage;
      
      // Specific error handling for common Firebase Auth errors
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please use a different email or login.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid. Please enter a proper email.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled. Please contact support.';
          break;
        case 'weak-password':
          errorMessage = 'Your password is too weak. Please choose a stronger password.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection and try again.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message ?? e.code}';
      }
      
      return {
        'success': false,
        'errorMessage': errorMessage,
        'errorCode': e.code
      };
    } catch (e) {
      print('Unexpected sign up error: $e');
      return {
        'success': false,
        'errorMessage': 'An unexpected error occurred. Please try again later.',
        'error': e.toString()
      };
    }
  }

  // Oturumu kapat
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Kullanıcı oturumda mı? Auth state listener için
  Stream<User?> get userChanges => _auth.authStateChanges();
}
