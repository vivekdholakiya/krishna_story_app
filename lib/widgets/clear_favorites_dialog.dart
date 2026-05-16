import 'package:flutter/material.dart';
import '../services/app_text_data.dart';
import '../services/context_extensions.dart';
import '../services/util.dart';

/// Shows a premium-themed confirmation dialog matching the app's dark/gold theme.
/// Returns `true` if user confirmed, `false` or `null` otherwise.
Future<bool?> showClearFavoritesDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (_, anim, __, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => const _ClearFavoritesDialog(),
  );
}

class _ClearFavoritesDialog extends StatelessWidget {
  const _ClearFavoritesDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: context.responsiveSize(28)),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1A3A),
            borderRadius: BorderRadius.circular(context.responsiveSize(24)),
            border: Border.all(
              color: const Color(0xFFFFD36A).withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 24,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFFFFD36A).withOpacity(0.07),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top wave header ──────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(context.responsiveSize(24))),
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    width: double.infinity,
                    height: context.responsiveSize(120),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFD36A).withOpacity(0.2),
                          const Color(0xFF0B1A3A),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(context.responsiveSize(14)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.6),
                            width: 1.5,
                          ),
                          color: Colors.redAccent.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent.shade100,
                          size: context.responsiveSize(36),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.responsiveSize(24),
                  context.responsiveSize(4),
                  context.responsiveSize(24),
                  context.responsiveSize(24),
                ),
                child: Column(
                  children: [
                    Text(
                      ClearFavorites[selectedLanguage],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.responsiveFontSize(22),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: context.responsiveSize(10)),
                    Text(
                      removeAllStory[selectedLanguage],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: context.responsiveFontSize(14),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: context.responsiveSize(28)),

                    // ── Buttons ──────────────────────────────
                    Row(
                      children: [
                        // Cancel
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: context.responsiveSize(14)),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(
                                    context.responsiveSize(14)),
                                border: Border.all(
                                  color: const Color(0xFFFFD36A).withOpacity(0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                Cancel[selectedLanguage],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: context.responsiveFontSize(16),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: context.responsiveSize(14)),

                        // Clear / Confirm
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: context.responsiveSize(14)),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.redAccent.shade200,
                                    Colors.red.shade700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                    context.responsiveSize(14)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                Clear[selectedLanguage],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: context.responsiveFontSize(16),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
      ..lineTo(0, size.height - 24)
      ..quadraticBezierTo(
          size.width * 0.25, size.height, size.width * 0.5, size.height - 16)
      ..quadraticBezierTo(
          size.width * 0.75, size.height - 32, size.width, size.height - 8)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}