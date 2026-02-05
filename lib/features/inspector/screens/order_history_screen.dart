import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        // Fetch orders where the user is EITHER the farmer OR the buyer
        final response = await _client
            .from('orders')
            .select()
            .or('farmer_id.eq.${user.id},buyer_id.eq.${user.id}')
            .order('order_date', ascending: false);

        if (mounted) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error fetching history: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _orders.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _HistoryCard(order: order);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No order history found",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _HistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'Unknown';
    final isCompleted = status == 'Completed';
    final isCancelled = status == 'Cancelled' || status == 'Rejected';

    // Date formatting
    final dateStr = order['order_date'];
    final date = dateStr != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(dateStr).toLocal())
        : "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Order ID & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order #${order['id'].toString().substring(0, 6).toUpperCase()}",
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              _StatusBadge(
                  status: status,
                  isCompleted: isCompleted,
                  isCancelled: isCancelled),
            ],
          ),
          const SizedBox(height: 10),

          // Crop Name
          Text(
            order['crop_name'] ?? 'Unknown Crop',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),

          const SizedBox(height: 6),

          // Price & Quantity
          Row(
            children: [
              Icon(Icons.currency_rupee, size: 16, color: Colors.green[800]),
              Text(
                "${order['price_offered']}",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[800]),
              ),
              const SizedBox(width: 10),
              Text(
                "•  ${order['quantity_kg']} Kg",
                style: TextStyle(
                    color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Footer: Date
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                date,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isCompleted;
  final bool isCancelled;

  const _StatusBadge({
    required this.status,
    required this.isCompleted,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    if (isCompleted) {
      bg = Colors.green[50]!;
      text = Colors.green[800]!;
    } else if (isCancelled) {
      bg = Colors.red[50]!;
      text = Colors.red[800]!;
    } else {
      bg = Colors.orange[50]!;
      text = Colors.orange[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
