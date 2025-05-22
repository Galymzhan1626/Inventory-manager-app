import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
