class ClosedException implements Exception {
  final dynamic message;

  ClosedException([this.message]);

  String toString() {
    Object? message = this.message;
    if (message == null) return "Context closed";
    return "Exception: $message";
  }
}
