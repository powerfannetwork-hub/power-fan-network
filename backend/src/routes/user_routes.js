// ============================================================
// POWER FAN NETWORK
// USER ROUTES
// ============================================================

const express = require("express");

const {
  authenticate,
} = require("../../middleware/auth");

const { getDb } =
  require("../firebase");

const router = express.Router();

// ============================================================
// PUBLIC USER
// ============================================================

function publicUser(user) {
  return {
    id: user.id,

    name:
      user.name || "",

    email:
      user.email || "",

    referralCode:
      user.referralCode || "",

    referredBy:
      user.referredBy || null,

    fanBalance:
      Number(user.fanBalance || 0),

    afamBalance:
      Number(user.afamBalance || 0),

    miningRate:
      Number(user.miningRate || 0.2),

    activeReferrals:
      Number(
        user.activeReferrals || 0
      ),

    dailyAdsWatched:
      Number(
        user.dailyAdsWatched || 0
      ),

    adBoost:
      Number(user.adBoost || 0),

    miningActive:
      Boolean(user.miningActive),

    miningStartedAt:
      user.miningStartedAt ||
      null,

    miningEndsAt:
      user.miningEndsAt ||
      null,

    consecutiveCheckIns:
      Number(
        user.consecutiveCheckIns ||
          0
      ),

    kyc1Eligible:
      Boolean(user.kyc1Eligible),

    kyc1Verified:
      Boolean(user.kyc1Verified),

    kyc2Eligible:
      Boolean(user.kyc2Eligible),

    kyc2Verified:
      Boolean(user.kyc2Verified),

    kyc3Verified:
      Boolean(user.kyc3Verified),

    createdAt:
      user.createdAt || null,

    updatedAt:
      user.updatedAt || null,
  };
}

// ============================================================
// PROFILE
// ============================================================

router.get(
  "/profile",
  authenticate,
  async (req, res) => {
    return res.json({
      success: true,
      user:
        publicUser(req.user),
    });
  }
);

// ============================================================
// UPDATE PROFILE
// ============================================================

router.put(
  "/profile",
  authenticate,
  async (req, res) => {
    try {
      const db = getDb();

      if (!db) {
        return res.status(503).json({
          success: false,
          message:
            "Database is not connected.",
        });
      }

      const updates = {};

      if (
        req.body.name !==
        undefined
      ) {
        const name =
          String(
            req.body.name
          ).trim();

        if (name.length < 2) {
          return res.status(400).json({
            success: false,
            message:
              "Name must contain at least 2 characters.",
          });
        }

        updates.name = name;
      }

      if (
        Object.keys(updates)
          .length === 0
      ) {
        return res.status(400).json({
          success: false,
          message:
            "No profile changes provided.",
        });
      }

      updates.updatedAt =
        new Date().toISOString();

      await db
        .collection("users")
        .doc(req.userId)
        .update(updates);

      const updatedDoc =
        await db
          .collection("users")
          .doc(req.userId)
          .get();

      const updatedUser = {
        id: updatedDoc.id,
        ...updatedDoc.data(),
      };

      return res.json({
        success: true,

        message:
          "Profile updated successfully.",

        user:
          publicUser(
            updatedUser
          ),
      });
    } catch (error) {
      console.error(
        "PROFILE UPDATE ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not update profile.",
      });
    }
  }
);

// ============================================================
// DASHBOARD
// ============================================================

router.get(
  "/dashboard",
  authenticate,
  async (req, res) => {
    return res.json({
      success: true,

      user:
        publicUser(req.user),

      rules: {
        baseMiningRate:
          0.2,

        adBoostPerAd:
          0.1,

        maxDailyAds:
          7,

        maxAdBoost:
          0.7,

        referralMiningBoost:
          0.02,

        newUserReferralReward:
          20,

        inviterReferralReward:
          5,

        dailySocialReward:
          10,

        miningSessionHours:
          24,
      },
    });
  }
);

module.exports = router;
