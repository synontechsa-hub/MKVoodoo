import 'package:flutter/foundation.dart';
import 'clipper_controller.dart';

class NavigationController extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void navigateTo(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  Future<void> navigateToClipper(String sourcePath, ClipperController clipper) async {
    _selectedIndex = 3; // Index of Clipper tab
    notifyListeners();
    await clipper.openSource(sourcePath);
  }
}
