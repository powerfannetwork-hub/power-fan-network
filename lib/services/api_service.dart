
static Future<Map<String, dynamic>> applyReferral(String code) async {
  try {
    final res = await _client.rpc('apply_referral', params: {'referral_code': code});
    return res;
  } catch (e) {
    throw Exception('Invalid Referral Code');
  }
}
