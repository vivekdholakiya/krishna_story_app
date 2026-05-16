import 'package:flutter/material.dart';

extension UsefulExtensions on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isIPad => MediaQuery.of(this).size.width > 700;
  double get topPadding =>
      MediaQuery.paddingOf(this).top > 0 ? MediaQuery.paddingOf(this).top : 15;
  double get topPaddingRaw => MediaQuery.paddingOf(this).top;
  double get bottomPaddingRaw => MediaQuery.paddingOf(this).bottom;
  double get bottomPadding =>
      MediaQuery.paddingOf(this).bottom > 0 ? MediaQuery.paddingOf(this).bottom : 18;
}

extension ResponsiveSizeExtensions on BuildContext {
  double responsiveSize(double size, {double? min, double? max}) {
    final scale = MediaQuery.of(this).size.width / 430.0;
    final val = size * scale;
    return val.clamp(min ?? size - 15, max ?? size + 8);
  }

  double responsiveFontSize(double size, {double? min, double? max}) {
    final scale = MediaQuery.of(this).size.width / 430.0;
    final val = size * scale;
    return val.clamp(min ?? size, max ?? size + 4);
  }
}
