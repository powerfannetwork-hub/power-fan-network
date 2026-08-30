// ============================================================
// POWER FAN NETWORK
// CUSTOM AUTH ROUTES
// ============================================================
//
// Firebase Authentication: NOT USED
// Authentication: JWT + bcrypt
// Database: Firestore
// ============================================================

const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const { getDb } = require("../firebase");
const { authenticate } = require("../../middleware/auth");

const router = express.Router();

const JWT_SECRET =
  process.env.JWT_SECRET ||
  "CHANGE_THIS_SECRET_IN_PRODUCTION";

const JWT_EXPIRES_IN = "30d";

// ============================================================
// HELPERS
// ============================================================

function cleanEmail(email) {
  return String(email || "")
    .trim()
    .toLowerCase();
}

function cleanName(name) {
  return String(name || "").trim();
}

function generateUserId() {
  return (
    "user_" +
    Date.now() +
    "_" +
    Math.random()
      .toString(36)
      .substring(2, 10)
  );
}

function generateReferralCode(name) {
  const prefix = cleanName(name)
    .replace(/[^a-zA-Z0-9]/g, "")
    .toUpperCase()
    .substring(0, 5);

  const random = Math.floor(
    100000 + Math.random() * 900000
  );

  return `${prefix || "FAN"}${random}`;
}

function createToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
    },
    JWT_SECRET,
    {
      expiresIn: JWT_EXPIRES_IN,
    }
  );
}

function publicUser(user) {
  if (!user) return null;

  return {
    id: user.id,
    name: user.name || "",
    email: user.email || "",

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

function validEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
    email
  );
}

// ============================================================
// REGISTER
// ============================================================

router.post(
  "/register",
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

      const name =
        cleanName(req.body.name);

      const email =
        cleanEmail(req.body.email);

      const password =
        String(req.body.password || "");

      const referralCode =
        String(
          req.body.referralCode || ""
        )
          .trim()
          .toUpperCase();

      // ------------------------------------------------------
      // VALIDATION
      // ------------------------------------------------------

      if (!name || !email || !password) {
        return res.status(400).json({
          success: false,
          message:
            "Name, email and password are required.",
        });
      }

      if (name.length < 2) {
        return res.status(400).json({
          success: false,
          message:
            "Name must contain at least 2 characters.",
        });
      }

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,
          message:
            "Invalid email address.",
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          success: false,
          message:
            "Password must contain at least 6 characters.",
        });
      }

      // ------------------------------------------------------
      // CHECK EMAIL
      // ------------------------------------------------------

      const existing =
        await db
          .collection("users")
          .where("email", "==", email)
          .limit(1)
          .get();

      if (!existing.empty) {
        return res.status(409).json({
          success: false,
          message:
            "This email is already registered.",
        });
      }

      // ------------------------------------------------------
      // REFERRER
      // ------------------------------------------------------

      let referrerDoc = null;

      if (referralCode) {
        const referrerQuery =
          await db
            .collection("users")
            .where(
              "referralCode",
              "==",
              referralCode
            )
            .limit(1)
            .get();

        if (referrerQuery.empty) {
          return res.status(400).json({
            success: false,
            message:
              "Invalid referral code.",
          });
        }

        referrerDoc =
          referrerQuery.docs[0];
      }

      // ------------------------------------------------------
      // PASSWORD HASH
      // ------------------------------------------------------

      const passwordHash =
        await bcrypt.hash(
          password,
          12
        );

      // ------------------------------------------------------
      // USER
      // ------------------------------------------------------

      const userId =
        generateUserId();

      const newReferralCode =
        generateReferralCode(name);

      const now =
        new Date().toISOString();

      const newUser = {
        id: userId,

        name,
        email,

        passwordHash,

        referralCode:
          newReferralCode,

        referredBy:
          referrerDoc
            ? referrerDoc.id
            : null,

        // New user receives 20 FAN
        fanBalance:
          referrerDoc ? 20 : 0,

        afamBalance: 0,

        // Base mining rate
        miningRate: 0.2,

        // Important:
        // Referral is NOT active until
        // the referred user starts mining.
        activeReferrals: 0,

        dailyAdsWatched: 0,

        adBoost: 0,

        miningActive: false,

        miningStartedAt: null,

        miningEndsAt: null,

        // Used to prevent counting
        // same mining session twice.
        referralActiveForSession:
          false,

        consecutiveCheckIns: 0,

        kyc1Eligible: false,
        kyc1Verified: false,

        kyc2Eligible: false,
        kyc2Verified: false,

        kyc3Verified: false,

        createdAt: now,
        updatedAt: now,
      };

      // ------------------------------------------------------
      // TRANSACTION
      // ------------------------------------------------------

      await db.runTransaction(
        async (transaction) => {
          const userRef =
            db
              .collection("users")
              .doc(userId);

          transaction.set(
            userRef,
            newUser
          );

          /*
           * Important:
           *
           * Inviter gets 5 FAN for successful
           * referral.
           *
           * But activeReferrals remains 0
           * until the referred user actually
           * starts mining.
           */

          if (referrerDoc) {
            const referrerData =
              referrerDoc.data();

            const balance =
              Number(
                referrerData.fanBalance ||
                  0
              );

            transaction.update(
              referrerDoc.ref,
              {
                fanBalance:
                  balance + 5,

                updatedAt: now,
              }
            );
          }
        }
      );

      // ------------------------------------------------------
      // TOKEN
      // ------------------------------------------------------

      const token =
        createToken(newUser);

      return res.status(201).json({
        success: true,

        message:
          "Account created successfully.",

        token,

        user:
          publicUser(newUser),
      });
    } catch (error) {
      console.error(
        "REGISTER ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Registration failed.",
      });
    }
  }
);

