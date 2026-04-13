class AuthException implements Exception {
  final String message;
  final String? field;

  AuthException(this.message, {this.field});

  @override
  String toString() => message;
}
