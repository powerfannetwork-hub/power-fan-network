// ============================================================
// POWER FAN NETWORK — AD SERVICE
// FILE: src/services/ad_service.js
// ============================================================

const AD_BOOST_PER_AD = 0.1;
const MAXIMUM_DAILY_ADS = 7;
const MAXIMUM_AD_BOOST = 0.7;

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function safeNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function resetDailyAds(user) {
  const today = todayKey();

  if (user.dailyAdDate !== today) {
    user.dailyAdDate = today;
    user.dailyAdCount = 0;
    user.dailyAdBoost = 0;
  }

  return user;
}

function calculateAdBoost(adCount) {
  const count = Math.max(
    0,
    Math.min(
      MAXIMUM_DAILY_ADS,
      Math.floor(safeNumber(adCount)),
    ),
  );

  return Number(
    Math.min(
      MAXIMUM_AD_BOOST,
      count * AD_BOOST_PER_AD,
    ).toFixed(8),
  );
}

function canClaimAd(user) {
  resetDailyAds(user);

  const count =
    safeNumber(user.dailyAdCount);

  if (count >= MAXIMUM_DAILY_ADS) {
    return {
      allowed: false,
      error: "daily_ad_limit_reached",
      dailyAdCount: count,
      dailyAdBoost:
        calculateAdBoost(count),
    };
  }

  return {
    allowed: true,
    dailyAdCount: count,
    remainingAds:
      MAXIMUM_DAILY_ADS - count,
  };
}

function claimAd(user) {
  if (!user) {
    throw new Error("User not found.");
  }

  resetDailyAds(user);

  const permission =
    canClaimAd(user);

  if (!permission.allowed) {
    return {
      success: false,
      error: permission.error,
      dailyAdCount:
        permission.dailyAdCount,
      dailyAdBoost:
        permission.dailyAdBoost,
    };
  }

  const newCount =
    safeNumber(user.dailyAdCount) + 1;

  const newBoost =
    calculateAdBoost(newCount);

  user.dailyAdCount =
    newCount;

  user.dailyAdBoost =
    newBoost;

  user.updatedAt =
    Date.now();

  return {
    success: true,
    dailyAdCount: newCount,
    dailyAdBoost: newBoost,
    remainingAds:
      MAXIMUM_DAILY_ADS - newCount,
  };
}

function getAdStatus(user) {
  if (!user) {
    return {
      dailyAdCount: 0,
      dailyAdBoost: 0,
      remainingAds:
        MAXIMUM_DAILY_ADS,
    };
  }

  resetDailyAds(user);

  const count =
    safeNumber(user.dailyAdCount);

  return {
    dailyAdCount: count,
    dailyAdBoost:
      calculateAdBoost(count),
    remainingAds:
      Math.max(
        0,
        MAXIMUM_DAILY_ADS - count,
      ),
    maximumDailyAds:
      MAXIMUM_DAILY_ADS,
    adBoostPerAd:
      AD_BOOST_PER_AD,
    maximumAdBoost:
      MAXIMUM_AD_BOOST,
  };
}

module.exports = {
  AD_BOOST_PER_AD,
  MAXIMUM_DAILY_ADS,
  MAXIMUM_AD_BOOST,

  todayKey,
  safeNumber,
  resetDailyAds,
  calculateAdBoost,
  canClaimAd,
  claimAd,
  getAdStatus,
};
