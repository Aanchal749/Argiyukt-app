import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactSupportScreen extends StatelessWidget {
  final Color themeColor;

  const ContactSupportScreen({super.key, required this.themeColor});

  // 📧 Production Email Handler
  Future<void> _contactViaEmail(String subject, BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'agriyuktbusiness@gmail.com',
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw "Could not launch email";
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "No email app found. Please email agriyuktbusiness@gmail.com directly.",
                style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: Colors.orange.shade800));
      }
    }
  }

  // 📞 Production Call Handler
  Future<void> _contactViaCall(BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+917304259064');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw "Could not launch dialer";
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Cannot open phone dialer.", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Support Center",
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("How can we help?",
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text("Our team usually responds within 24 hours.",
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            _supportCard(
              icon: Icons.email_outlined,
              title: "Email Support",
              subtitle: "Send us your queries directly",
              onTap: () => _contactViaEmail("General Support Request", context),
            ),
            _supportCard(
              icon: Icons.phone_in_talk_outlined,
              title: "Call Us",
              subtitle: "Available 10 AM - 6 PM IST",
              onTap: () => _contactViaCall(context),
            ),
            _supportCard(
              icon: Icons.bug_report_outlined,
              title: "Report a Bug",
              subtitle: "Report technical glitches via email",
              onTap: () =>
                  _contactViaEmail("Bug Report: Technical Issue", context),
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.location_city,
                      color: Colors.grey.shade300, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    "AgriYukt HQ\nD.Y Patil-RAIT, Navi Mumbai, MH",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: themeColor, size: 24),
        ),
        title: Text(title,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle,
            style:
                GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
        trailing: Icon(Icons.arrow_forward_ios,
            size: 14, color: Colors.grey.shade300),
        onTap: onTap,
      ),
    );
  }
}
