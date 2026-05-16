import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishna_stories_app/services/context_extensions.dart';
import 'package:krishna_stories_app/services/util.dart';
import '../services/app_text_data.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: kStatusBarStyle,
      child: Scaffold(
        body: AppBackground(
          child: Column(
            children: [
              SizedBox(height: context.responsiveSize(40)),
              AppHeader(title: PrivacyPolicy[selectedLanguage]),
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
                              fontSize: context.responsiveFontSize(14),
                              color: const Color(0xFFFFD36A),
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: context.responsiveSize(24)),
                      _policyCard(
                        context: context,
                        icon: Icons.security,
                        title: 'We Protect Your Privacy',
                        content:
                            '• No names, emails, phone numbers, device IDs or location data\n'
                            '• No analytics, tracking or third-party SDKs\n'
                            '• No data is ever sent to servers or shared with anyone\n\n'
                            'All your preferences (favorites, settings) are stored only on your device using local storage.\n'
                            'The app works completely offline.',
                      ),
                      SizedBox(height: context.responsiveSize(20)),
                      _policyCard(
                        context: context,
                        icon: Icons.block,
                        title: 'No Data Collection & Sharing',
                        content:
                            'Since we collect nothing, there is nothing to share, sell or misuse.\n\n'
                            '• No advertising networks\n'
                            '• No crash reporting tools\n'
                            '• No unnecessary permissions',
                      ),
                      SizedBox(height: context.responsiveSize(20)),
                      _policyCard(
                        context: context,
                        icon: Icons.info_outline,
                        title: 'Content & AI Disclaimer',
                        content:
                            'Stories and information are created with the help of AI tools and public sources.\n\n'
                            'While we strive to be respectful and accurate, AI-generated content may include simplifications.\n\n'
                            'This app is made with devotion and has no intention to hurt or misrepresent any belief.',
                        isImportant: true,
                      ),
                      SizedBox(height: context.responsiveSize(36)),
                      Center(
                        child: Text(
                          'Jay Shree Krishna 🙏\nThank you for your trust',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: context.responsiveSize(18),
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

  Widget _policyCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
    bool isImportant = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(context.responsiveSize(20)),
        border: Border.all(color: const Color(0xFFFFD36A).withOpacity(0.35)),
      ),
      padding: EdgeInsets.all(context.responsiveSize(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.responsiveSize(10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD36A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.responsiveSize(14)),
                ),
                child: Icon(icon,
                    color: const Color(0xFFFFD36A),
                    size: context.responsiveSize(26)),
              ),
              SizedBox(width: context.responsiveSize(14)),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: context.responsiveFontSize(20),
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(content,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: context.responsiveFontSize(15),
                  height: 1.6,
                  fontWeight: isImportant ? FontWeight.w500 : FontWeight.normal)),
        ],
      ),
    );
  }
}
