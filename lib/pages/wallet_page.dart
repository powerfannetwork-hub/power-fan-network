import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WalletTab extends StatelessWidget {
  const WalletTab({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF3B159B).withValues(alpha: 0.10), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 55, color: Color(0xFF3B159B)),
              ),
              const SizedBox(height: 20),
              const Text('Wallet', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('COMING SOON', style: TextStyle(color: Color(0xFF3B159B), fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}
