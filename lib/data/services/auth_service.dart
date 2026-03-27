import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../core/errors/failures.dart';

/// Authentication service for managing user authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<User> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) {
        throw const AuthFailure('Đăng nhập thất bại');
      }
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      print('[AuthService] signIn FirebaseAuthException code: ${e.code}, message: ${e.message}');
      throw AuthFailure(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('[AuthService] signIn unknown error: $e');
      throw AuthFailure('Lỗi không xác định: $e');
    }
  }

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      print('[AuthService] signUp FirebaseAuthException code: ${e.code}, message: ${e.message}');
      throw AuthFailure(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('[AuthService] signUp unknown error: $e');
      throw AuthFailure('Lỗi không xác định: $e');
    }
  }

  // /// Sign in with Google
  // Future<User> signInWithGoogle() async {
  //   try {
  //     // Lazy initialize GoogleSignIn
  //     _googleSignIn ??= GoogleSignIn();
      
  //     final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
  //     if (googleUser == null) {
  //       throw const AuthFailure('Đăng nhập Google bị hủy');
  //     }

  //     final GoogleSignInAuthentication googleAuth =
  //         await googleUser.authentication;

  //     final credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );

  //     final userCredential = await _auth.signInWithCredential(credential);
  //     if (userCredential.user == null) {
  //       throw const AuthFailure('Đăng nhập Google thất bại');
  //     }

  //     return userCredential.user!;
  //   } on FirebaseAuthException catch (e) {
  //     throw AuthFailure(_getAuthErrorMessage(e.code));
  //   } catch (e) {
  //     throw AuthFailure('Lỗi đăng nhập Google: $e');
  //   }
  // }

  /// Sign in with Apple
  // Future<User> signInWithApple() async {
  //   try {
  //     final appleCredential = await SignInWithApple.getAppleIDCredential(
  //       scopes: [
  //         AppleIDAuthorizationScopes.email,
  //         AppleIDAuthorizationScopes.fullName,
  //       ],
  //     );

  //     final oauthCredential = OAuthProvider("apple.com").credential(
  //       idToken: appleCredential.identityToken,
  //       accessToken: appleCredential.authorizationCode,
  //     );

  //     final userCredential = await _auth.signInWithCredential(oauthCredential);
  //     if (userCredential.user == null) {
  //       throw const AuthFailure('Đăng nhập Apple thất bại');
  //     }

  //     return userCredential.user!;
  //   } on FirebaseAuthException catch (e) {
  //     throw AuthFailure(_getAuthErrorMessage(e.code));
  //   } catch (e) {
  //     throw AuthFailure('Lỗi đăng nhập Apple: $e');
  //   }
  // }

  /// Sign out
  Future<void> signOut() async {
    try {
      final futures = <Future>[_auth.signOut()];
      
      // Only sign out from Google if it was initialized
      if (_googleSignIn != null) {
        futures.add(_googleSignIn!.signOut());
      }
      
      await Future.wait(futures);
    } catch (e) {
      throw AuthFailure('Lỗi đăng xuất: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw AuthFailure('Lỗi gửi email: $e');
    }
  }

  /// Update current user's avatar photoUrl in Firestore
  Future<void> updatePhotoUrl(String photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Không tìm thấy người dùng hiện tại');
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'photoUrl': photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw AuthFailure('Lỗi cập nhật ảnh đại diện: $e');
    }
  }




  /// Get user-friendly error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng';
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa';
      case 'too-many-requests':
        return 'Đăng nhập thất bại quá nhiều lần. Vui lòng thử lại sau';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Kiểm tra internet và thử lại';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật';
      default:
        return 'Đăng nhập thất bại. Vui lòng thử lại';
    }
  }
}

