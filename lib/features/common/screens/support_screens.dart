import 'package:flutter/material.dart';

// --- SCREEN 1: CONTACT SUPPORT ---
class ContactSupportScreen extends StatelessWidget {
  final Color themeColor;
  const ContactSupportScreen({super.key, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Contact Support"),
          backgroundColor: themeColor,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _contactTile(Icons.phone, "Call Us", "+91 7304259064"),
            _contactTile(Icons.email, "Email Us",
                "aanchalsingh0441@gmail.com"), // Fixed email typo
            _contactTile(Icons.location_on, "Visit Us",
                "AgriYukt HQ, D.Y Patil-RAIT, Navi Mumbai, MH"),

            const SizedBox(height: 20),
            // Link to Report Issue Screen
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ReportIssueScreen(themeColor: themeColor)));
                },
                icon: Icon(Icons.bug_report, color: themeColor),
                label: Text("Report an Issue",
                    style: TextStyle(color: themeColor)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: themeColor)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _contactTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: themeColor.withOpacity(0.1),
            child: Icon(icon, color: themeColor)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        onTap: () {
          // Future: Launch URL (UrlLauncher)
        },
      ),
    );
  }
}

// --- SCREEN 2: REPORT ISSUE ---
class ReportIssueScreen extends StatefulWidget {
  final Color themeColor;
  const ReportIssueScreen({super.key, required this.themeColor});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Report an Issue"),
          backgroundColor: widget.themeColor,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Describe the issue you are facing:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Type here...",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    foregroundColor: Colors.white),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit Report"),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate API
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Report Submitted! Support will contact you shortly."),
          backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }
}
