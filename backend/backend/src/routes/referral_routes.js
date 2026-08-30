// ============================================================
// POWER FAN NETWORK — REFERRAL ROUTES
// FILE: backend/src/routes/referral_routes.js
// ============================================================

const express = require("express");
const admin = require("firebase-admin");

const router = express.Router();

const db = admin.database();

// ============================================================
// CONFIGURATION
// ============================================================

const NEW_USER_REWARD = 20;
const INVITER_REWARD = 5;

// EVERY active referral gives +0.02 FAN/H.
// NO LIMIT — 1, 100, 1000 or more.
const ACTIVE_REFERRAL_BONUS = 0.02;

const COIN = "FAN";

// ============================================================
// HELPERS
// ============================================================

function now() {
  return Date.now();
}

function cleanCode(value) {
  return String(value || "")
    .trim()
    .toUpperCase();
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

  const adBoost = Math.max(
    0,
    safeNumber(user.dailyAdBoost),
  );

  // NO maximum referral limit.
  return Number(
    (
      0.2 +
      referrals * ACTIVE_REFERRAL_BONUS +
      adBoost
    ).toFixed(8),
  );
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
// REFERRAL CONFIG
// ============================================================

router.get("/config", (req, res) => {
  return res.json({
    success: true,

    coin: COIN,

    newUserReward:
      NEW_USER_REWARD,

    inviterReward:
      INVITER_REWARD,

    miningRatePerActiveReferral:
      ACTIVE_REFERRAL_BONUS,

    referralLimit:
      "UNLIMITED",
  });
});

// ============================================================
// APPLY REFERRAL
// ============================================================

router.post("/apply", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
      });
    }

    const referralCode =
      cleanCode(
        req.body.referralCode,
      );

    if (!referralCode) {
      return res.status(400).json({
        success: false,
        error:
          "referral_code_required",
      });
    }

    // --------------------------------------------------------
    // GET NEW USER
    // --------------------------------------------------------

    const userRef =
      db.ref(`users/${uid}`);

    const userSnapshot =
      await userRef.once("value");

    if (!userSnapshot.exists()) {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
      });
    }

    const user =
      userSnapshot.val();

    // A user can only use one referral.
    if (user.referrerUid) {
      return res.status(400).json({
        success: false,
        error:
          "referral_already_used",
      });
    }

    // --------------------------------------------------------
    // FIND INVITER
    // --------------------------------------------------------

    const codeSnapshot =
      await db
        .ref(`referralCodes/${referralCode}`)
        .once("value");

    if (!codeSnapshot.exists()) {
      return res.status(400).json({
        success: false,
        error:
          "invalid_referral_code",
      });
    }

    const inviterUid =
      codeSnapshot.val();

    if (!inviterUid) {
      return res.status(400).json({
        success: false,
        error:
          "invalid_referral_code",
      });
    }

    if (inviterUid === uid) {
      return res.status(400).json({
        success: false,
        error:
          "cannot_refer_yourself",
      });
    }

    // --------------------------------------------------------
    // GET INVITER
    // --------------------------------------------------------

    const inviterRef =
      db.ref(`users/${inviterUid}`);

    const inviterSnapshot =
      await inviterRef.once("value");

    if (!inviterSnapshot.exists()) {
      return res.status(400).json({
        success: false,
        error:
          "inviter_not_found",
      });
    }

    // --------------------------------------------------------
    // ATOMIC REFERRAL LOCK
    // --------------------------------------------------------
    // Prevents the same new user from receiving the referral
    // reward twice if two requests arrive simultaneously.
    // --------------------------------------------------------

    const claimRef =
      db.ref(
        `referralClaims/${inviterUid}/${uid}`,
      );

    const claimResult =
      await claimRef.transaction(
        (existing) => {
          if (existing) {
            return;
          }

          return {
            uid,
            inviterUid,
            referralCode,
            createdAt: now(),
          };
        },
      );

    if (!claimResult.committed) {
      return res.status(400).json({
        success: false,
        error:
          "referral_already_used",
      });
    }

    // --------------------------------------------------------
    // UPDATE INVITER ATOMICALLY
    // --------------------------------------------------------

    let inviterAfter =
      null;

    const inviterResult =
      await inviterRef.transaction(
        (current) => {
          if (!current) {
            return current;
          }

          const oldBalance =
            safeNumber(
              current.fanBalance,
            );

          const oldCount =
            Math.max(
              0,
              Math.floor(
                safeNumber(
                  current.activeReferralCount,
                ),
              ),
            );

          const newCount =
            oldCount + 1;

          current.fanBalance =
            Number(
              (
                oldBalance +
                INVITER_REWARD
              ).toFixed(8),
            );

          current.activeReferralCount =
            newCount;

          current.miningRate =
            calculateMiningRate(
              current,
            );

          current.updatedAt =
            now();

          return current;
        },
      );

    if (!inviterResult.committed) {
      await claimRef.remove();

      return res.status(500).json({
        success: false,
        error:
          "referral_processing_failed",
      });
    }

    inviterAfter =
      inviterResult.snapshot.val();

    // --------------------------------------------------------
    // UPDATE NEW USER
    // --------------------------------------------------------

    const userResult =
      await userRef.transaction(
        (current) => {
          if (!current) {
            return current;
          }

          // Protect against a second referral.
          if (current.referrerUid) {
            return;
          }

          current.referrerUid =
            inviterUid;

          current.fanBalance =
            Number(
              (
                safeNumber(
                  current.fanBalance,
                ) +
                NEW_USER_REWARD
              ).toFixed(8),
            );

          current.updatedAt =
            now();

          return current;
        },
      );

    if (!userResult.committed) {
      // Roll back inviter reward when possible.
      await inviterRef.transaction(
        (current) => {
          if (!current) {
            return current;
          }

          current.fanBalance =
            Number(
              Math.max(
                0,
                safeNumber(
                  current.fanBalance,
                ) -
                  INVITER_REWARD,
              ).toFixed(8),
            );

          current.activeReferralCount =
            Math.max(
              0,
              Math.floor(
                safeNumber(
                  current.activeReferralCount,
                ),
              ) - 1,
            );

          current.miningRate =
            calculateMiningRate(
              current,
            );

          current.updatedAt =
            now();

          return current;
        },
      );

      await claimRef.remove();

      return res.status(400).json({
        success: false,
        error:
          "referral_processing_failed",
      });
    }

    // --------------------------------------------------------
    // CREATE REFERRAL RECORD
    // --------------------------------------------------------

    const timestamp = now();

    await db.ref().update({
      [`referrals/${inviterUid}/${uid}`]: {
        uid,
        inviterUid,
        referralCode,

        active: true,

        createdAt: timestamp,
        updatedAt: timestamp,
      },

      [`users/${uid}/referralAppliedAt`]:
        timestamp,

      [`users/${uid}/referralCodeUsed`]:
        referralCode,
    });

    // --------------------------------------------------------
    // RESPONSE
    // --------------------------------------------------------

    const finalUser =
      userResult.snapshot.val();

    return res.json({
      success: true,

      message:
        "Referral successfully applied.",

      coin: COIN,

      newUserReward:
        NEW_USER_REWARD,

      inviterReward:
        INVITER_REWARD,

      activeReferralMiningBonus:
        ACTIVE_REFERRAL_BONUS,

      activeReferralCount:
        safeNumber(
          inviterAfter.activeReferralCount,
        ),

      inviterMiningRate:
        calculateMiningRate(
          inviterAfter,
        ),

      fanBalance:
        safeNumber(
          finalUser.fanBalance,
        ),
    });
  } catch (error) {
    console.error(
      "Referral apply error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "referral_processing_failed",
    });
  }
});