// ============================================================
// LOGIN
// ============================================================

router.post(
  "/login",
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

      const email =
        cleanEmail(req.body.email);

      const password =
        String(req.body.password || "");

      if (!email || !password) {
        return res.status(400).json({
          success: false,
          message:
            "Email and password are required.",
        });
      }

      const query =
        await db
          .collection("users")
          .where("email", "==", email)
          .limit(1)
          .get();

      if (query.empty) {
        return res.status(401).json({
          success: false,
          message:
            "Incorrect email or password.",
        });
      }

      const doc =
        query.docs[0];

      const user = {
        id: doc.id,
        ...doc.data(),
      };

      const valid =
        await bcrypt.compare(
          password,
          user.passwordHash || ""
        );

      if (!valid) {
        return res.status(401).json({
          success: false,
          message:
            "Incorrect email or password.",
        });
      }

      const token =
        createToken(user);

      return res.json({
        success: true,

        message:
          "Login successful.",

        token,

        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "LOGIN ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Login failed.",
      });
    }
  }
);

// ============================================================
// CURRENT USER
// ============================================================

router.get(
  "/me",
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
// LOGOUT
// ============================================================
//
// JWT logout happens on the client by deleting
// the locally stored token.
// ============================================================

router.post(
  "/logout",
  authenticate,
  async (req, res) => {
    return res.json({
      success: true,
      message:
        "Logged out successfully.",
    });
  }
);

// ============================================================
// CHANGE PASSWORD
// ============================================================

router.post(
  "/change-password",
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

      const currentPassword =
        String(
          req.body.currentPassword ||
            ""
        );

      const newPassword =
        String(
          req.body.newPassword || ""
        );

      if (
        !currentPassword ||
        !newPassword
      ) {
        return res.status(400).json({
          success: false,
          message:
            "Current password and new password are required.",
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message:
            "New password must contain at least 6 characters.",
        });
      }

      const valid =
        await bcrypt.compare(
          currentPassword,
          req.user.passwordHash ||
            ""
        );

      if (!valid) {
        return res.status(401).json({
          success: false,
          message:
            "Current password is incorrect.",
        });
      }

      const passwordHash =
        await bcrypt.hash(
          newPassword,
          12
        );

      await db
        .collection("users")
        .doc(req.userId)
        .update({
          passwordHash,
          updatedAt:
            new Date().toISOString(),
        });

      return res.json({
        success: true,
        message:
          "Password changed successfully.",
      });
    } catch (error) {
      console.error(
        "CHANGE PASSWORD ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not change password.",
      });
    }
  }
);

module.exports = router;
