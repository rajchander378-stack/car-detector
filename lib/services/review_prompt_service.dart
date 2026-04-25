import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPromptService {
  static const String _successfulIdentificationCountKey =
      'review_successful_identification_count';
  static const String _lastPromptAtCountKey = 'review_last_prompt_at_count';
  static const String _promptAttemptCountKey = 'review_prompt_attempt_count';

  static const int _firstPromptThreshold = 3;
  static const int _repeatPromptInterval = 8;

  final InAppReview _inAppReview;

  ReviewPromptService({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  Future<void> recordSuccessfulIdentification() async {
    final prefs = await SharedPreferences.getInstance();
    final successfulCount =
        (prefs.getInt(_successfulIdentificationCountKey) ?? 0) + 1;
    await prefs.setInt(_successfulIdentificationCountKey, successfulCount);

    final promptAttemptCount = prefs.getInt(_promptAttemptCountKey) ?? 0;
    final lastPromptAtCount = prefs.getInt(_lastPromptAtCountKey) ?? 0;

    final isEligibleForFirstPrompt =
        promptAttemptCount == 0 && successfulCount >= _firstPromptThreshold;
    final isEligibleForRepeatPrompt = promptAttemptCount > 0 &&
        successfulCount - lastPromptAtCount >= _repeatPromptInterval;

    if (!isEligibleForFirstPrompt && !isEligibleForRepeatPrompt) {
      return;
    }

    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) return;

      await _inAppReview.requestReview();
      await prefs.setInt(_lastPromptAtCountKey, successfulCount);
      await prefs.setInt(_promptAttemptCountKey, promptAttemptCount + 1);
    } catch (_) {
      // Fail silently: review prompts are best-effort only.
    }
  }
}
