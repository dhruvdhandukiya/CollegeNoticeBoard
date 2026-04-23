import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStream => _auth.authStateChanges();

  /// Sign in and return UserModel with role from Firestore
  Future<UserModel?> signIn(String email, String password) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      // Validate password
      if (password.isEmpty || password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password must be at least 6 characters',
        );
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final doc = await _db
        .collection('users').doc(cred.user!.uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No profile found. Contact admin.',
        );
      }

      return UserModel.fromDoc(doc);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: e.toString(),
      );
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel?> getCurrentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final doc = await _db.collection('users').doc(u.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  /// Admin creates a student account from the app
  Future<UserModel> createStudent({
    required String email,
    required String password,
    required String name,
    required String role,
    required String department,
    required String year,
    String? committee,
    String? rollNumber,
    String? phone,
  }) async {
    if (!_isValidEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address',
      );
    }

    if (password.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final user = UserModel(
      uid:        cred.user!.uid,
      email:      email.trim().toLowerCase(),
      name:       name,
      role:       role,
      department: department,
      year:       year,
      committee:  committee,
      rollNumber: rollNumber,
      phone:      phone,
      isActive:   true,
      createdAt:  DateTime.now(),
    );

    await _db.collection('users').doc(user.uid).set(user.toMap());
    return user;
  }

  /// Helper method to validate email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }
}