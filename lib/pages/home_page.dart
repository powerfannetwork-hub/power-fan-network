import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../globals/app_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: app.refresh,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text("POWER FAN NETWORK", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF241064))),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF3B159B), Color(0xFF241064)]),
                borderRadius: BorderRadius.circular(24)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("FAN Balance", style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 10),
                  Text("${app.fanBalance.toStringAsFixed(4)} FAN", style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.bold)),
                ]
              )
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(app.miningActive? "MINING ACTIVE" : "MINING STOPPED", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B159B), foregroundColor: Colors.white), // AN SAWA CHILD NA KARSHE
                        onPressed: app.loading? null : () => app.miningActive? app.claimMining() : app.startMining(),
                        child: Text(app.miningActive? "CLAIM MINING" : "START MINING"),
                      )
                    )
                  ]
                )
              )
            )
          ]
        )
      )
    );
  }
}
