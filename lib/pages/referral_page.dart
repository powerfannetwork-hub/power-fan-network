import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ReferralPage extends StatefulWidget { const ReferralPage({super.key}); @override State<ReferralPage> createState() => _ReferralPageState(); }

class _ReferralPageState extends State<ReferralPage> {
  Map? _data; bool _loading = true; final _controller = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final res = await ApiService.getReferrals(); setState((){_data = res; _loading = false;}); } catch(e){ setState((){_loading = false;}); } }

  Future<void> _apply() async {
    try {
      await ApiService.applyReferral(_controller.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral applied! +20 FAN"), backgroundColor: Colors.green));
      _controller.clear(); _load();
    } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)); }
  }

  @override Widget build(BuildContext context) {
    if(_loading) return const Center(child: CircularProgressIndicator());
    final code = _data?['referralCode'] ?? '';
    return SafeArea(child: ListView(padding: EdgeInsets.all(16), children: [
      Text("Referral", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF241064))),
      SizedBox(height: 20),
      Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [
        Text("Your Referral Code"), SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(code, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          IconButton(icon: Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: code)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied"))); })
        ])
      ])),
      SizedBox(height: 20),
      TextField(controller: _controller, decoration: InputDecoration(labelText: "Enter Referral Code", suffixIcon: ElevatedButton(onPressed: _apply, child: Text("Apply")))),
      SizedBox(height: 20),
      Text("Active Referrals: ${_data?['activeReferrals'] ?? 0}", style: TextStyle(fontWeight: FontWeight.bold))
    ]));
  }
}
