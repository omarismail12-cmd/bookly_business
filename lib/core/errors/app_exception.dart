class AppError implements Exception {
  final String message;
  final Object? cause;
  const AppError(this.message, {this.cause});
  @override
  String toString() => message;
}
