import 'package:firebase_data_connect/firebase_data_connect.dart';







class DefaultConnector {
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east1',
    'default',
    'flutter_application_1',
  );

  DefaultConnector({required this.dataConnect});
  static DefaultConnector get instance {
    return DefaultConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}

