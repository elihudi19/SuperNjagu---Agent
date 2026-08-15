import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import 'data_repository.dart';
import 'pushbullet_service.dart';

/// Hali ya pamoja inayotumika na skrini zote baada ya login - sawa na
/// st.session_state + sidebar settings za Streamlit (device, sms_workers,
/// idadi_ya_miezi).
class AppState extends ChangeNotifier {
  AppUser user;
  final DataRepository repo;
  final String resendApiKey;
  final String resendFromEmail;

  List<PushbulletDevice> devices = [];
  String selectedDeviceIden = '';
  int smsWorkers = 25;
  int idadiYaMiezi = 8;
  bool loadingDevices = false;

  AppState({
    required this.user,
    required this.repo,
    required this.resendApiKey,
    required this.resendFromEmail,
  });

  Future<void> loadDevices() async {
    loadingDevices = true;
    notifyListeners();
    devices = await PushbulletService.getDevices(user.pushbulletToken);
    final smsCapable = devices.where((d) => d.hasSms).toList();
    if (smsCapable.isNotEmpty &&
        !smsCapable.any((d) => d.iden == selectedDeviceIden)) {
      selectedDeviceIden = smsCapable.first.iden;
    }
    loadingDevices = false;
    notifyListeners();
  }

  void setSelectedDevice(String iden) {
    selectedDeviceIden = iden;
    notifyListeners();
  }

  void setSmsWorkers(int v) {
    smsWorkers = v;
    notifyListeners();
  }

  void setIdadiYaMiezi(int v) {
    idadiYaMiezi = v;
    notifyListeners();
  }

  void updateUser(AppUser newUser) {
    user = newUser;
    notifyListeners();
  }

  List<PushbulletDevice> get smsCapableDevices =>
      devices.where((d) => d.hasSms).toList();
}
