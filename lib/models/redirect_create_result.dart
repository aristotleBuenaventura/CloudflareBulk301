class RedirectCreateResult {
  const RedirectCreateResult({
    required this.created,
    required this.message,
  });

  final bool created;
  final String message;

  factory RedirectCreateResult.created(String message) {
    return RedirectCreateResult(created: true, message: message);
  }

  factory RedirectCreateResult.updated(String message) {
    return RedirectCreateResult(created: true, message: message);
  }

  factory RedirectCreateResult.alreadyExists(String message) {
    return RedirectCreateResult(created: false, message: message);
  }
}
