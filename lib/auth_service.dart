import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // one stream, shared by the gate
  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // update the password, sign in again first if firebase asks for it
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You need to sign in again.');
    }
    final email = user.email;
    if (email == null) {
      throw StateError('This account does not have an email address.');
    }

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') {
        rethrow;
      }
      // confirm it is really us, then try the update one more time
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    }
  }
}

// turn firebase error codes into something a user can read
String authErrorMessage(Object error) {
  if (error is StateError) {
    return error.message;
  }
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Check your connection and try again.';
  }

  if (error.code == 'invalid-email') {
    return 'That email address does not look right.';
  }
  if (error.code == 'email-already-in-use') {
    return 'That email already has an account. Try signing in.';
  }
  if (error.code == 'weak-password') {
    return 'Use at least 6 characters for the password.';
  }
  if (error.code == 'wrong-password' ||
      error.code == 'invalid-credential' ||
      error.code == 'user-not-found') {
    return 'The email or password is not correct.';
  }
  if (error.code == 'user-disabled') {
    return 'That account has been disabled.';
  }
  if (error.code == 'too-many-requests') {
    return 'Too many attempts. Wait a minute and try again.';
  }
  if (error.code == 'network-request-failed') {
    return 'No internet connection. Check your network and try again.';
  }
  if (error.code == 'requires-recent-login') {
    return 'Please sign in again before changing the password.';
  }
  return 'That did not work. Please try again.';
}
