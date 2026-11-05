class AppConstants {
  AppConstants._();

  // App Meta
  static const String appName = 'MedWise';
  static const String appTagline = 'Smart Chemist Companion & Offline Medicine Cabinet';

  // Asset Paths
  static const String bundledDbAssetPath = 'assets/database/indian_medicines.db';
  static const String drugInteractionsAssetPath = 'assets/data/drug_interactions.json';
  static const String logoAssetPath = 'assets/images/logo.jpg';

  // SQLite DB File Names
  static const String bundledDbFileName = 'indian_medicines.db';
  static const String userCabinetDbFileName = 'medwise_user.db';

  // Confidence Thresholds for OCR & Fuzzy Matching
  static const double confidenceHighThreshold = 0.90;   // 90%+ Direct match (Green)
  static const double confidenceMediumThreshold = 0.70; // 70-89% Suggestion (Amber)

  // Domain Defaults
  static const int openSterilityDaysLimit = 28; // 28-day rule for eye drops & syrups
  static const double lowStockThresholdDays = 2.0; // Refill alert when <= 2 days left
}
