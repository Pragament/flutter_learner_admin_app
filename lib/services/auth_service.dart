import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        final result = await _auth.signInWithPopup(provider);
        return result.user;
      } else {
        await GoogleSignIn.instance.initialize(
          serverClientId: kGoogleServerClientId,
        );
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw Exception('No ID token');
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final result = await _auth.signInWithCredential(credential);
        return result.user;
      }
    } catch (e) {
      rethrow;
    }
  }

  // Force refresh to trigger StreamBuilder rebuild
  Future<void> refreshUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
