import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class InspectorNotificationScreen extends StatefulWidget {
  const InspectorNotificationScreen({super.key});

  @override
  State<InspectorNotificationScreen> createState() =>
      _InspectorNotificationScreenState();
}

class _InspectorNotificationScreenState
    extends State<InspectorNotificationScreen> {
  final _supabase = Supabase.instance.client;
  final Color _inspectorColor = const Color(0xFF512DA8);

  // ✅ FAKE DATA (Updated: Only kept the 2 Order Requests)
  final List<Map<String, dynamic>> _fakeNotifications = [
    {
      'id': '101',
      'title': 'New Order Request',
      'body':
          'Himanshu chauhan has ordered 500.0 Kg of Onion. Action required.',
      'created_at':
          DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      'is_read': false,
    },
    {
      'id': '102',
      'title': 'New Order Request',
      'body': 'Janvi kadam has ordered 50.0 Kg of Brinjal. Action required.',
      'created_at':
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'is_read': false,
    },
  ];

  // ✅ LOGIC: Update Local Fake Data
  void _markAsRead(String id) {
    setState(() {
      final index =
          _fakeNotifications.indexWhere((element) => element['id'] == id);
      if (index != -1) {
        _fakeNotifications[index]['is_read'] = true;
      }
    });
  }

  // ✅ LOGIC: Mark ALL Local Data as Read
  void _markAllAsRead() {
    setState(() {
      for (var note in _fakeNotifications) {
        note['is_read'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All notifications marked as read")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Notifications",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: _inspectorColor),
            tooltip: "Mark all as read",
            onPressed: _markAllAsRead,
          )
        ],
      ),
      // ✅ Using ListView directly with fake data
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _fakeNotifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final note = _fakeNotifications[index];
          final isRead = note['is_read'] as bool;
          final title = note['title'] as String;
          final body = note['body'] as String;
          final date = DateTime.parse(note['created_at']).toLocal();
          final timeStr = DateFormat('dd MMM, hh:mm a').format(date);

          return GestureDetector(
            onTap: () => _markAsRead(note['id']),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead ? Colors.white : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: isRead
                    ? Border.all(color: Colors.grey.shade200)
                    : Border.all(color: _inspectorColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Based on Read Status
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.grey.shade100
                          : _inspectorColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: isRead ? Colors.grey : _inspectorColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color:
                                      isRead ? Colors.black87 : _inspectorColor,
                                ),
                              ),
                            ),
                            Text(
                              timeStr,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
