import 'package:equatable/equatable.dart';

/// Base class for all failures
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Firestore failures
class FirestoreFailure extends Failure {
  const FirestoreFailure(super.message);
}

/// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Network failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

