// ============================================================
// POWER FAN NETWORK — REFERRAL SERVICE
// FILE: src/services/referral_service.js
// ============================================================

const NEW_USER_REWARD = 20;
const INVITER_REWARD = 5;
const ACTIVE_REFERRAL_BONUS = 0.02;

function safeNumber(value, fallback = 0) {
  const number = Number(value);

  return Number.isFinite(number)
    ? number
    : fallback;
}

function cleanReferralCode(value) {
  return String(value || "")
    .trim()
    .toUpperCase();
}

function calculateMiningRate(user) {
  const referrals = Math.max(
    0,
    Math.floor(
      safeNumber(user?.activeReferralCount),
    ),
  );

  const adBoost = Math.max(
    0,
    safeNumber(user?.dailyAdBoost),
  );

  return Number(
    (
      0.2 +
      referrals * ACTIVE_REFERRAL_BONUS +
      adBoost
    ).toFixed(8),
  );
}

function validateReferralCode(code) {
  const referralCode =
    cleanReferralCode(code);

  if (!referralCode) {
    return {
      valid: false,
      error: "referral_code_required",
    };
  }

  if (
    referralCode.length < 4 ||
    referralCode.length > 32
  ) {
    return {
      valid: false,
      error: "invalid_referral_code",
    };
  }

  return {
    valid: true,
    referralCode,
  };
}

function canApplyReferral(user) {
  if (!user) {
    return {
      allowed: false,
      error: "user_not_found",
    };
  }

  if (user.referrerUid) {
    return {
      allowed: false,
      error: "referral_already_used",
    };
  }

  return {
    allowed: true,
  };
}

function createReferralRecord(
  inviterUid,
  referredUid,
  timestamp = Date.now(),
) {
  return {
    uid: referredUid,
    inviterUid,
    active: true,
    createdAt: timestamp,
  };
}

function buildReferralUpdates({
  user,
  inviter,
  inviterUid,
  referredUid,
  timestamp = Date.now(),
}) {
  const newUserBalance =
    safeNumber(user.fanBalance) +
    NEW_USER_REWARD;

  const inviterBalance =
    safeNumber(inviter.fanBalance) +
    INVITER_REWARD;

  const newActiveReferralCount =
    safeNumber(
      inviter.activeReferralCount,
    ) + 1;

  const updatedInviter = {
    ...inviter,
    activeReferralCount:
      newActiveReferralCount,
  };

  const inviterMiningRate =
    calculateMiningRate(
      updatedInviter,
    );

  return {
    [`users/${referredUid}/referrerUid`]:
      inviterUid,

    [`users/${referredUid}/fanBalance`]:
      newUserBalance,

    [`users/${referredUid}/updatedAt`]:
      timestamp,

    [`users/${inviterUid}/fanBalance`]:
      inviterBalance,

    [`users/${inviterUid}/activeReferralCount`]:
      newActiveReferralCount,

    [`users/${inviterUid}/miningRate`]:
      inviterMiningRate,

    [`users/${inviterUid}/updatedAt`]:
      timestamp,

    [`referrals/${inviterUid}/${referredUid}`]:
      createReferralRecord(
        inviterUid,
        referredUid,
        timestamp,
      ),
  };
}

function getReferralRewardInfo() {
  return {
    newUserReward: NEW_USER_REWARD,
    inviterReward: INVITER_REWARD,
    miningRatePerActiveReferral:
      ACTIVE_REFERRAL_BONUS,
  };
}

function calculateReferralMiningBonus(
  activeReferralCount,
) {
  const count = Math.max(
    0,
    Math.floor(
      safeNumber(activeReferralCount),
    ),
  );

  return Number(
    (
      count *
      ACTIVE_REFERRAL_BONUS
    ).toFixed(8),
  );
}

function calculateTotalMiningRate({
  activeReferralCount = 0,
  dailyAdBoost = 0,
}) {
  return Number(
    (
      0.2 +
      calculateReferralMiningBonus(
        activeReferralCount,
      ) +
      Math.max(
        0,
        safeNumber(dailyAdBoost),
      )
    ).toFixed(8),
  );
}

function isReferralActive(referral) {
  return referral?.active === true;
}

function countActiveReferrals(referrals) {
  if (!Array.isArray(referrals)) {
    return 0;
  }

  return referrals.filter(
    isReferralActive,
  ).length;
}

module.exports = {
  NEW_USER_REWARD,
  INVITER_REWARD,
  ACTIVE_REFERRAL_BONUS,

  cleanReferralCode,
  validateReferralCode,
  canApplyReferral,

  createReferralRecord,
  buildReferralUpdates,

  getReferralRewardInfo,

  calculateReferralMiningBonus,
  calculateTotalMiningRate,

  isReferralActive,
  countActiveReferrals,
};
