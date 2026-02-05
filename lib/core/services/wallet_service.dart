import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  final _supabase = Supabase.instance.client;

  // 1. Fetch Balance
  Future<double> getBalance() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0.0;

    final data = await _supabase
        .from('profiles')
        .select('wallet_balance')
        .eq('id', user.id)
        .single();

    return (data['wallet_balance'] ?? 0).toDouble();
  }

  // 2. Fetch Transactions
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final data = await _supabase
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false); // Latest first

    return List<Map<String, dynamic>>.from(data);
  }

  // 3. Add Money (Simulated Payment)
  Future<void> addMoney(double amount) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // A. Update Balance
    await _supabase.rpc('increment_balance', params: {
      'user_id': user.id,
      'amount': amount,
    });

    // B. Save Transaction Record
    await _supabase.from('transactions').insert({
      'user_id': user.id,
      'type': 'Credit', // Money coming in
      'amount': amount,
      'description': 'Added to Wallet',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // 4. Withdraw Money
  Future<bool> withdrawMoney(double amount) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // Check balance first
    final currentBalance = await getBalance();
    if (currentBalance < amount) return false; // Not enough money

    // A. Deduct Balance
    await _supabase.rpc('decrement_balance', params: {
      'user_id': user.id,
      'amount': amount,
    });

    // B. Save Transaction Record
    await _supabase.from('transactions').insert({
      'user_id': user.id,
      'type': 'Debit', // Money going out
      'amount': amount,
      'description': 'Withdrawal to Bank',
      'created_at': DateTime.now().toIso8601String(),
    });

    return true;
  }
}
