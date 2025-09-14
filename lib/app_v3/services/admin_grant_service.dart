import 'package:cloud_functions/cloud_functions.dart';

class AdminGrantService {
  static Future<String?> grantAdminByEmail(String email) async {
    try {
      // Functions are deployed in us-east4 per setGlobalOptions
      final functions = FirebaseFunctions.instanceFor(region: 'us-east4');
      final callable = functions.httpsCallable('grantAdmin');
  final result = await callable.call(<String, dynamic>{'email': email, 'bootstrap': true});
      return result.data?.toString() ?? 'Success';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
