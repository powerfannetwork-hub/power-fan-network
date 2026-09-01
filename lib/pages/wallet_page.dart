import 'package:flutter/material.dart';
import '../globals/app_state.dart';

class WalletPage extends StatelessWidget {
  final AppState appState;
  const WalletPage({super.key, required this.appState});

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wallet")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text("Total Balance"),
                    Text("${appState.fanBalance.toStringAsFixed(4)} FAN", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
                  ]
                )
              )
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B159B)), // AN SAWA CHILD NA KARSHE
                onPressed: (){},
                child: Text("WITHDRAW")
              )
            )
          ]
        )
      )
    );
  }
}
