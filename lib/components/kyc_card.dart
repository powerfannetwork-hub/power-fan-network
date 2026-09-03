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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
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
            _buildComingSoon(),
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
            color: const Color(
              0xFF3B159B,
            ).withOpacity(0.10),
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
                'KYC Verification',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Verification will be available soon',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
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
    );
  }

  Widget _buildComingSoon() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(
          0xFF3B159B,
        ).withOpacity(0.06),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: const Color(
            0xFF3B159B,
          ).withOpacity(0.12),
        ),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.face_retouching_natural,
                color: Color(0xFF3B159B),
                size: 28,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Biometric Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'KYC and biometric verification are currently coming soon.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You will be notified when verification becomes available.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF3B159B),
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}
