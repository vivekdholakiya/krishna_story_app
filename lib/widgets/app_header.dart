import 'package:flutter/material.dart';
import '../services/context_extensions.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppHeader({required this.title, this.trailing, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.responsiveSize(18)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(context.responsiveSize(10)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(context.responsiveSize(14)),
                border: Border.all(color: const Color(0xFFFFD36A).withOpacity(0.4)),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: context.responsiveSize(24)),
            ),
          ),
          SizedBox(width: context.responsiveSize(14)),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: context.responsiveFontSize(24),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
