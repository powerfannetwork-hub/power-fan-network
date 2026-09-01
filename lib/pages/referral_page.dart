import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ReferralPage extends StatefulWidget { const ReferralPage({super.key}); @override State<ReferralPage> createState() => _ReferralPageState(); }
class _ReferralPageState extends State<ReferralPage> {
  String code = ""; int active = 0; double earnings = 0; bool loading = true;

  @override void initState() { super.initState(); _load(); }

  void _load() async {
    try {
      final data = await ApiService.getReferrals();
      if(!mounted) return; // AN KARA WANNAN
      setState(() { code = data['referralCode']; active = data['activeReferrals']; earnings = data['earnings']; loading = false; });
    } catch(e) { if(mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Referral")), body: loading? Center(child: CircularProgressIndicator()) : Padding(
      padding: EdgeInsets.all(20), child: Column(children: [
        Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [
          Text("Your Referral Code"), SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(code, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(icon: Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: code)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied"))); })
          ])
        ]))),
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [Text("Active"), Text("$active", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))])))),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Column(children: [Text("Earnings"), Text("$earnings FAN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]))))
        ])
      ])
    ));
  }
}
