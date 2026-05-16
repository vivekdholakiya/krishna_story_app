import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/util.dart';
import '../services/app_text_data.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kStatusBarStyle,
      child: Scaffold(
        body: AppBackground(
          child: Column(
            children: [
              SizedBox(height: context.responsiveSize(40)),
              AppHeader(title: TermsOfUse[selectedLanguage]),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      context.responsiveSize(20),
                      context.responsiveSize(10),
                      context.responsiveSize(20),
                      context.responsiveSize(40)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Updated: January 2026',
                          style: TextStyle(
                              fontSize: context.responsiveFontSize(15),
                              color: const Color(0xFFFFD36A).withOpacity(0.9),
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: context.responsiveSize(20)),
                      _termsCard(
                        context: context,
                        icon: Icons.verified_user,
                        title: 'Acceptance of Terms',
                        content:
                            '• By using "Krishna – The Eternal Story" you agree to these terms.\n'
                            '• If you do not agree, please do not use the app.',
                      ),
                      SizedBox(height: context.responsiveSize(20)),
                      _termsCard(
                        context: context,
                        icon: Icons.auto_stories,
                        title: 'Purpose & Content Usage',
                        content:
                            '• Free for personal, non-commercial devotional use only\n'
                            '• Stories are for inspiration and reflection\n'
                            '• Content is AI-assisted and based on traditional sources\n'
                            '• May contain simplifications and variations',
                      ),
                      SizedBox(height: context.responsiveSize(20)),
                      _termsCard(
                        context: context,
                        icon: Icons.favorite,
                        title: 'Respect & Devotion',
                        content:
                            'This app is created with deep respect for Lord Krishna and all spiritual traditions.\n\n'
                            'It has no intention to offend, misrepresent or harm any religion, belief or community.',
                        isImportant: true,
                      ),
                      SizedBox(height: context.responsiveSize(20)),
                      _termsCard(
                        context: context,
                        icon: Icons.warning_amber,
                        title: 'Disclaimer & Liability',
                        content:
                            '• App is provided "as is" without warranties\n'
                            '• We are not responsible for any direct or indirect damages\n'
                            '• Use at your own discretion\n'
                            '• For authentic knowledge, refer to scriptures and learned guides',
                      ),
                      SizedBox(height: context.responsiveSize(20)),
                      _termsCard(
                        context: context,
                        icon: Icons.update,
                        title: 'Changes to Terms',
                        content:
                            'We may update these terms from time to time.\n\n'
                            'Continued use of the app means acceptance of updated terms.',
                      ),
                      SizedBox(height: context.responsiveSize(40)),
                      Center(
                        child: Text(
                          'Hari Om 🙏\nThank you for your trust',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: context.responsiveFontSize(18),
                              color: const Color(0xFFFFD36A),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
    bool isImportant = false,
  }) {
    return Container(
      padding: EdgeInsets.all(context.responsiveSize(16)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(context.responsiveSize(20)),
        border: Border.all(
            color: const Color(0xFFFFD36A).withOpacity(0.35), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.responsiveSize(12)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(context.responsiveSize(14)),
                ),
                child: Icon(icon,
                    color: Colors.white, size: context.responsiveSize(26)),
              ),
              SizedBox(width: context.responsiveSize(14)),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: context.responsiveFontSize(19),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(content,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: context.responsiveFontSize(15),
                  height: 1.55,
                  fontWeight: isImportant ? FontWeight.w500 : FontWeight.normal)),
        ],
      ),
    );
  }
}
