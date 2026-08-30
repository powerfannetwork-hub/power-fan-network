// ============================================================
// POWER FAN NETWORK — MINING ROUTES
// FILE: backend/src/routes/mining_routes.js
// ============================================================

const express = require("express");
const admin = require("firebase-admin");

const router = express.Router();

const db = admin.database();

// ============================================================
// MINING CONFIGURATION
// ============================================================

const BASE_MINING_RATE = 0.2;

const AD_BOOST_PER_AD = 0.1;
const MAXIMUM_DAILY_ADS = 7;
const MAXIMUM_AD_BOOST = 0.7;

// UNLIMITED ACTIVE REFERRALS.
// Every active referral = +0.02 FAN/H.
const ACTIVE_REFERRAL_BONUS = 0.02;

const MINING_SESSION_HOURS = 24;

// ============================================================
// HELPERS
// ============================================================

function now() {
  return Date.now();
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function safeNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function calculateMiningRate(user) {
  const referrals = Math.max(
    0,
    Math.floor(
      safeNumber(user.activeReferralCount),
    ),
  );

  const adBoost = Math.min(
    MAXIMUM_AD_BOOST,
    Math.max(
      0,
      safeNumber(user.dailyAdBoost),
    ),
  );

  const referralBoost =
    referrals * ACTIVE_REFERRAL_BONUS;

  // NO maximum mining-rate cap.
  const rate =
    BASE_MINING_RATE +
    referralBoost +
    adBoost;

  return Number(rate.toFixed(8));
}

function resetDailyAds(user) {
  const date = todayKey();

  if (user.dailyAdDate !== date) {
    user.dailyAdDate = date;
    user.dailyAdCount = 0;
    user.dailyAdBoost = 0;
  }

  return user;
}

async function getUser(uid) {
  const snapshot = await db
    .ref(`users/${uid}`)
    .once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

// ============================================================
// MINING CONFIG
// ============================================================

router.get("/config", (req, res) => {
  res.json({
    success: true,
    coin: "FAN",

    baseMiningRate: BASE_MINING_RATE,

    adBoostPerAd: AD_BOOST_PER_AD,
    maximumDailyAds: MAXIMUM_DAILY_ADS,
    maximumAdBoost: MAXIMUM_AD_BOOST,

    activeReferralMiningBonus:
      ACTIVE_REFERRAL_BONUS,

    referralBonusLimit: "UNLIMITED",

    miningSessionHours:
      MINING_SESSION_HOURS,
  });
});

// ============================================================
// START MINING
// ============================================================

router.post("/start", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
      });
    }

    const userRef = db.ref(`users/${uid}`);

    let alreadyActive = false;

    const result = await userRef.transaction((user) => {
      if (!user) {
        return user;
      }

      resetDailyAds(user);

      if (user.miningActive === true) {
        alreadyActive = true;
        return;
      }

      const startedAt = now();

      const endsAt =
        startedAt +
        MINING_SESSION_HOURS *
          60 *
          60 *
          1000;

      user.miningActive = true;
      user.miningStartedAt = startedAt;
      user.miningEndsAt = endsAt;

      user.miningRate =
        calculateMiningRate(user);

      user.updatedAt = startedAt;

      return user;
    });

    if (!result.committed) {
      const user = await getUser(uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      if (
        alreadyActive ||
        user.miningActive === true
      ) {
        return res.status(400).json({
          success: false,
          error: "mining_already_active",
          miningEndsAt:
            user.miningEndsAt,
          miningRate:
            calculateMiningRate(user),
        });
      }

      return res.status(400).json({
        success: false,
        error: "mining_start_failed",
      });
    }

    const user = result.snapshot.val();

    return res.json({
      success: true,
      message: "Mining session started.",

      coin: "FAN",

      miningActive: true,

      miningRate:
        calculateMiningRate(user),

      miningStartedAt:
        user.miningStartedAt,

      miningEndsAt:
        user.miningEndsAt,
    });
  } catch (error) {
    console.error("Mining start error:", error);

    return res.status(500).json({
      success: false,
      error: "mining_start_failed",
    });
  }
});

