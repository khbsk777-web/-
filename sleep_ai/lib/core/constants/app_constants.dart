class AppConstants {
  static const String appName = 'Sleep AI';
  static const String appVersion = '1.0.0';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String sleepSessionsCollection = 'sleep_sessions';
  static const String snoreEventsCollection = 'snore_events';
  static const String healthDataCollection = 'health_data';
  static const String aiReportsCollection = 'ai_reports';

  // SharedPreferences Keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserId = 'user_id';
  static const String keyIsPremium = 'is_premium';
  static const String keyOpenAIKey = 'openai_api_key';
  static const String keyBedtimeHour = 'bedtime_hour';
  static const String keyBedtimeMinute = 'bedtime_minute';
  static const String keyWakeHour = 'wake_hour';
  static const String keyWakeMinute = 'wake_minute';

  // RevenueCat
  static const String revenueCatAppleKey = 'YOUR_REVENUECAT_APPLE_KEY';
  static const String revenueCatGoogleKey = 'YOUR_REVENUECAT_GOOGLE_KEY';
  static const String premiumEntitlement = 'premium';
  static const String monthlyProductId = 'sleep_ai_premium_monthly';

  // OpenAI
  static const String openAIBaseUrl = 'https://api.openai.com/v1';
  static const String openAIModel = 'gpt-4o';

  // Audio
  static const int sampleRate = 44100;
  static const double snoreThresholdDb = 45.0;
  static const int snoreDetectionWindowMs = 2000;
  static const int minSnoreDurationMs = 3000;

  // Sleep Score
  static const int idealSleepMinutes = 480; // 8 hours
  static const double snorePenaltyPerEvent = 2.0;

  // Free tier limit
  static const int freeTierDays = 7;

  // Notification IDs
  static const int bedtimeNotificationId = 1001;
  static const int wakeupNotificationId = 1002;
  static const int aiReportNotificationId = 1003;

  // Background Service
  static const String bgServiceId = 'sleep_ai_bg_service';
  static const String bgTaskRecording = 'sleep_recording';
}
