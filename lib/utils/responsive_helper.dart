import 'package:flutter/material.dart';

/// Responsive helper - সব সাইজের মোবাইলে UI ঠিক রাখে
class R {
  final BuildContext context;
  final double _w;
  final double _h;

  R(this.context)
      : _w = MediaQuery.of(context).size.width,
        _h = MediaQuery.of(context).size.height;

  /// Screen width
  double get width => _w;

  /// Screen height
  double get height => _h;

  /// Responsive horizontal padding (screen width এর % হিসেবে)
  double get horizontalPadding => _w * 0.06; // ~6% of screen width

  /// Responsive vertical spacing (screen height এর % হিসেবে)
  double h(double percent) => _h * percent;

  /// Responsive width (screen width এর % হিসেবে)
  double w(double percent) => _w * percent;

  /// Font size — screen width অনুযায়ী scale করে
  double font(double base) {
    if (_w < 360) return base * 0.9;
    if (_w > 430) return base * 1.05;
    return base;
  }

  /// Spacing — screen height অনুযায়ী scale করে
  double space(double base) {
    if (_h < 680) return base * 0.75;
    if (_h > 900) return base * 1.1;
    return base;
  }

  /// Icon size — screen width অনুযায়ী scale করে
  double icon(double base) {
    if (_w < 360) return base * 0.85;
    if (_w > 430) return base * 1.1;
    return base;
  }

  /// Banner height (Cashbooks screen)
  double get bannerHeight {
    if (_h < 680) return _h * 0.20;
    if (_h > 900) return _h * 0.22;
    return _h * 0.21;
  }

  /// Donut chart size
  double get donutSize {
    if (_w < 360) return 100.0;
    if (_w > 430) return 130.0;
    return 120.0;
  }

  /// Bar chart height
  double get barChartHeight {
    if (_h < 680) return 130.0;
    if (_h > 900) return 175.0;
    return 160.0;
  }

  /// Top padding for auth screens
  double get authTopPadding {
    if (_h < 680) return _h * 0.04;
    if (_h > 900) return _h * 0.07;
    return _h * 0.055;
  }

  /// Button vertical padding
  double get btnPadding {
    if (_h < 680) return 12.0;
    return 14.0;
  }

  /// Avatar/icon circle size for splash screen
  double get splashCircleSize {
    if (_w < 360) return 110.0;
    if (_w > 430) return 160.0;
    return 140.0;
  }

  /// Splash screen feature icon size
  double get splashIconSize {
    if (_w < 360) return 60.0;
    if (_w > 430) return 90.0;
    return 75.0;
  }

  /// Small screen check
  bool get isSmall => _h < 700;

  /// Large screen check
  bool get isLarge => _h > 880;
}