// ============================================================
// MINING STATUS
// ============================================================

router.get("/status", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
      });
    }

    const user = await getUser(uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
      });
    }

    resetDailyAds(user);

    const active =
      user.miningActive === true;

    const endsAt =
      safeNumber(user.miningEndsAt);

    const remaining =
      active
        ? Math.max(0, endsAt - now())
        : 0;

    return res.json({
      success: true,

      coin: "FAN",

      miningActive: active,

      miningFinished:
        active && remaining <= 0,

      miningRate:
        calculateMiningRate(user),

      baseMiningRate:
        BASE_MINING_RATE,

      activeReferralCount:
        safeNumber(
          user.activeReferralCount,
        ),

      referralMiningBonus:
        Number(
          (
            safeNumber(
              user.activeReferralCount,
            ) *
            ACTIVE_REFERRAL_BONUS
          ).toFixed(8),
        ),

      dailyAdCount:
        safeNumber(user.dailyAdCount),

      dailyAdBoost:
        safeNumber(user.dailyAdBoost),

      miningStartedAt:
        user.miningStartedAt || null,

      miningEndsAt:
        user.miningEndsAt || null,

      remainingMilliseconds:
        remaining,

      fanBalance:
        safeNumber(user.fanBalance),
    });
  } catch (error) {
    console.error(
      "Mining status error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error: "mining_status_failed",
    });
  }
});

// ============================================================
// CLAIM MINING REWARD
// ============================================================

router.post("/claim", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
      });
    }

    const userRef = db.ref(`users/${uid}`);

    let earnedAmount = 0;

    const result = await userRef.transaction((user) => {
      if (!user) {
        return user;
      }

      if (user.miningActive !== true) {
        return;
      }

      const currentTime = now();

      const startedAt =
        safeNumber(user.miningStartedAt);

      const endsAt =
        safeNumber(user.miningEndsAt);

      if (!startedAt || !endsAt) {
        return;
      }

      if (currentTime < endsAt) {
        return;
      }

      const elapsedHours = Math.min(
        MINING_SESSION_HOURS,
        Math.max(
          0,
          (endsAt - startedAt) /
            (60 * 60 * 1000),
        ),
      );

      const miningRate =
        calculateMiningRate(user);

      earnedAmount = Number(
        (
          miningRate *
          elapsedHours
        ).toFixed(8),
      );

      user.fanBalance = Number(
        (
          safeNumber(user.fanBalance) +
          earnedAmount
        ).toFixed(8),
      );

      user.miningActive = false;
      user.miningStartedAt = null;
      user.miningEndsAt = null;
      user.miningRate = miningRate;
      user.updatedAt = currentTime;

      return user;
    });

    if (!result.committed) {
      const user = await getUser(uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      if (user.miningActive !== true) {
        return res.status(400).json({
          success: false,
          error: "nothing_to_claim",
        });
      }

      const endsAt =
        safeNumber(user.miningEndsAt);

      if (now() < endsAt) {
        return res.status(400).json({
          success: false,
          error: "mining_not_finished",

          miningEndsAt:
            user.miningEndsAt,

          remainingMilliseconds:
            Math.max(
              0,
              endsAt - now(),
            ),
        });
      }

      return res.status(400).json({
        success: false,
        error: "claim_failed",
      });
    }

    const finalUser =
      result.snapshot.val();

    return res.json({
      success: true,

      message:
        "Mining reward claimed.",

      coin: "FAN",

      earned: earnedAmount,

      fanBalance:
        safeNumber(
          finalUser.fanBalance,
        ),

      miningActive: false,

      miningRate:
        calculateMiningRate(
          finalUser,
        ),
    });
  } catch (error) {
    console.error(
      "Mining claim error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error: "mining_claim_failed",
    });
  }
});

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
