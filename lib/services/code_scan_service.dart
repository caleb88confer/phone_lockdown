import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodeScanService extends ChangeNotifier {
  static const _savedCodeKey = 'savedCodeValue';

  String? _registeredCode;

  String? get registeredCode => _registeredCode;
  bool get hasRegisteredCode => _registeredCode != null;

  CodeScanService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _registeredCode = prefs.getString(_savedCodeKey);
    notifyListeners();
  }

  Future<void> registerCode(String codeValue) async {
    _registeredCode = codeValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedCodeKey, codeValue);
    notifyListeners();
  }

  Future<void> clearRegisteredCode() async {
    _registeredCode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedCodeKey);
    notifyListeners();
  }

  bool isValidCode(String scannedValue) {
    return _registeredCode != null && scannedValue == _registeredCode;
  }
}
