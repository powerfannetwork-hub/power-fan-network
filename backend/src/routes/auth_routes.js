// ============================================================
// POWER FAN NETWORK
// FILE: backend/src/routes/auth_routes.js
// ============================================================
// Authentication:
//   Custom JWT + bcrypt
//
// Database:
//   Firestore
//
// Firebase Authentication:
//   NOT USED
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
  "CHANGE_THIS_SECRET_IN_PRODUCTION";

const JWT_EXPIRES_IN = "30d";

// ============================================================
// FIRESTORE
// ============================================================

let db;

function getDatabase() {
  if (db) {
    return db;
  }

  try {
    const admin = require("firebase-admin");

    if (!admin.apps.length) {
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

    return db;
  } catch (error) {
    console.error(
      "Firestore initialization error:",
      error.message
    );

    return null;
  }
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
  return String(name || "").trim();
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

  const random = Math.floor(
    100000 + Math.random() * 900000
  );

  return `${prefix || "FAN"}${random}`;
}

async function generateUniqueReferralCode(
  database,
  name
) {
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = generateReferralCode(name);

    const result = await database
      .collection("users")
      .where("referralCode", "==", code)
      .limit(1)
      .get();

    if (result.empty) {
      return code;
    }
  }

  throw new Error(
    "Could not generate a unique referral code."
  );
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

    fanBalance: Number(
      user.fanBalance || 0
    ),

    afamBalance: Number(
      user.afamBalance || 0
    ),

    miningRate: Number(
      user.miningRate || 0.2
    ),

    activeReferrals: Number(
      user.activeReferrals || 0
    ),

    dailyAdsWatched: Number(
      user.dailyAdsWatched || 0
    ),

    adBoost: Number(
      user.adBoost || 0
    ),

    miningActive:
      user.miningActive === true,

    miningStartedAt:
      user.miningStartedAt || null,

    miningEndsAt:
      user.miningEndsAt || null,

    consecutiveCheckIns: Number(
      user.consecutiveCheckIns || 0
    ),

    kyc1Eligible:
      user.kyc1Eligible === true,

    kyc1Verified:
      user.kyc1Verified === true,

    kyc2Eligible:
      user.kyc2Eligible === true,

    kyc2Verified:
      user.kyc2Verified === true,

    kyc3Verified:
      user.kyc3Verified === true,

    createdAt:
      user.createdAt || null,

    updatedAt:
      user.updatedAt || null,
  };
}

function errorMessage(error) {
  if (
    error &&
    typeof error.message === "string"
  ) {
    return error.message;
  }

  return "An unexpected error occurred.";
}

// ============================================================
// REGISTER
// ============================================================

