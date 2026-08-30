// ============================================================
// POWER FAN NETWORK — USER ROUTES
// FILE: backend/src/routes/user_routes.js
// ============================================================

const express = require("express");
const admin = require("firebase-admin");

const router = express.Router();

const db = admin.database();

// ============================================================
// CONFIGURATION
// ============================================================

const BASE_MINING_RATE = 0.2;
const AD_BOOST_PER_AD = 0.1;
const MAXIMUM_DAILY_ADS = 7;
const MAXIMUM_AD_BOOST = 0.7;

// Unlimited active referrals.
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
  const today = todayKey();

  if (user.dailyAdDate !== today) {
    user.dailyAdDate = today;
    user.dailyAdCount = 0;
    user.dailyAdBoost = 0;
  }

  return user;
}

function publicUser(user) {
  if (!user) {
    return null;
  }

  return {
    uid: user.uid || "",

    name:
      user.name ||
      "",

    email:
      user.email ||
      "",

    fanBalance:
      safeNumber(
        user.fanBalance,
      ),

    afamBalance:
      safeNumber(
        user.afamBalance,
      ),

    miningRate:
      calculateMiningRate(
        user,
      ),

    miningActive:
      user.miningActive === true,

    miningStartedAt:
      user.miningStartedAt ||
      null,

    miningEndsAt:
      user.miningEndsAt ||
      null,

    dailyAdCount:
      safeNumber(
        user.dailyAdCount,
      ),

    dailyAdBoost:
      safeNumber(
        user.dailyAdBoost,
      ),

    activeReferralCount:
      safeNumber(
        user.activeReferralCount,
      ),

    referralCode:
      user.referralCode ||
      "",

    referrerUid:
      user.referrerUid ||
      null,

    createdAt:
      user.createdAt ||
      null,

    updatedAt:
      user.updatedAt ||
      null,
  };
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
// GET CURRENT USER
// ============================================================

router.get("/me", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
      });
    }

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

    return res.json({
      success: true,

      user:
        publicUser(user),
    });
  } catch (error) {
    console.error(
      "Get current user error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "user_fetch_failed",
    });
  }
});

// ============================================================
// GET PROFILE
// ============================================================

router.get("/profile", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
      });
    }

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

    return res.json({
      success: true,

      user:
        publicUser(user),
    });
  } catch (error) {
    console.error(
      "Profile error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "profile_fetch_failed",
    });
  }
});

// ============================================================
// USER BALANCE
// ============================================================

router.get("/balance", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
      });
    }

    const user =
      await getUser(uid);

    if (!user) {
      return res.status(404).json({
        success: false,
        error:
          "user_not_found",
      });
    }

    return res.json({
      success: true,

      fanBalance:
        safeNumber(
          user.fanBalance,
        ),

      afamBalance:
        safeNumber(
          user.afamBalance,
        ),

      coin:
        "FAN",

      originalCoin:
        "AFAM",
    });
  } catch (error) {
    console.error(
      "Balance error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "balance_fetch_failed",
    });
  }
});

// ============================================================
// USER MINING SUMMARY
// ============================================================

router.get(
  "/mining-summary",
  async (req, res) => {
    try {
      const uid =
        req.user?.uid;

      if (!uid) {
        return res.status(401).json({
          success: false,
          error:
            "missing_authentication",
        });
      }

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

      const referrals =
        Math.max(
          0,
          Math.floor(
            safeNumber(
              user.activeReferralCount,
            ),
          ),
        );

      const referralBonus =
        referrals *
        ACTIVE_REFERRAL_BONUS;

      const adBoost =
        Math.min(
          MAXIMUM_AD_BOOST,
          Math.max(
            0,
            safeNumber(
              user.dailyAdBoost,
            ),
          ),
        );

      const miningRate =
        calculateMiningRate(
          user,
        );

      return res.json({
        success: true,

        coin:
          "FAN",

        fanBalance:
          safeNumber(
            user.fanBalance,
          ),

        baseMiningRate:
          BASE_MINING_RATE,

        activeReferralCount:
          referrals,

        referralMiningBonus:
          Number(
            referralBonus.toFixed(8),
          ),

        dailyAdCount:
          safeNumber(
            user.dailyAdCount,
          ),

        dailyAdBoost:
          adBoost,

        miningRate,

        miningActive:
          user.miningActive === true,

        miningStartedAt:
          user.miningStartedAt ||
          null,

        miningEndsAt:
          user.miningEndsAt ||
          null,
      });
    } catch (error) {
      console.error(
        "Mining summary error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error:
          "mining_summary_failed",
      });
    }
  },
);

// ============================================================
// UPDATE NAME
// ============================================================

router.patch("/name", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
      });
    }

    const name =
      String(
        req.body?.name || "",
      ).trim();

    if (!name) {
      return res.status(400).json({
        success: false,
        error:
          "name_required",
      });
    }

    if (name.length > 80) {
      return res.status(400).json({
        success: false,
        error:
          "name_too_long",
      });
    }

    const userRef =
      db.ref(`users/${uid}`);

    const result =
      await userRef.transaction(
        (user) => {
          if (!user) {
            return user;
          }

          user.name = name;
          user.updatedAt = now();

          return user;
        },
      );

    if (!result.committed) {
      return res.status(404).json({
        success: false,
        error:
          "user_not_found",
      });
    }

    // Update Firebase Auth display name too.
    try {
      await admin
        .auth()
        .updateUser(uid, {
          displayName: name,
        });
    } catch (authError) {
      console.error(
        "Firebase Auth display name update error:",
        authError.message,
      );
    }

    const user =
      result.snapshot.val();

    return res.json({
      success: true,

      message:
        "Name updated successfully.",

      user:
        publicUser(user),
    });
  } catch (error) {
    console.error(
      "Update name error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "name_update_failed",
    });
  }
});

// ============================================================
// REFERRAL INFORMATION
// ============================================================

router.get(
  "/referral-info",
  async (req, res) => {
    try {
      const uid =
        req.user?.uid;

      if (!uid) {
        return res.status(401).json({
          success: false,
          error:
            "missing_authentication",
        });
      }

      const user =
        await getUser(uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error:
            "user_not_found",
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

        referralCode:
          user.referralCode ||
          "",

        referrerUid:
          user.referrerUid ||
          null,

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
      });
    } catch (error) {
      console.error(
        "Referral info error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error:
          "referral_info_failed",
      });
    }
  },
);

// ============================================================
// DELETE / DISABLE USER DATA
// ============================================================
// This route does NOT delete Firebase Authentication.
// It only marks the application profile as disabled.
// ============================================================

router.post(
  "/disable",
  async (req, res) => {
    try {
      const uid =
        req.user?.uid;

      if (!uid) {
        return res.status(401).json({
          success: false,
          error:
            "missing_authentication",
        });
      }

      const userRef =
        db.ref(`users/${uid}`);

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) {
              return user;
            }

            user.accountDisabled =
              true;

            user.disabledAt =
              now();

            user.updatedAt =
              now();

            // Stop mining immediately.
            user.miningActive =
              false;

            user.miningStartedAt =
              null;

            user.miningEndsAt =
              null;

            return user;
          },
        );

      if (!result.committed) {
        return res.status(404).json({
          success: false,
          error:
            "user_not_found",
        });
      }

      return res.json({
        success: true,

        message:
          "Account disabled successfully.",
      });
    } catch (error) {
      console.error(
        "Disable account error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error:
          "account_disable_failed",
      });
    }
  },
);

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
