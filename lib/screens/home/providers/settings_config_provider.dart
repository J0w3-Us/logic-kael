import 'package:flutter/material.dart';

class SettingsConfigProvider extends ChangeNotifier {
  double _volume = 0.5; // Valor inicial del volumen (0.0 a 1.0)

  double get volume => _volume;

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    notifyListeners();
  }
}
