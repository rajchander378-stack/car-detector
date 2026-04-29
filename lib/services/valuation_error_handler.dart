class ValuationErrorHandler {
  const ValuationErrorHandler._();

  /// Returns true for errors where the plate is genuinely invalid or unknown —
  /// these should be shown directly to the user with no Gemini fallback attempt.
  static bool isTerminalError(String message) {
    return message.contains('InvalidSearchTerm') ||
        message.contains('not found') ||
        message.contains('No vehicle') ||
        message.contains('authentication');
  }

  /// Maps a VDGL error message to a user-readable string.
  static String toUserMessage(String message) {
    if (message.contains('InvalidSearchTerm')) {
      return 'Registration not recognised — check the plate and try again.';
    }
    return message;
  }
}
