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
    final cred = await _auth.signInWithEmailAndPassword(
      email: email, password: password);
    final doc = await _db
      .collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw Exception('No profile found. Contact admin.');
    }
    return UserModel.fromDoc(doc);
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
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password);
    final user = UserModel(
      uid:        cred.user!.uid,
      email:      email,
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
}