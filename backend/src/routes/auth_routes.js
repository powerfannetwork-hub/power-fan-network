// ============================================================
// POWER FAN NETWORK
// AUTH ROUTES
// ============================================================
// Firebase Authentication: NOT USED
// Authentication: Custom JWT + bcrypt
// Database: Firestore
// ============================================================

const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const router = express.Router();

// ============================================================
// CONFIG
// ============================================================

const JWT_SECRET =
  process.env.JWT_SECRET ||
  "POWER_FAN_NETWORK_CHANGE_THIS_SECRET";

const JWT_EXPIRES_IN =
  process.env.JWT_EXPIRES_IN || "30d";

// ============================================================
// FIRESTORE
// ============================================================

const admin = require("firebase-admin");

function getDb() {
  if (admin.apps.length === 0) {
    return null;
  }

  return admin.firestore();
}

// ============================================================
// HELPERS
// ============================================================

function cleanEmail(email) {
  return String(email || "")
    .trim()
    .toLowerCase();
}

function cleanName(name) {
  return String(name || "")
    .trim();
}

function cleanReferralCode(code) {
  return String(code || "")
    .trim()
    .toUpperCase();
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

  const random =
    Math.floor(
      100000 +
        Math.random() * 900000
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

function databaseUnavailable(res) {
  const db = getDb();

  if (!db) {
    res.status(503).json({
      success: false,

      message:
        "Firestore database is not connected.",
    });

    return true;
  }

  return false;
}

// ============================================================
// AUTHENTICATE TOKEN
// ============================================================

async function authenticate(
  req,
  res,
  next
) {
  try {
    const header =
      req.headers.authorization || "";

    if (!header.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,

        message:
          "Authentication token is required.",
      });
    }

    const token =
      header.substring(7).trim();

    if (!token) {
      return res.status(401).json({
        success: false,

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

        message:
          "Invalid authentication token.",
      });
    }

    const db = getDb();

    if (!db) {
      return res.status(503).json({
        success: false,

        message:
          "Firestore database is not connected.",
      });
    }

    const userDoc =
      await db
        .collection("users")
        .doc(decoded.userId)
        .get();

    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,

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
      "AUTHENTICATION ERROR:",
      error.message
    );

    return res.status(401).json({
      success: false,

      message:
        "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// REGISTER
// ============================================================

router.post(
  "/register",
  async (req, res) => {
    try {
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

      const name =
        cleanName(req.body.name);

      const email =
        cleanEmail(req.body.email);

      const password =
        String(
          req.body.password || ""
        );

      const referralCode =
        cleanReferralCode(
          req.body.referralCode
        );

      // --------------------------------------------------------
      // VALIDATION
      // --------------------------------------------------------

      if (
        !name ||
        !email ||
        !password
      ) {
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

      if (password.length < 6) {
        return res.status(400).json({
          success: false,

          message:
            "Password must contain at least 6 characters.",
        });
      }

      if (
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
          email
        )
      ) {
        return res.status(400).json({
          success: false,

          message:
            "Invalid email address.",
        });
      }

      // --------------------------------------------------------
      // CHECK EMAIL
      // --------------------------------------------------------

      const existing =
        await db
          .collection("users")
          .where(
            "email",
            "==",
            email
          )
          .limit(1)
          .get();

      if (!existing.empty) {
        return res.status(409).json({
          success: false,

          message:
            "This email is already registered.",
        });
      }

      // --------------------------------------------------------
      // REFERRER
      // --------------------------------------------------------

      let referrerDoc = null;

      if (referralCode) {
        const referralQuery =
          await db
            .collection("users")
            .where(
              "referralCode",
              "==",
              referralCode
            )
            .limit(1)
            .get();

        if (referralQuery.empty) {
          return res.status(400).json({
            success: false,

            message:
              "Invalid referral code.",
          });
        }

        referrerDoc =
          referralQuery.docs[0];
      }

      // --------------------------------------------------------
      // PASSWORD HASH
      // --------------------------------------------------------

      const passwordHash =
        await bcrypt.hash(
          password,
          12
        );

      // --------------------------------------------------------
      // USER
      // --------------------------------------------------------

      const userId =
        generateUserId();

      const newReferralCode =
        generateReferralCode(
          name
        );

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

        // New referral user receives 20 FAN
        fanBalance:
          referrerDoc ? 20 : 0,

        afamBalance: 0,

        // Base rate
        miningRate: 0.2,

        activeReferrals: 0,

        dailyAdsWatched: 0,

        adBoost: 0,

        miningActive: false,

        miningStartedAt: null,

        miningEndsAt: null,

        consecutiveCheckIns: 0,

        kyc1Eligible: false,

        kyc1Verified: false,

        kyc2Eligible: false,

        kyc2Verified: false,

        kyc3Verified: false,

        createdAt: now,

        updatedAt: now,
      };

      // --------------------------------------------------------
      // TRANSACTION
      // --------------------------------------------------------

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

          if (referrerDoc) {
            const referrerData =
              referrerDoc.data();

            const currentBalance =
              Number(
                referrerData.fanBalance ||
                  0
              );

            const currentReferrals =
              Number(
                referrerData.activeReferrals ||
                  0
              );

            const newReferrals =
              currentReferrals + 1;

            const newRate =
              0.2 +
              newReferrals * 0.02;

            transaction.update(
              referrerDoc.ref,
              {
                fanBalance:
                  currentBalance + 5,

                activeReferrals:
                  newReferrals,

                miningRate:
                  newRate,

                updatedAt: now,
              }
            );
          }
        }
      );

      // --------------------------------------------------------
      // TOKEN
      // --------------------------------------------------------

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
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

      const email =
        cleanEmail(req.body.email);

      const password =
        String(
          req.body.password || ""
        );

      if (
        !email ||
        !password
      ) {
        return res.status(400).json({
          success: false,

          message:
            "Email and password are required.",
        });
      }

      const query =
        await db
          .collection("users")
          .where(
            "email",
            "==",
            email
          )
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

      const validPassword =
        await bcrypt.compare(
          password,
          user.passwordHash || ""
        );

      if (!validPassword) {
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
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

      const currentPassword =
        String(
          req.body.currentPassword ||
            ""
        );

      const newPassword =
        String(
          req.body.newPassword ||
            ""
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

      if (
        newPassword.length < 6
      ) {
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
        .doc(req.user.id)
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

// ============================================================
// PROFILE
// ============================================================

router.put(
  "/profile",
  authenticate,
  async (req, res) => {
    try {
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

      const updates = {};

      if (
        req.body.name !== undefined
      ) {
        const name =
          cleanName(
            req.body.name
          );

        if (name.length < 2) {
          return res.status(400).json({
            success: false,

            message:
              "Name is too short.",
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
        "PROFILE ERROR:",
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
  }
);

// ============================================================
// MINING START
// ============================================================

router.post(
  "/mining/start",
  authenticate,
  async (req, res) => {
    try {
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

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
            "User not found.",
        });
      }

      const user =
        userDoc.data();

      if (user.miningActive) {
        return res.status(400).json({
          success: false,

          message:
            "Mining is already active.",
        });
      }

      const now =
        new Date();

      const endsAt =
        new Date(
          now.getTime() +
            24 *
              60 *
              60 *
              1000
        );

      await userRef.update({
        miningActive: true,

        miningStartedAt:
          now.toISOString(),

        miningEndsAt:
          endsAt.toISOString(),

        updatedAt:
          now.toISOString(),
      });

      return res.json({
        success: true,

        message:
          "Mining started.",

        mining: {
          active: true,

          startedAt:
            now.toISOString(),

          endsAt:
            endsAt.toISOString(),

          miningRate:
            Number(
              user.miningRate ||
                0.2
            ),
        },
      });
    } catch (error) {
      console.error(
        "MINING START ERROR:",
        error
      );

      return res.status(500).json({
        success: false,

        message:
          "Could not start mining.",
      });
    }
  }
);

// ============================================================
// MINING CLAIM
// ============================================================

router.post(
  "/mining/claim",
  authenticate,
  async (req, res) => {
    try {
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

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
            "User not found.",
        });
      }

      const user =
        userDoc.data();

      if (!user.miningActive) {
        return res.status(400).json({
          success: false,

          message:
            "Mining session is not active.",
        });
      }

      if (!user.miningEndsAt) {
        return res.status(400).json({
          success: false,

          message:
            "Mining end time is missing.",
        });
      }

      const now =
        new Date();

      const endsAt =
        new Date(
          user.miningEndsAt
        );

      if (now < endsAt) {
        return res.status(400).json({
          success: false,

          message:
            "Mining session has not ended yet.",

          endsAt:
            endsAt.toISOString(),
        });
      }

      const miningRate =
        Number(
          user.miningRate ||
            0.2
        );

      const reward =
        miningRate * 24;

      const currentBalance =
        Number(
          user.fanBalance || 0
        );

      const newBalance =
        currentBalance + reward;

      await userRef.update({
        fanBalance:
          newBalance,

        miningActive: false,

        miningStartedAt: null,

        miningEndsAt: null,

        dailyAdsWatched: 0,

        adBoost: 0,

        miningRate:
          0.2 +
          Number(
            user.activeReferrals ||
              0
          ) *
            0.02,

        updatedAt:
          now.toISOString(),
      });

      return res.json({
        success: true,

        message:
          "Mining reward claimed.",

        reward,

        fanBalance:
          newBalance,

        miningActive: false,
      });
    } catch (error) {
      console.error(
        "MINING CLAIM ERROR:",
        error
      );

      return res.status(500).json({
        success: false,

        message:
          "Could not claim mining reward.",
      });
    }
  }
);

// ============================================================
// REWARDED AD
// ============================================================

router.post(
  "/mining/ad",
  authenticate,
  async (req, res) => {
    try {
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

      const userRef =
        db
          .collection("users")
          .doc(req.user.id);

      const userDoc =
        await userRef.get();

      const user =
        userDoc.data();

      const adsWatched =
        Number(
          user.dailyAdsWatched ||
            0
        );

      if (adsWatched >= 7) {
        return res.status(400).json({
          success: false,

          message:
            "You have reached the maximum of 7 rewarded ads today.",
        });
      }

      const newAds =
        adsWatched + 1;

      const newAdBoost =
        newAds * 0.1;

      const referralBoost =
        Number(
          user.activeReferrals ||
            0
        ) * 0.02;

      const newRate =
        0.2 +
        referralBoost +
        newAdBoost;

      await userRef.update({
        dailyAdsWatched:
          newAds,

        adBoost:
          newAdBoost,

        miningRate:
          newRate,

        updatedAt:
          new Date().toISOString(),
      });

      return res.json({
        success: true,

        message:
          "Ad reward applied.",

        adsWatched:
          newAds,

        adBoost:
          newAdBoost,

        miningRate:
          newRate,
      });
    } catch (error) {
      console.error(
        "AD ERROR:",
        error
      );

      return res.status(500).json({
        success: false,

        message:
          "Could not apply ad reward.",
      });
    }
  }
);

// ============================================================
// REFERRALS
// ============================================================

router.get(
  "/referrals",
  authenticate,
  async (req, res) => {
    try {
      if (databaseUnavailable(res)) {
        return;
      }

      const db = getDb();

      const referrals =
        await db
          .collection("users")
          .where(
            "referredBy",
            "==",
            req.user.id
          )
          .get();

      const list =
        referrals.docs.map(
          (doc) => {
            const data =
              doc.data();

            return {
              id: doc.id,

              name:
                data.name || "",

              email:
                data.email || "",

              createdAt:
                data.createdAt ||
                null,

              miningActive:
                Boolean(
                  data.miningActive
                ),
            };
          }
        );

      return res.json({
        success: true,

        referralCode:
          req.user.referralCode ||
          "",

        activeReferrals:
          Number(
            req.user.activeReferrals ||
              0
          ),

        miningRate:
          Number(
            req.user.miningRate ||
              0.2
          ),

        referrals:
          list,
      });
    } catch (error) {
      console.error(
        "REFERRALS ERROR:",
        error
      );

      return res.status(500).json({
        success: false,

        message:
          "Could not load referrals.",
      });
    }
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
