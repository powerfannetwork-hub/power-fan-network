// ============================================================
// POWER FAN NETWORK
// FILE: backend/src/routes/user_routes.js
// ============================================================
// USER ROUTES
// Database: Firestore
// Firebase Authentication: NOT USED
// ============================================================

const express = require("express");

const router = express.Router();

// ============================================================
// FIRESTORE
// ============================================================

let db = null;

try {
  const admin = require("firebase-admin");

  if (admin.apps.length === 0) {
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const serviceAccount = JSON.parse(
        process.env.FIREBASE_SERVICE_ACCOUNT
      );

      admin.initializeApp({
        credential: admin.credential.cert(
          serviceAccount
        ),
      });
    } else {
      admin.initializeApp();
    }
  }

  db = admin.firestore();

  console.log(
    "USER ROUTES: Firestore initialized."
  );
} catch (error) {
  console.error(
    "USER ROUTES: Firestore initialization failed:",
    error.message
  );
}

// ============================================================
// DATABASE CHECK
// ============================================================

function databaseRequired(res) {
  if (!db) {
    res.status(503).json({
      success: false,
      error: "database_unavailable",
      message: "Database is not connected.",
    });

    return false;
  }

  return true;
}

// ============================================================
// AUTHENTICATION
// ============================================================

async function authenticate(req, res, next) {
  try {
    const jwt = require("jsonwebtoken");

    const JWT_SECRET =
      process.env.JWT_SECRET ||
      "CHANGE_THIS_SECRET_IN_PRODUCTION";

    const authorization =
      req.headers.authorization || "";

    if (
      !authorization.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message:
          "Authentication token is required.",
      });
    }

    const token =
      authorization
        .substring(7)
        .trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message:
          "Authentication token is required.",
      });
    }

    const decoded =
      jwt.verify(
        token,
        JWT_SECRET
      );

    if (!decoded.userId) {
      return res.status(401).json({
        success: false,
        error: "invalid_token",
        message:
          "Invalid authentication token.",
      });
    }

    if (!databaseRequired(res)) {
      return;
    }

    const userDoc =
      await db
        .collection("users")
        .doc(decoded.userId)
        .get();

    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        error: "user_not_found",
        message:
          "User account no longer exists.",
      });
    }

    req.user = {
      id: userDoc.id,
      ...userDoc.data(),
    };

    next();
  } catch (error) {
    console.error(
      "USER AUTH ERROR:",
      error.message
    );

    return res.status(401).json({
      success: false,
      error: "invalid_token",
      message:
        "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// PUBLIC USER OBJECT
// ============================================================

function publicUser(user) {
  return {
    id: user.id || "",

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
      Number(user.activeReferrals || 0),

    dailyAdsWatched:
      Number(user.dailyAdsWatched || 0),

    adBoost:
      Number(user.adBoost || 0),

    miningActive:
      Boolean(user.miningActive),

    miningStartedAt:
      user.miningStartedAt || null,

    miningEndsAt:
      user.miningEndsAt || null,

    consecutiveCheckIns:
      Number(
        user.consecutiveCheckIns || 0
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
// GET PROFILE
// ============================================================

router.get(
  "/profile",
  authenticate,
  async (req, res) => {
    try {
      if (!databaseRequired(res)) {
        return;
      }

      return res.json({
        success: true,

        user:
          publicUser(req.user),
      });
    } catch (error) {
      console.error(
        "GET PROFILE ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not load profile.",
      });
    }
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
      if (!databaseRequired(res)) {
        return;
      }

      const updates = {};

      // --------------------------------------------------------
      // NAME
      // --------------------------------------------------------

      if (
        req.body.name !== undefined
      ) {
        const name =
          String(
            req.body.name || ""
          ).trim();

        if (name.length < 2) {
          return res.status(400).json({
            success: false,
            error: "invalid_name",
            message:
              "Name must contain at least 2 characters.",
          });
        }

        if (name.length > 100) {
          return res.status(400).json({
            success: false,
            error: "invalid_name",
            message:
              "Name is too long.",
          });
        }

        updates.name = name;
      }

      // --------------------------------------------------------
      // NO CHANGES
      // --------------------------------------------------------

      if (
        Object.keys(updates).length === 0
      ) {
        return res.status(400).json({
          success: false,
          error: "no_changes",
          message:
            "No profile changes provided.",
        });
      }

      updates.updatedAt =
        new Date().toISOString();

      await db
        .collection("users")
        .doc(req.user.id)
        .update(updates);

      const updatedDoc =
        await db
          .collection("users")
          .doc(req.user.id)
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
          publicUser(updatedUser),
      });
    } catch (error) {
      console.error(
        "UPDATE PROFILE ERROR:",
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
// GET USER BALANCES
// ============================================================

router.get(
  "/balance",
  authenticate,
  async (req, res) => {
    try {
      return res.json({
        success: true,

        fanBalance:
          Number(
            req.user.fanBalance || 0
          ),

        afamBalance:
          Number(
            req.user.afamBalance || 0
          ),

        miningRate:
          Number(
            req.user.miningRate || 0.2
          ),
      });
    } catch (error) {
      console.error(
        "BALANCE ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not load balance.",
      });
    }
  }
);

// ============================================================
// GET DASHBOARD DATA
// ============================================================

router.get(
  "/dashboard",
  authenticate,
  async (req, res) => {
    try {
      return res.json({
        success: true,

        user:
          publicUser(req.user),

        rules: {
          baseMiningRate: 0.2,

          adBoostPerAd: 0.1,

          maxDailyAds: 7,

          maxAdBoost: 0.7,

          referralMiningBoost: 0.02,

          newUserReferralReward: 20,

          inviterReferralReward: 5,

          dailySocialReward: 10,
        },
      });
    } catch (error) {
      console.error(
        "DASHBOARD ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not load dashboard.",
      });
    }
  }
);

// ============================================================
// GET REFERRAL CODE
// ============================================================

router.get(
  "/referral-code",
  authenticate,
  async (req, res) => {
    try {
      return res.json({
        success: true,

        referralCode:
          req.user.referralCode || "",

        activeReferrals:
          Number(
            req.user.activeReferrals || 0
          ),

        miningRate:
          Number(
            req.user.miningRate || 0.2
          ),
      });
    } catch (error) {
      console.error(
        "REFERRAL CODE ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not load referral code.",
      });
    }
  }
);

// ============================================================
// DELETE ACCOUNT
// ============================================================
// NOTE:
// This permanently removes the user's Firestore account.
// Firebase Authentication is NOT involved.
// ============================================================

router.delete(
  "/account",
  authenticate,
  async (req, res) => {
    try {
      if (!databaseRequired(res)) {
        return;
      }

      const userRef =
        db
          .collection("users")
          .doc(req.user.id);

      const userDoc =
        await userRef.get();

      if (!userDoc.exists) {
        return res.status(404).json({
          success: false,
          message:
            "User account not found.",
        });
      }

      await userRef.delete();

      return res.json({
        success: true,

        message:
          "Account deleted successfully.",
      });
    } catch (error) {
      console.error(
        "DELETE ACCOUNT ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not delete account.",
      });
    }
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  router,
  authenticate,
};
