/// Central place to map app meal plans to Stripe Price IDs.
///
/// Configure via --dart-define to avoid hardcoding in source. Example:
///   flutter run \
///     --dart-define=STRIPE_PRICE_1_MEAL=price_123 \
///     --dart-define=STRIPE_PRICE_2_MEAL=price_456 \
///     --dart-define=STRIPE_PRICE_3_MEAL=price_789
///
/// Note: Price IDs are not secrets, but using dart-define lets you keep
/// dev/test/prod configs separate without code changes.
class StripePricesConfig {
  // Example: 'price_1AbCdEfGhIjKlMn' (from your Stripe Dashboard)
  static const String oneMealPerDay = String.fromEnvironment(
    'STRIPE_PRICE_1_MEAL',
    defaultValue: 'price_1SKVNgPJ2bllJ7ptK10uXJbZ', // Premium
  );
  static const String twoMealsPerDay = String.fromEnvironment(
    'STRIPE_PRICE_2_MEAL',
    defaultValue: 'price_1SKVPMPJ2bllJ7ptWEGzul37', // Pro
  );
  static const String threeMealsPerDay = String.fromEnvironment(
    'STRIPE_PRICE_3_MEAL',
    defaultValue: 'price_1SKVPZPJ2bllJ7ptiSCAdMT9', // Standard
  );

  /// Returns the Stripe Price ID for the given MealPlanModelV3.id.
  /// Plan IDs expected: '1' (1 meal/day), '2' (2/day), '3' (3/day).
  static String priceIdForPlanId(String planId) {
    switch (planId) {
      case '1':
        return oneMealPerDay;
      case '2':
        return twoMealsPerDay;
      case '3':
        return threeMealsPerDay;
      default:
        return '';
    }
  }

  /// Quick sanity check to know if all prices are configured.
  static bool get isConfigured =>
      oneMealPerDay.isNotEmpty &&
      twoMealsPerDay.isNotEmpty &&
      threeMealsPerDay.isNotEmpty;
}