// ============================================================
// REFERRAL LIST
// ============================================================

router.get("/list", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
      });
    }

    const snapshot =
      await db
        .ref(`referrals/${uid}`)
        .once("value");

    const data =
      snapshot.val() || {};

    const referrals =
      Object.values(data);

    const activeReferrals =
      referrals.filter(
        (item) =>
          item &&
          item.active === true,
      );

    return res.json({
      success: true,

      activeReferralCount:
        activeReferrals.length,

      referralMiningBonus:
        Number(
          (
            activeReferrals.length *
            ACTIVE_REFERRAL_BONUS
          ).toFixed(8),
        ),

      referrals:
        activeReferrals,
    });
  } catch (error) {
    console.error(
      "Referral list error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "referral_list_failed",
    });
  }
});

// ============================================================
// MY REFERRAL SUMMARY
// ============================================================

router.get("/summary", async (req, res) => {
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

    const count =
      Math.max(
        0,
        Math.floor(
          safeNumber(
            user.activeReferralCount,
          ),
        ),
      );

    return res.json({
      success: true,

      coin: COIN,

      referralCode:
        user.referralCode || "",

      activeReferralCount:
        count,

      miningRatePerReferral:
        ACTIVE_REFERRAL_BONUS,

      totalReferralMiningBonus:
        Number(
          (
            count *
            ACTIVE_REFERRAL_BONUS
          ).toFixed(8),
        ),

      miningRate:
        calculateMiningRate(user),

      fanBalance:
        safeNumber(
          user.fanBalance,
        ),
    });
  } catch (error) {
    console.error(
      "Referral summary error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "referral_summary_failed",
    });
  }
});

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
