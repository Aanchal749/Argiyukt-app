import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditHistoryScreen extends StatelessWidget {
  const AuditHistoryScreen({super.key});

  final Color _inspectorOrange = const Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    // ✅ FIXED: Changed .stream() to .select() to fix .eq() error
    final futureQuery = Supabase.instance.client
        .from('inspections')
        .select()
        .eq('inspector_id', user?.id ?? '')
        .eq('status', 'completed')
        .order('inspection_date', ascending: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Audit History"),
        backgroundColor: _inspectorOrange,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureQuery,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: _inspectorOrange));
          }

          final audits = snapshot.data ?? [];

          if (audits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No completed audits yet",
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: audits.length,
            itemBuilder: (context, index) {
              final audit = audits[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white, size: 20),
                  ),
                  title:
                      Text("Audit #${audit['id'].toString().substring(0, 4)}"),
                  subtitle: Text(audit['inspection_date'] ?? 'Date Unknown'),
                  trailing: Text(
                    "COMPLETED",
                    style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