router.post("/register", async (req, res) => {
  try {
    const database = getDatabase();

    if (!database) {
      return res.status(503).json({
        success: false,
        message:
          "Database is not connected.",
      });
    }

    const name = cleanName(
      req.body.name
    );

    const email = cleanEmail(
      req.body.email
    );

    const password = String(
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
      !email.includes("@") ||
      !email.includes(".")
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

    const existingUser = await database
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

    if (!existingUser.empty) {
      return res.status(409).json({
        success: false,
        message:
          "This email is already registered.",
      });
    }

    // --------------------------------------------------------
    // FIND REFERRER
    // --------------------------------------------------------

    let referrerDoc = null;

    if (referralCode) {
      const referrerQuery =
        await database
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

    // --------------------------------------------------------
    // PASSWORD HASH
    // --------------------------------------------------------

    const passwordHash =
      await bcrypt.hash(
        password,
        12
      );

    // --------------------------------------------------------
    // USER DATA
    // --------------------------------------------------------

    const userId =
      generateUserId();

    const newReferralCode =
      await generateUniqueReferralCode(
        database,
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

      // New user receives 20 FAN
      fanBalance:
        referrerDoc ? 20 : 0,

      afamBalance: 0,

      // Base mining rate
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

    await database.runTransaction(
      async (transaction) => {
        const userRef =
          database
            .collection("users")
            .doc(userId);

        // Create new user
        transaction.set(
          userRef,
          newUser
        );

        // ----------------------------------------------------
        // REFERRER REWARD
        // ----------------------------------------------------

        if (referrerDoc) {
          const referrer =
            referrerDoc.data();

          const currentBalance =
            Number(
              referrer.fanBalance || 0
            );

          const currentReferrals =
            Number(
              referrer.activeReferrals ||
                0
            );

          const newReferrals =
            currentReferrals + 1;

          const newMiningRate =
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
                newMiningRate,

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
});

// ============================================================
// LOGIN
// ============================================================

router.post("/login", async (req, res) => {
  try {
    const database = getDatabase();

    if (!database) {
      return res.status(503).json({
        success: false,
        message:
          "Database is not connected.",
      });
    }

    const email = cleanEmail(
      req.body.email
    );

    const password = String(
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

    // --------------------------------------------------------
    // FIND USER
    // --------------------------------------------------------

    const result = await database
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

    if (result.empty) {
      return res.status(401).json({
        success: false,
        message:
          "Incorrect email or password.",
      });
    }

    const document =
      result.docs[0];

    const user = {
      id: document.id,
      ...document.data(),
    };

    // --------------------------------------------------------
    // CHECK PASSWORD
    // --------------------------------------------------------

    const passwordValid =
      await bcrypt.compare(
        password,
        user.passwordHash || ""
      );

    if (!passwordValid) {
      return res.status(401).json({
        success: false,
        message:
          "Incorrect email or password.",
      });
    }

    // --------------------------------------------------------
    // TOKEN
    // --------------------------------------------------------

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
});

// ============================================================
// VERIFY TOKEN / CURRENT USER
// ============================================================

router.get(
  "/me",
  async (req, res) => {
    try {
      const database =
        getDatabase();

      if (!database) {
        return res.status(503).json({
          success: false,
          message:
            "Database is not connected.",
        });
      }

      const authorization =
        req.headers.authorization ||
        "";

      if (
        !authorization.startsWith(
          "Bearer "
        )
      ) {
        return res.status(401).json({
          success: false,
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
          message:
            "Authentication token is required.",
        });
      }

      let decoded;

      try {
        decoded =
          jwt.verify(
            token,
            JWT_SECRET
          );
      } catch (_) {
        return res.status(401).json({
          success: false,
          message:
            "Invalid or expired authentication token.",
        });
      }

      if (!decoded.userId) {
        return res.status(401).json({
          success: false,
          message:
            "Invalid authentication token.",
        });
      }

      const userDoc =
        await database
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

      const user = {
        id: userDoc.id,
        ...userDoc.data(),
      };

      return res.json({
        success: true,
        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "ME ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not load account.",
      });
    }
  }
);

// ============================================================
// CHANGE PASSWORD
// ============================================================

router.post(
  "/change-password",
  async (req, res) => {
    try {
      const database =
        getDatabase();

      if (!database) {
        return res.status(503).json({
          success: false,
          message:
            "Database is not connected.",
        });
      }

      const authorization =
        req.headers.authorization ||
        "";

      if (
        !authorization.startsWith(
          "Bearer "
        )
      ) {
        return res.status(401).json({
          success: false,
          message:
            "Authentication token is required.",
        });
      }

      const token =
        authorization
          .substring(7)
          .trim();

      let decoded;

      try {
        decoded =
          jwt.verify(
            token,
            JWT_SECRET
          );
      } catch (_) {
        return res.status(401).json({
          success: false,
          message:
            "Invalid or expired authentication token.",
        });
      }

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

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message:
            "New password must contain at least 6 characters.",
        });
      }

      const userDoc =
        await database
          .collection("users")
          .doc(decoded.userId)
          .get();

      if (!userDoc.exists) {
        return res.status(404).json({
          success: false,
          message:
            "User account not found.",
        });
      }

      const user = userDoc.data();

      const valid =
        await bcrypt.compare(
          currentPassword,
          user.passwordHash || ""
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

      await database
        .collection("users")
        .doc(decoded.userId)
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
// LOGOUT
// ============================================================

router.post(
  "/logout",
  async (req, res) => {
    // JWT logout is completed by
    // deleting the token from the app.
    //
    // There is no Firebase Auth session here.

    return res.json({
      success: true,
      message:
        "Logged out successfully.",
    });
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = router;
