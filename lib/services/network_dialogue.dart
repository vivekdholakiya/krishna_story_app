import 'package:flutter/material.dart';
import 'app_text_data.dart';
import 'util.dart';

class NoInternetConnection extends StatefulWidget {
  final VoidCallback onRetry;
  const NoInternetConnection({super.key, required this.onRetry});

  @override
  State<NoInternetConnection> createState() => _NoInternetConnectionState();
}

class _NoInternetConnectionState extends State<NoInternetConnection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween<double>(begin: 40, end: 0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, _slide.value), child: child),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1A3A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFFFD36A).withOpacity(0.45), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5),
                  BoxShadow(
                      color: const Color(0xFFFFD36A).withOpacity(0.08),
                      blurRadius: 30,
                      spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: ClipPath(
                      clipper: _WaveClipper(),
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFD36A).withOpacity(0.25),
                              const Color(0xFF0B1A3A),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFFFD36A).withOpacity(0.5),
                                  width: 1.5),
                              color: Colors.white.withOpacity(0.05),
                            ),
                            child: const Icon(Icons.wifi_off_rounded,
                                color: Color(0xFFFFD36A), size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: Column(
                      children: [
                        Text(oops[selectedLanguage],
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 6),
                        Text(noInternet[selectedLanguage],
                            style: TextStyle(
                                fontSize: 15,
                                color: const Color(0xFFFFD36A).withOpacity(0.9),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Text(noInternetDes[selectedLanguage],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.65),
                                height: 1.6)),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: widget.onRetry,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD36A), Color(0xFFE8B84B)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFFFD36A).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded,
                                    color: Color(0xFF0B1A3A), size: 20),
                                const SizedBox(width: 8),
                                Text(Retry[selectedLanguage],
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0B1A3A),
                                        letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 30)
      ..quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height - 20)
      ..quadraticBezierTo(size.width * 0.75, size.height - 40, size.width, size.height - 10)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
