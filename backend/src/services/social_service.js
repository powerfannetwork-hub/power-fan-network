// ============================================================
// POWER FAN NETWORK — SOCIAL SERVICE
// FILE: src/services/social_service.js
// ============================================================

const DAILY_SOCIAL_REWARD = 10;
const COIN = "FAN";

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function getClaimPath(uid, date = todayKey()) {
  return `socialClaims/${uid}/${date}`;
}

function createClaimRecord(
  uid,
  date = todayKey(),
) {
  return {
    uid,
    date,
    reward: DAILY_SOCIAL_REWARD,
    coin: COIN,
    claimedAt: Date.now(),
  };
}

function getDailyReward() {
  return {
    reward: DAILY_SOCIAL_REWARD,
    coin: COIN,
  };
}

function hasClaimedToday(claim) {
  return Boolean(claim);
}

function calculateRewardBalance(
  currentBalance,
) {
  const balance = Number(currentBalance);

  const safeBalance =
    Number.isFinite(balance)
      ? balance
      : 0;

  return Number(
    (
      safeBalance +
      DAILY_SOCIAL_REWARD
    ).toFixed(8),
  );
}

function validateUser(uid) {
  return (
    typeof uid === "string" &&
    uid.trim().length > 0
  );
}

function validateClaim({
  uid,
  existingClaim,
}) {
  if (!validateUser(uid)) {
    return {
      valid: false,
      error: "user_required",
    };
  }

  if (hasClaimedToday(existingClaim)) {
    return {
      valid: false,
      error:
        "social_reward_already_claimed",
    };
  }

  return {
    valid: true,
  };
}

module.exports = {
  DAILY_SOCIAL_REWARD,
  COIN,

  todayKey,
  getClaimPath,
  createClaimRecord,
  getDailyReward,
  hasClaimedToday,
  calculateRewardBalance,
  validateUser,
  validateClaim,
};
