import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kullanıcıyı email ve şifre ile giriş yaptır
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // Yeni kullanıcı oluştur
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Sign up error: $e');
      return null;
    }
  }

  // Oturumu kapat
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Kullanıcı oturumda mı? Auth state listener için
  Stream<User?> get userChanges => _auth.authStateChanges();
}
