// ============================================================
// POWER FAN NETWORK — USER SERVICE
// FILE: src/services/user_service.js
// ============================================================

function createUserModel({
  uid,
  name = "",
  email = "",
  referralCode = "",
  now = Date.now(),
}) {
  return {
    uid,
    name: String(name || "").trim(),
    email: String(email || "").trim().toLowerCase(),

    fanBalance: 0,
    afamBalance: 0,

    miningRate: 0.2,

    dailyAdCount: 0,
    dailyAdBoost: 0,
    dailyAdDate: new Date(now)
      .toISOString()
      .slice(0, 10),

    activeReferralCount: 0,

    referralCode,
    referrerUid: null,

    miningActive: false,
    miningStartedAt: null,
    miningEndsAt: null,

    createdAt: now,
    updatedAt: now,
  };
}

function sanitizeUser(user) {
  if (!user) {
    return null;
  }

  return {
    uid: user.uid || "",
    name: user.name || "",
    email: user.email || "",

    fanBalance: Number(user.fanBalance || 0),
    afamBalance: Number(user.afamBalance || 0),

    miningRate: Number(user.miningRate || 0.2),

    dailyAdCount: Number(user.dailyAdCount || 0),
    dailyAdBoost: Number(user.dailyAdBoost || 0),

    activeReferralCount:
      Number(user.activeReferralCount || 0),

    referralCode: user.referralCode || "",
    referrerUid: user.referrerUid || null,

    miningActive:
      user.miningActive === true,

    miningStartedAt:
      user.miningStartedAt || null,

    miningEndsAt:
      user.miningEndsAt || null,

    createdAt:
      user.createdAt || null,

    updatedAt:
      user.updatedAt || null,
  };
}

function normalizeUser(user) {
  if (!user) {
    return null;
  }

  return {
    ...user,

    fanBalance: Number(user.fanBalance || 0),
    afamBalance: Number(user.afamBalance || 0),

    miningRate: Number(user.miningRate || 0.2),

    dailyAdCount:
      Number(user.dailyAdCount || 0),

    dailyAdBoost:
      Number(user.dailyAdBoost || 0),

    activeReferralCount:
      Number(user.activeReferralCount || 0),

    miningActive:
      user.miningActive === true,

    updatedAt: Date.now(),
  };
}

function calculateMiningRate(user) {
  if (!user) {
    return 0.2;
  }

  const baseRate = 0.2;

  const referrals =
    Math.max(
      0,
      Math.floor(
        Number(
          user.activeReferralCount || 0,
        ),
      ),
    );

  const adBoost =
    Math.min(
      0.7,
      Math.max(
        0,
        Number(
          user.dailyAdBoost || 0,
        ),
      ),
    );

  const referralBoost =
    referrals * 0.02;

  return Number(
    (
      baseRate +
      referralBoost +
      adBoost
    ).toFixed(4),
  );
}

function resetDailyAdsIfNeeded(user) {
  if (!user) {
    return null;
  }

  const today =
    new Date()
      .toISOString()
      .slice(0, 10);

  if (user.dailyAdDate !== today) {
    user.dailyAdDate = today;
    user.dailyAdCount = 0;
    user.dailyAdBoost = 0;
    user.miningRate =
      calculateMiningRate(user);
    user.updatedAt = Date.now();
  }

  return user;
}

function addFanBalance(user, amount) {
  if (!user) {
    throw new Error("User not found.");
  }

  const reward =
    Number(amount);

  if (
    !Number.isFinite(reward) ||
    reward <= 0
  ) {
    throw new Error("Invalid FAN amount.");
  }

  user.fanBalance =
    Number(user.fanBalance || 0) +
    reward;

  user.updatedAt =
    Date.now();

  return user;
}

function addAfamBalance(user, amount) {
  if (!user) {
    throw new Error("User not found.");
  }

  const amountNumber =
    Number(amount);

  if (
    !Number.isFinite(amountNumber) ||
    amountNumber <= 0
  ) {
    throw new Error("Invalid AFAM amount.");
  }

  user.afamBalance =
    Number(user.afamBalance || 0) +
    amountNumber;

  user.updatedAt =
    Date.now();

  return user;
}

function setMiningState(
  user,
  active,
  startedAt = null,
  endsAt = null,
) {
  if (!user) {
    throw new Error("User not found.");
  }

  user.miningActive =
    active === true;

  user.miningStartedAt =
    startedAt;

  user.miningEndsAt =
    endsAt;

  user.miningRate =
    calculateMiningRate(user);

  user.updatedAt =
    Date.now();

  return user;
}

function incrementActiveReferral(user) {
  if (!user) {
    throw new Error("User not found.");
  }

  user.activeReferralCount =
    Math.max(
      0,
      Number(
        user.activeReferralCount || 0,
      ),
    ) + 1;

  user.miningRate =
    calculateMiningRate(user);

  user.updatedAt =
    Date.now();

  return user;
}

function incrementAdBoost(user) {
  if (!user) {
    throw new Error("User not found.");
  }

  resetDailyAdsIfNeeded(user);

  const count =
    Number(user.dailyAdCount || 0);

  if (count >= 7) {
    return {
      success: false,
      error: "daily_ad_limit_reached",
      user,
    };
  }

  user.dailyAdCount =
    count + 1;

  user.dailyAdBoost =
    Number(
      Math.min(
        0.7,
        user.dailyAdCount * 0.1,
      ).toFixed(4),
    );

  user.miningRate =
    calculateMiningRate(user);

  user.updatedAt =
    Date.now();

  return {
    success: true,
    user,
  };
}

module.exports = {
  createUserModel,
  sanitizeUser,
  normalizeUser,
  calculateMiningRate,
  resetDailyAdsIfNeeded,
  addFanBalance,
  addAfamBalance,
  setMiningState,
  incrementActiveReferral,
  incrementAdBoost,
};
