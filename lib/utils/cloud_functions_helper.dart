import 'package:cloud_functions/cloud_functions.dart';
/// Provides a consistent way to call Firebase Cloud Functions across
/// platforms while keeping Firebase Auth/App Check tokens intact.
///
/// We intentionally use the standard callable endpoint for every
/// platform (including web) so Firebase automatically attaches the
/// current user's auth token. Attempting to hit the Google Cloud
/// REST API directly would require OAuth credentials and results in
/// 401 errors for signed-in app users.
HttpsCallable callableForPlatform({
  required FirebaseFunctions functions,
  required String functionName,
  required String region,
}) {
  return functions.httpsCallable(functionName);
}
