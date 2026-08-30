// ============================================================
// POWER FAN NETWORK — MINING SERVICE
// FILE: src/services/mining_service.js
// ============================================================

const BASE_MINING_RATE = 0.2;
const AD_BOOST_PER_AD = 0.1;
const MAXIMUM_DAILY_ADS = 7;
const MAXIMUM_AD_BOOST = 0.7;
const ACTIVE_REFERRAL_BONUS = 0.02;
const MINING_SESSION_HOURS = 24;

function now() {
  return Date.now();
}

function safeNumber(value, fallback = 0) {
  const number = Number(value);

  return Number.isFinite(number)
    ? number
    : fallback;
}

function calculateMiningRate(user) {
  const activeReferrals = Math.max(
    0,
    Math.floor(
      safeNumber(user?.activeReferralCount),
    ),
  );

  const dailyAdBoost = Math.min(
    MAXIMUM_AD_BOOST,
    Math.max(
      0,
      safeNumber(user?.dailyAdBoost),
    ),
  );

  return Number(
    (
      BASE_MINING_RATE +
      activeReferrals * ACTIVE_REFERRAL_BONUS +
      dailyAdBoost
    ).toFixed(8),
  );
}

function calculateMiningReward(
  user,
  startedAt,
  endedAt,
) {
  const start = safeNumber(startedAt);
  const end = safeNumber(endedAt);

  if (
    start <= 0 ||
    end <= start
  ) {
    return 0;
  }

  const maximumMilliseconds =
    MINING_SESSION_HOURS *
    60 *
    60 *
    1000;

  const elapsedMilliseconds =
    Math.min(
      maximumMilliseconds,
      end - start,
    );

  const elapsedHours =
    elapsedMilliseconds /
    (60 * 60 * 1000);

  const rate =
    calculateMiningRate(user);

  return Number(
    (
      rate *
      elapsedHours
    ).toFixed(8),
  );
}

function isMiningActive(user) {
  return user?.miningActive === true;
}

function isMiningFinished(user, currentTime = now()) {
  if (!isMiningActive(user)) {
    return false;
  }

  const endsAt =
    safeNumber(user.miningEndsAt);

  return (
    endsAt > 0 &&
    currentTime >= endsAt
  );
}

function getRemainingMilliseconds(
  user,
  currentTime = now(),
) {
  if (!isMiningActive(user)) {
    return 0;
  }

  const endsAt =
    safeNumber(user.miningEndsAt);

  return Math.max(
    0,
    endsAt - currentTime,
  );
}

function startMining(user, currentTime = now()) {
  if (!user) {
    throw new Error("User not found.");
  }

  if (isMiningActive(user)) {
    return {
      success: false,
      error: "mining_already_active",
      miningEndsAt:
        user.miningEndsAt || null,
    };
  }

  const startedAt =
    currentTime;

  const endsAt =
    startedAt +
    MINING_SESSION_HOURS *
      60 *
      60 *
      1000;

  const rate =
    calculateMiningRate(user);

  user.miningActive = true;
  user.miningStartedAt = startedAt;
  user.miningEndsAt = endsAt;
  user.miningRate = rate;
  user.updatedAt = currentTime;

  return {
    success: true,
    user,
    miningRate: rate,
    miningStartedAt: startedAt,
    miningEndsAt: endsAt,
  };
}

function claimMining(user, currentTime = now()) {
  if (!user) {
    throw new Error("User not found.");
  }

  if (!isMiningActive(user)) {
    return {
      success: false,
      error: "nothing_to_claim",
    };
  }

  if (!isMiningFinished(user, currentTime)) {
    return {
      success: false,
      error: "mining_not_finished",
      miningEndsAt:
        user.miningEndsAt || null,
      remainingMilliseconds:
        getRemainingMilliseconds(
          user,
          currentTime,
        ),
    };
  }

  const startedAt =
    safeNumber(user.miningStartedAt);

  const endedAt =
    safeNumber(user.miningEndsAt);

  const rate =
    calculateMiningRate(user);

  const earned =
    calculateMiningReward(
      user,
      startedAt,
      endedAt,
    );

  user.fanBalance =
    safeNumber(user.fanBalance) +
    earned;

  user.miningActive = false;
  user.miningStartedAt = null;
  user.miningEndsAt = null;
  user.miningRate = rate;
  user.updatedAt = currentTime;

  return {
    success: true,
    user,
    earned,
    miningRate: rate,
    fanBalance:
      safeNumber(user.fanBalance),
  };
}

function claimAdBoost(user) {
  if (!user) {
    throw new Error("User not found.");
  }

  const today =
    new Date()
      .toISOString()
      .slice(0, 10);

  if (user.dailyAdDate !== today) {
    user.dailyAdDate = today;
    user.dailyAdCount = 0;
    user.dailyAdBoost = 0;
  }

  const currentCount =
    safeNumber(user.dailyAdCount);

  if (
    currentCount >=
    MAXIMUM_DAILY_ADS
  ) {
    return {
      success: false,
      error: "daily_ad_limit_reached",
      dailyAdCount: currentCount,
      dailyAdBoost:
        safeNumber(user.dailyAdBoost),
      miningRate:
        calculateMiningRate(user),
    };
  }

  const nextCount =
    currentCount + 1;

  const nextBoost =
    Math.min(
      MAXIMUM_AD_BOOST,
      nextCount * AD_BOOST_PER_AD,
    );

  user.dailyAdCount =
    nextCount;

  user.dailyAdBoost =
    Number(nextBoost.toFixed(8));

  user.miningRate =
    calculateMiningRate(user);

  user.updatedAt =
    now();

  return {
    success: true,
    user,
    dailyAdCount:
      user.dailyAdCount,
    dailyAdBoost:
      user.dailyAdBoost,
    miningRate:
      user.miningRate,
  };
}

function getMiningStatus(user, currentTime = now()) {
  if (!user) {
    throw new Error("User not found.");
  }

  const active =
    isMiningActive(user);

  const remainingMilliseconds =
    getRemainingMilliseconds(
      user,
      currentTime,
    );

  return {
    miningActive: active,
    miningRate:
      calculateMiningRate(user),
    miningStartedAt:
      user.miningStartedAt || null,
    miningEndsAt:
      user.miningEndsAt || null,
    remainingMilliseconds,
    fanBalance:
      safeNumber(user.fanBalance),
  };
}

function addActiveReferral(user) {
  if (!user) {
    throw new Error("User not found.");
  }

  user.activeReferralCount =
    Math.max(
      0,
      Math.floor(
        safeNumber(
          user.activeReferralCount,
        ),
      ),
    ) + 1;

  user.miningRate =
    calculateMiningRate(user);

  user.updatedAt =
    now();

  return {
    success: true,
    activeReferralCount:
      user.activeReferralCount,
    miningRate:
      user.miningRate,
  };
}

module.exports = {
  BASE_MINING_RATE,
  AD_BOOST_PER_AD,
  MAXIMUM_DAILY_ADS,
  MAXIMUM_AD_BOOST,
  ACTIVE_REFERRAL_BONUS,
  MINING_SESSION_HOURS,

  calculateMiningRate,
  calculateMiningReward,

  isMiningActive,
  isMiningFinished,
  getRemainingMilliseconds,

  startMining,
  claimMining,
  claimAdBoost,
  getMiningStatus,
  addActiveReferral,
};
