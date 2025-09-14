/// Centralized feature flags & debug toggles.
/// Adjust these for build variants or local experimentation.
class FeatureFlags {
  /// Show the in-app floating debug overlay panel.
  static const bool showDebugOverlay = false; // Disabled to avoid UI noise.

  /// Allow navigation to any legacy v1 pages (kept for reference).
  /// Currently disabled to prevent "mixed pages" confusion.
  static const bool enableLegacyPages = false;
}
