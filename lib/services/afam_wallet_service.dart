import 'package:supabase_flutter/supabase_flutter.dart';

class AfamWalletService {
  AfamWalletService._();

  static final AfamWalletService instance = AfamWalletService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Karanta FAN da AFAM balances na user.
  Future<Map<String, dynamic>> getWalletSnapshot() async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Please sign in to access your wallet.');
    }

    final response = await _supabase
        .from('profiles')
        .select(
          'username, fan_balance, afam_balance, migration_completed',
        )
        .eq('id', userId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  // Duba ko user ya cancanci Migration.
  Future<Map<String, dynamic>> migrateFanToAfam() async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Please sign in first.');
    }

    final response = await _supabase.rpc(
      'migrate_fan_to_afam_after_manual_kyc',
    );

    return _parseResponse(response);
  }

  // Aika AFAM zuwa username na wani user.
  Future<Map<String, dynamic>> sendAfam({
    required String username,
    required double amount,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Please sign in first.');
    }

    final recipientUsername = username.trim();

    if (recipientUsername.isEmpty) {
      throw Exception('Please enter the recipient username.');
    }

    if (amount <= 0 || !amount.isFinite) {
      throw Exception('Enter a valid AFAM amount.');
    }

    final response = await _supabase.rpc(
      'send_afam_by_username',
      params: {
        'p_username': recipientUsername,
        'p_amount': amount,
      },
    );

    final result = _parseResponse(response);

    if (result['success'] != true) {
      throw Exception(
        result['message']?.toString() ?? 'AFAM transfer failed.',
      );
    }

    return result;
  }

  // Karanta tarihin AFAM transactions.
  Future<List<Map<String, dynamic>>> getTransactions({
    int limit = 50,
  }) async {
    final userId = currentUserId;

    if (userId == null) {
      throw Exception('Please sign in first.');
    }

    final response = await _supabase.rpc(
      'get_afam_wallet_transactions',
      params: {
        'p_limit': limit.clamp(1, 100),
      },
    );

    final result = _parseResponse(response);

    if (result['success'] != true) {
      throw Exception(
        result['message']?.toString() ??
            'Unable to load AFAM transactions.',
      );
    }

    final transactions = result['transactions'];

    if (transactions is! List) {
      return <Map<String, dynamic>>[];
    }

    return transactions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Maida sakamakon Supabase zuwa Map.
  Map<String, dynamic> _parseResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Unexpected response received from the server.');
  }
}
