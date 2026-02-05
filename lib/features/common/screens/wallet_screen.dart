import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agriyukt_app/features/farmer/screens/bank_details_screen.dart';

class WalletScreen extends StatefulWidget {
  // ✅ ADDED: Optional theme color to fix Drawer errors
  final Color? themeColor;

  const WalletScreen({super.key, this.themeColor});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  double _totalEarned = 0.0;
  double _lockedAmount = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _bankDetails;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final walletData = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      final transData = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final bankData = await _supabase
          .from('bank_accounts')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _totalEarned = (walletData?['total_earned'] ?? 0).toDouble();
          _lockedAmount = (walletData?['locked_amount'] ?? 0).toDouble();
          _transactions = List<Map<String, dynamic>>.from(transData ?? []);
          _bankDetails = bankData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use passed theme color or default to Blue
    final primaryColor = widget.themeColor ?? Colors.blue;
    final gradientColors = [primaryColor, primaryColor.withOpacity(0.7)];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Earnings",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchWalletData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. MAIN BALANCE CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Earnings",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text("₹${_totalEarned.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_clock,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Locked (In Escrow)",
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10)),
                                    Text("₹${_lockedAmount.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. BANK ACCOUNT LINK
                    InkWell(
                      onTap: () {
                        Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const BankDetailsScreen()))
                            .then((_) => _fetchWalletData());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.account_balance,
                                    color: Colors.green)),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Payout Account",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      _bankDetails != null
                                          ? "${_bankDetails!['bank_name']} ••••"
                                          : "Link your bank account",
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 3. HISTORY
                    const Text("Transaction History",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_transactions.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                              child: Text("No transactions yet",
                                  style: TextStyle(color: Colors.grey))))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = _transactions[index];
                          final isCredit = t['direction'] == 'credit';
                          return ListTile(
                            leading: Icon(
                                isCredit
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isCredit ? Colors.green : Colors.red),
                            title: Text(t['description'] ?? 'Transaction'),
                            trailing: Text("₹${t['amount']}",
                                style: TextStyle(
                                    color: isCredit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
