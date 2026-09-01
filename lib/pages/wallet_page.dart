import 'package:flutter/material.dart';
import '../globals/app_state.dart';

class WalletPage extends StatelessWidget {
  final AppState appState;
  const WalletPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: EdgeInsets.all(16), children: [
      Text("Wallet", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF241064))),
      SizedBox(height: 20),
      Container(padding: EdgeInsets.all(22), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3B159B), Color(0xFF241064)]), borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("FAN Balance", style: TextStyle(color: Colors.white70)), SizedBox(height: 10),
          Text("${appState.fanBalance.toStringAsFixed(4)} FAN", style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.bold)),
        ])),
      SizedBox(height: 20),
      ElevatedButton(onPressed: (){}, child: Text("WITHDRAW - COMING SOON"), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, minimumSize: Size(double.infinity, 50)))
    ]));
  }
}
