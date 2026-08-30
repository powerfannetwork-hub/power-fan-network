// ============================================================
// POWER FAN NETWORK — ADS ROUTES
// FILE: backend/src/routes/ads_routes.js
// ============================================================

const express = require("express");
const admin = require("firebase-admin");

const router = express.Router();

const db = admin.database();

// ============================================================
// CONFIGURATION
// ============================================================

const COIN = "FAN";

const AD_BOOST_PER_AD = 0.1;
const MAXIMUM_DAILY_ADS = 7;
const MAXIMUM_AD_BOOST = 0.7;

const BASE_MINING_RATE = 0.2;

// Every active referral gives +0.02 FAN/H.
// There is NO referral limit.
const ACTIVE_REFERRAL_BONUS = 0.02;

// ============================================================
// HELPERS
// ============================================================

function now() {
  return Date.now();
}

function todayKey() {
  return new Date()
    .toISOString()
    .slice(0, 10);
}

function safeNumber(value, fallback = 0) {
  const number = Number(value);

  return Number.isFinite(number)
    ? number
    : fallback;
}

function calculateMiningRate(user) {
  const referrals = Math.max(
    0,
    Math.floor(
      safeNumber(
        user.activeReferralCount,
      ),
    ),
  );

  const adBoost = Math.min(
    MAXIMUM_AD_BOOST,
    Math.max(
      0,
      safeNumber(
        user.dailyAdBoost,
      ),
    ),
  );

  return Number(
    (
      BASE_MINING_RATE +
      referrals *
        ACTIVE_REFERRAL_BONUS +
      adBoost
    ).toFixed(8),
  );
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
  const snapshot =
    await db
      .ref(`users/${uid}`)
      .once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

// ============================================================
// ADS CONFIG
// ============================================================

router.get("/config", (req, res) => {
  return res.json({
    success: true,

    coin: COIN,

    adBoostPerAd:
      AD_BOOST_PER_AD,

    maximumDailyAds:
      MAXIMUM_DAILY_ADS,

    maximumAdBoost:
      MAXIMUM_AD_BOOST,

    activeReferralBonus:
      ACTIVE_REFERRAL_BONUS,
  });
});

// ============================================================
// ADS STATUS
// ============================================================

router.get("/status", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
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

    const count =
      safeNumber(
        user.dailyAdCount,
      );

    const boost =
      Math.min(
        MAXIMUM_AD_BOOST,
        Math.max(
          0,
          safeNumber(
            user.dailyAdBoost,
          ),
        ),
      );

    return res.json({
      success: true,

      dailyAdCount:
        count,

      remainingAds:
        Math.max(
          0,
          MAXIMUM_DAILY_ADS -
            count,
        ),

      dailyAdBoost:
        boost,

      adBoostPerAd:
        AD_BOOST_PER_AD,

      maximumDailyAds:
        MAXIMUM_DAILY_ADS,

      maximumAdBoost:
        MAXIMUM_AD_BOOST,

      miningRate:
        calculateMiningRate(
          user,
        ),
    });
  } catch (error) {
    console.error(
      "Ads status error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error: "ads_status_failed",
    });
  }
});

// ============================================================
// CLAIM COMPLETED REWARDED AD
// ============================================================

router.post("/claim", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
      });
    }

    const userRef =
      db.ref(`users/${uid}`);

    let newCount = 0;
    let newBoost = 0;
    let newMiningRate = 0;

    const result =
      await userRef.transaction(
        (user) => {
          if (!user) {
            return user;
          }

          resetDailyAds(user);

          const count =
            safeNumber(
              user.dailyAdCount,
            );

          if (
            count >=
            MAXIMUM_DAILY_ADS
          ) {
            return;
          }

          const nextCount =
            count + 1;

          const nextBoost =
            Math.min(
              MAXIMUM_AD_BOOST,
              nextCount *
                AD_BOOST_PER_AD,
            );

          user.dailyAdCount =
            nextCount;

          user.dailyAdBoost =
            Number(
              nextBoost.toFixed(8),
            );

          user.miningRate =
            calculateMiningRate(
              user,
            );

          user.updatedAt =
            now();

          newCount =
            nextCount;

          newBoost =
            nextBoost;

          newMiningRate =
            user.miningRate;

          return user;
        },
      );

    if (!result.committed) {
      const user =
        await getUser(uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error:
            "user_not_found",
        });
      }

      resetDailyAds(user);

      if (
        safeNumber(
          user.dailyAdCount,
        ) >=
        MAXIMUM_DAILY_ADS
      ) {
        return res.status(400).json({
          success: false,
          error:
            "daily_ad_limit_reached",

          dailyAdCount:
            safeNumber(
              user.dailyAdCount,
            ),

          dailyAdBoost:
            safeNumber(
              user.dailyAdBoost,
            ),

          remainingAds: 0,
        });
      }

      return res.status(400).json({
        success: false,
        error: "ad_claim_failed",
      });
    }

    const finalUser =
      result.snapshot.val();

    return res.json({
      success: true,

      message:
        "Mining boost added.",

      coin: COIN,

      dailyAdCount:
        newCount,

      remainingAds:
        Math.max(
          0,
          MAXIMUM_DAILY_ADS -
            newCount,
        ),

      dailyAdBoost:
        Number(
          newBoost.toFixed(8),
        ),

      miningRate:
        newMiningRate,

      fanBalance:
        safeNumber(
          finalUser.fanBalance,
        ),
    });
  } catch (error) {
    console.error(
      "Ad claim error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error: "ad_claim_failed",
    });
  }
});

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
