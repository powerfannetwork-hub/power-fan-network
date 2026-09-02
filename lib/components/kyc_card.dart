import 'package:flutter/material.dart';

class KycCard extends StatelessWidget {
  final int checkInDays;
  final int activeReferrals;
  final bool faceVerified;
  final bool kyc1Verified;
  final bool kyc2Eligible;
  final VoidCallback? onFaceVerification;

  const KycCard({
    super.key,
    this.checkInDays = 0,
    this.activeReferrals = 0,
    this.faceVerified = false,
    this.kyc1Verified = false,
    this.kyc2Eligible = false,
    this.onFaceVerification,
  });

  static const int kyc1RequiredDays = 14;
  static const int kyc2RequiredDays = 60;
  static const int kyc2RequiredReferrals = 5;

  bool get kyc1Eligible =>
      checkInDays >= kyc1RequiredDays;

  bool get kyc2CheckInEligible =>
      checkInDays >= kyc2RequiredDays;

  bool get kyc2RequirementsMet =>
      kyc2CheckInEligible &&
      activeReferrals >= kyc2RequiredReferrals;

  int get kyc1DaysRemaining {
    final remaining =
        kyc1RequiredDays - checkInDays;
    return remaining > 0 ? remaining : 0;
  }

  int get kyc2DaysRemaining {
    final remaining =
        kyc2RequiredDays - checkInDays;
    return remaining > 0 ? remaining : 0;
  }

  int get referralsRemaining {
    final remaining =
        kyc2RequiredReferrals - activeReferrals;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 16),

            _buildKyc1(),

            const SizedBox(height: 12),

            _buildDivider(),

            const SizedBox(height: 12),

            _buildKyc2(),

            const SizedBox(height: 12),

            _buildDivider(),

            const SizedBox(height: 12),

            _buildMigration(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3B159B)
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.verified_user,
            color: Color(0xFF3B159B),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Verification',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Complete the requirements to progress',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKyc1() {
    if (kyc1Verified) {
      return _buildCompletedSection(
        title: 'KYC 1',
        subtitle: 'Face Verification completed',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge('1'),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'KYC 1',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(
              kyc1Eligible
                  ? 'READY'
                  : 'IN PROGRESS',
              kyc1Eligible
                  ? const Color(0xFF159B61)
                  : Colors.orange,
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildRequirementRow(
          icon: Icons.calendar_month,
          title: 'Daily check-in',
          value:
              '$checkInDays / $kyc1RequiredDays days',
          completed: kyc1Eligible,
        ),

        const SizedBox(height: 8),

        Text(
          kyc1Eligible
              ? 'You are eligible for Face Verification.'
              : '$kyc1DaysRemaining more consecutive day${kyc1DaysRemaining == 1 ? '' : 's'} required.',
          style: TextStyle(
            fontSize: 12,
            color: kyc1Eligible
                ? const Color(0xFF159B61)
                : Colors.grey.shade600,
          ),
        ),

        if (kyc1Eligible) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: faceVerified
                  ? null
                  : onFaceVerification,
              icon: Icon(
                faceVerified
                    ? Icons.check
                    : Icons.face,
                size: 19,
              ),
              label: Text(
                faceVerified
                    ? 'FACE VERIFIED'
                    : 'FACE VERIFICATION',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF3B159B),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF159B61),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKyc2() {
    final requirementsMet =
        kyc2Eligible || kyc2RequirementsMet;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildNumberBadge('2'),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'KYC 2',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(
              requirementsMet
                  ? 'ELIGIBLE'
                  : 'IN PROGRESS',
              requirementsMet
                  ? const Color(0xFF159B61)
                  : Colors.orange,
            ),
          ],
        ),

        const SizedBox(height: 12),

        _buildRequirementRow(
          icon: Icons.calendar_month,
          title: 'Daily check-in',
          value:
              '$checkInDays / $kyc2RequiredDays days',
          completed: kyc2CheckInEligible,
        ),

        const SizedBox(height: 8),

        _buildRequirementRow(
          icon: Icons.people,
          title: 'Active referrals',
          value:
              '$activeReferrals / $kyc2RequiredReferrals',
          completed:
              activeReferrals >=
                  kyc2RequiredReferrals,
        ),

        const SizedBox(height: 10),

        if (!requirementsMet)
          Text(
            _kyc2ProgressText(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF159B61)
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Color(0xFF159B61),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KYC 2 requirements completed.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF159B61),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _kyc2ProgressText() {
    final parts = <String>[];

    if (!kyc2CheckInEligible) {
      parts.add(
        '$kyc2DaysRemaining more consecutive check-in days',
      );
    }

    if (activeReferrals <
        kyc2RequiredReferrals) {
      parts.add(
        '$referralsRemaining more active referral${referralsRemaining == 1 ? '' : 's'}',
      );
    }

    if (parts.isEmpty) {
      return 'Keep completing your daily requirements.';
    }

    return '${parts.join(' and ')} required.';
  }

  Widget _buildMigration() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3B159B)
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: Color(0xFF3B159B),
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Migration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'FAN → AFAM migration',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Coming Soon • 2027 Q1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B159B),
                  ),
                ),
              ],
            ),
          ),

          _buildStatusBadge(
            'COMING SOON',
            const Color(0xFF3B159B),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF159B61)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF159B61),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF159B61),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({
    required IconData icon,
    required String title,
    required String value,
    required bool completed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: completed
                ? const Color(0xFF159B61)
                : const Color(0xFF3B159B),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: completed
                  ? const Color(0xFF159B61)
                  : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            completed
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 18,
            color: completed
                ? const Color(0xFF159B61)
                : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberBadge(String number) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3B159B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
    );
  }
}
