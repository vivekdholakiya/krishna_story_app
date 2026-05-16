import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/bg_image.png', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: const Color(0xFF0B1A3A).withOpacity(0.5)),
        ),
        child,
      ],
    );
  }
}
