// Utilidades de layout responsivo para adaptar la interfaz a web y movil.
import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 720;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 900;

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.all(isMobile(context) ? 14 : 24);
  }

  static EdgeInsets headerPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: isMobile(context) ? 16 : 28,
      vertical: isMobile(context) ? 14 : 18,
    );
  }

  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.all(isMobile(context) ? 16 : 28);
  }
}
