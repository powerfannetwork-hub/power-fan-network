    final referralRows = referrals is List
        ? referrals
            .whereType<Map>()
            .map(
              (row) => Map<String, dynamic>.from(row),
            )
            .toList()
        : <Map<String, dynamic>>[];

    final rewardRows = rewards is List
        ? rewards
            .whereType<Map>()
            .map(
              (row) => Map<String, dynamic>.from(row),
            )
            .toList()
        : <Map<String, dynamic>>[];
