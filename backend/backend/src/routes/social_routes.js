// ============================================================
// POWER FAN NETWORK — SOCIAL ROUTES
// FILE: backend/src/routes/social_routes.js
// ============================================================

const express = require("express");
const admin = require("firebase-admin");

const router = express.Router();

const db = admin.database();

// ============================================================
// CONFIGURATION
// ============================================================

const COIN = "FAN";
const DAILY_SOCIAL_REWARD = 10;

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

async function getUser(uid) {
  const snapshot = await db
    .ref(`users/${uid}`)
    .once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

// ============================================================
// SOCIAL CONFIG
// ============================================================

router.get("/config", (req, res) => {
  return res.json({
    success: true,

    coin: COIN,

    dailyReward:
      DAILY_SOCIAL_REWARD,
  });
});

// ============================================================
// TODAY STATUS
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

    const date = todayKey();

    const claimSnapshot =
      await db
        .ref(
          `socialClaims/${uid}/${date}`,
        )
        .once("value");

    return res.json({
      success: true,

      date,

      claimed:
        claimSnapshot.exists(),

      reward:
        DAILY_SOCIAL_REWARD,

      coin: COIN,
    });
  } catch (error) {
    console.error(
      "Social status error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "social_status_failed",
    });
  }
});

// ============================================================
// CLAIM DAILY SOCIAL REWARD
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

    const date = todayKey();

    const claimRef =
      db.ref(
        `socialClaims/${uid}/${date}`,
      );

    // --------------------------------------------------------
    // ATOMIC CLAIM LOCK
    // --------------------------------------------------------

    const claimResult =
      await claimRef.transaction(
        (existing) => {
          if (existing) {
            return;
          }

          return {
            uid,

            reward:
              DAILY_SOCIAL_REWARD,

            coin: COIN,

            claimedAt: now(),
          };
        },
      );

    if (!claimResult.committed) {
      return res.status(400).json({
        success: false,
        error:
          "social_reward_already_claimed",
      });
    }

    // --------------------------------------------------------
    // ADD FAN REWARD ATOMICALLY
    // --------------------------------------------------------

    const userRef =
      db.ref(`users/${uid}`);

    let finalBalance = 0;

    const balanceResult =
      await userRef.transaction(
        (user) => {
          if (!user) {
            return user;
          }

          const oldBalance =
            safeNumber(
              user.fanBalance,
            );

          finalBalance =
            Number(
              (
                oldBalance +
                DAILY_SOCIAL_REWARD
              ).toFixed(8),
            );

          user.fanBalance =
            finalBalance;

          user.updatedAt =
            now();

          return user;
        },
      );

    if (!balanceResult.committed) {
      // Remove claim lock so the user can retry.
      await claimRef.remove();

      return res.status(500).json({
        success: false,
        error:
          "social_reward_failed",
      });
    }

    const user =
      balanceResult.snapshot.val();

    return res.json({
      success: true,

      message:
        "Daily social reward claimed.",

      coin: COIN,

      reward:
        DAILY_SOCIAL_REWARD,

      fanBalance:
        safeNumber(
          user.fanBalance,
        ),

      claimedAt:
        claimResult.snapshot.val()
          ?.claimedAt || now(),
    });
  } catch (error) {
    console.error(
      "Social claim error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "social_claim_failed",
    });
  }
});

// ============================================================
// MY SOCIAL CLAIM HISTORY
// ============================================================

router.get("/history", async (req, res) => {
  try {
    const uid = req.user?.uid;

    if (!uid) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
      });
    }

    const snapshot =
      await db
        .ref(`socialClaims/${uid}`)
        .once("value");

    const data =
      snapshot.val() || {};

    const history =
      Object.entries(data)
        .map(
          ([date, claim]) => ({
            date,
            reward:
              safeNumber(
                claim?.reward,
              ),
            coin:
              claim?.coin || COIN,
            claimedAt:
              claim?.claimedAt || null,
          }),
        )
        .sort(
          (a, b) =>
            safeNumber(
              b.claimedAt,
            ) -
            safeNumber(
              a.claimedAt,
            ),
        );

    return res.json({
      success: true,

      totalClaims:
        history.length,

      totalReward:
        Number(
          history
            .reduce(
              (total, item) =>
                total +
                safeNumber(
                  item.reward,
                ),
              0,
            )
            .toFixed(8),
        ),

      history,
    });
  } catch (error) {
    console.error(
      "Social history error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "social_history_failed",
    });
  }
});

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
