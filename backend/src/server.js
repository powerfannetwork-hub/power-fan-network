// ============================================================
// POWER FAN NETWORK — PRODUCTION BACKEND
// FILE: src/server.js
// ============================================================

const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");
const crypto = require("crypto");

const app = express();

const PORT = Number(process.env.PORT || 3000);

// ============================================================
// FIREBASE CONFIG
// ============================================================

const projectId = process.env.FIREBASE_PROJECT_ID;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
const privateKey = process.env.FIREBASE_PRIVATE_KEY;
const firebaseWebApiKey = process.env.FIREBASE_WEB_API_KEY;

if (!projectId || !clientEmail || !privateKey) {
  console.error("Missing Firebase environment variables.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert({
    projectId,
    clientEmail,
    privateKey: privateKey.replace(/\\n/g, "\n"),
  }),
  databaseURL:
      `https://${projectId}-default-rtdb.firebaseio.com`,
});

const db = admin.database();
const auth = admin.auth();

// ============================================================
// CONFIGURATION
// ============================================================

const CONFIG = {
  appName: "POWER FAN NETWORK",
  version: "1.0.0",

  miningCoin: "FAN",
  originalCoin: "AFAM",

  baseMiningRate: 0.2,

  adBoostPerAd: 0.1,
  maximumDailyAds: 7,
  maximumAdBoost: 0.7,

  activeReferralMiningBonus: 0.02,

  maximumMiningRate: 0.9,

  miningSessionHours: 24,

  newUserReferralReward: 20,
  inviterReferralReward: 5,

  dailySocialReward: 10,

  maximumNameLength: 80,
  maximumEmailLength: 254,
};

// ============================================================
// MIDDLEWARE
// ============================================================

app.disable("x-powered-by");

app.use(
  cors({
    origin: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
    ],
  }),
);

app.use(
  express.json({
    limit: "1mb",
  }),
);

// ============================================================
// HELPERS
// ============================================================

function now() {
  return Date.now();
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function cleanString(value) {
  return String(value || "").trim();
}

function normalizeEmail(value) {
  return cleanString(value).toLowerCase();
}

function validEmail(email) {
  return (
    email.length > 3 &&
    email.length <= CONFIG.maximumEmailLength &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  );
}

function generateReferralCode() {
  return crypto
    .randomBytes(5)
    .toString("hex")
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
      safeNumber(user.activeReferralCount),
    ),
  );

  const adBoost = Math.min(
    CONFIG.maximumAdBoost,
    Math.max(
      0,
      safeNumber(user.dailyAdBoost),
    ),
  );

  const referralBoost =
    referrals *
    CONFIG.activeReferralMiningBonus;

  const total =
    CONFIG.baseMiningRate +
    referralBoost +
    adBoost;

  return Math.min(
    Number(total.toFixed(4)),
    CONFIG.maximumMiningRate,
  );
}

function publicUser(user) {
  if (!user) return null;

  return {
    uid: user.uid,
    name: user.name || "",
    email: user.email || "",

    fanBalance: safeNumber(user.fanBalance),
    afamBalance: safeNumber(user.afamBalance),

    miningRate: safeNumber(
      user.miningRate,
      CONFIG.baseMiningRate,
    ),

    dailyAdCount: safeNumber(user.dailyAdCount),
    dailyAdBoost: safeNumber(user.dailyAdBoost),

    activeReferralCount:
      safeNumber(user.activeReferralCount),

    referralCode: user.referralCode || "",

    miningActive:
      user.miningActive === true,

    miningStartedAt:
      user.miningStartedAt || null,

    miningEndsAt:
      user.miningEndsAt || null,

    createdAt:
      user.createdAt || null,

    updatedAt:
      user.updatedAt || null,
  };
}

async function getUser(uid) {
  const snapshot =
    await db.ref(`users/${uid}`).once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

// ============================================================
// AUTHENTICATION
// ============================================================

async function authenticate(req, res, next) {
  try {
    const header =
      req.headers.authorization;

    if (
      !header ||
      !header.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
        message:
          "Firebase ID token is required.",
      });
    }

    const token =
      header.substring(7).trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
      });
    }

    const decodedToken =
      await auth.verifyIdToken(token);

    req.user = decodedToken;

    next();
  } catch (error) {
    console.error(
      "Authentication error:",
      error.message,
    );

    return res.status(401).json({
      success: false,
      error: "invalid_authentication",
      message:
        "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// ROOT / HEALTH
// ============================================================

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: CONFIG.appName,
    version: CONFIG.version,
    status: "running",
  });
});

app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "ok",
    service: "POWER FAN NETWORK Backend",
    firebase: true,
    time: new Date().toISOString(),
  });
});

app.get("/api/status", (req, res) => {
  res.json({
    success: true,
    app: CONFIG.appName,
    backend: true,
    database: "Firebase Realtime Database",
    authentication: "Firebase Authentication",
    status: "online",
    time: new Date().toISOString(),
  });
});

// ============================================================
// AUTH — REGISTER
// ============================================================

app.post("/api/auth/register", async (req, res) => {
  try {
    const name =
      cleanString(req.body.name);

    const email =
      normalizeEmail(req.body.email);

    const password =
      String(req.body.password || "");

    if (!name) {
      return res.status(400).json({
        success: false,
        error: "name_required",
        message: "Name is required.",
      });
    }

    if (
      name.length >
      CONFIG.maximumNameLength
    ) {
      return res.status(400).json({
        success: false,
        error: "name_too_long",
      });
    }

    if (!validEmail(email)) {
      return res.status(400).json({
        success: false,
        error: "invalid_email",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        error: "weak_password",
        message:
          "Password must contain at least 6 characters.",
      });
    }

    if (!firebaseWebApiKey) {
      return res.status(500).json({
        success: false,
        error: "firebase_web_api_key_missing",
      });
    }

    // Create Firebase Authentication account.
    const userRecord =
      await auth.createUser({
        email,
        password,
        displayName: name,
        emailVerified: false,
      });

    const uid = userRecord.uid;

    // Generate unique referral code.
    let referralCode;

    for (let attempt = 0; attempt < 10; attempt++) {
      const candidate =
        generateReferralCode();

      const existing =
        await db
          .ref(`referralCodes/${candidate}`)
          .once("value");

      if (!existing.exists()) {
        referralCode = candidate;
        break;
      }
    }

    if (!referralCode) {
      await auth.deleteUser(uid);

      return res.status(500).json({
        success: false,
        error: "referral_code_generation_failed",
      });
    }

    const timestamp = now();

    const user = {
      uid,
      name,
      email,

      fanBalance: 0,
      afamBalance: 0,

      miningRate:
        CONFIG.baseMiningRate,

      dailyAdCount: 0,
      dailyAdBoost: 0,
      dailyAdDate: todayKey(),

      activeReferralCount: 0,

      referralCode,

      referrerUid: null,

      miningActive: false,
      miningStartedAt: null,
      miningEndsAt: null,

      createdAt: timestamp,
      updatedAt: timestamp,
    };

    await db.ref().update({
      [`users/${uid}`]: user,
      [`referralCodes/${referralCode}`]: uid,
    });

    // Get Firebase custom token.
    const customToken =
      await auth.createCustomToken(uid);

    return res.status(201).json({
      success: true,
      message: "Account created successfully.",

      token: customToken,

      user: publicUser(user),
    });
  } catch (error) {
    console.error(
      "Register error:",
      error,
    );

    if (
      error.code ===
      "auth/email-already-exists"
    ) {
      return res.status(409).json({
        success: false,
        error: "email_already_in_use",
        message:
          "This email is already registered.",
      });
    }

    return res.status(500).json({
      success: false,
      error: "registration_failed",
      message:
        error.message || "Registration failed.",
    });
  }
});

// ============================================================
// AUTH — LOGIN
// ============================================================

app.post("/api/auth/login", async (req, res) => {
  try {
    const email =
      normalizeEmail(req.body.email);

    const password =
      String(req.body.password || "");

    if (!validEmail(email)) {
      return res.status(400).json({
        success: false,
        error: "invalid_email",
      });
    }

    if (!password) {
      return res.status(400).json({
        success: false,
        error: "password_required",
      });
    }

    if (!firebaseWebApiKey) {
      return res.status(500).json({
        success: false,
        error: "firebase_web_api_key_missing",
      });
    }

    // Firebase Authentication REST API.
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseWebApiKey}`,
      {
        method: "POST",

        headers: {
          "Content-Type": "application/json",
        },

        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true,
        }),
      },
    );

    const data =
      await response.json();

    if (!response.ok) {
      return res.status(401).json({
        success: false,
        error: "invalid_credentials",
        message:
          "Incorrect email or password.",
      });
    }

    const uid = data.localId;

    let user =
      await getUser(uid);

    // Repair/create database profile
    // if Authentication exists but profile is missing.
    if (!user) {
      let referralCode;

      for (let attempt = 0; attempt < 10; attempt++) {
        const candidate =
          generateReferralCode();

        const existing =
          await db
            .ref(`referralCodes/${candidate}`)
            .once("value");

        if (!existing.exists()) {
          referralCode = candidate;
          break;
        }
      }

      const timestamp = now();

      user = {
        uid,

        name: data.displayName || "",

        email,

        fanBalance: 0,
        afamBalance: 0,

        miningRate:
          CONFIG.baseMiningRate,

        dailyAdCount: 0,
        dailyAdBoost: 0,
        dailyAdDate: todayKey(),

        activeReferralCount: 0,

        referralCode,

        referrerUid: null,

        miningActive: false,
        miningStartedAt: null,
        miningEndsAt: null,

        createdAt: timestamp,
        updatedAt: timestamp,
      };

      await db.ref().update({
        [`users/${uid}`]: user,
        [`referralCodes/${referralCode}`]: uid,
      });
    }

    return res.json({
      success: true,
      message: "Login successful.",

      // ID token is used by API requests.
      token: data.idToken,

      refreshToken:
        data.refreshToken || "",

      expiresIn:
        data.expiresIn || "3600",

      user: publicUser(user),
    });
  } catch (error) {
    console.error(
      "Login error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error: "login_failed",
      message:
        error.message || "Login failed.",
    });
  }
});

// ============================================================
// AUTH — FORGOT PASSWORD
// ============================================================

app.post(
  "/api/auth/forgot-password",
  async (req, res) => {
    try {
      const email =
        normalizeEmail(req.body.email);

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,
          error: "invalid_email",
        });
      }

      if (!firebaseWebApiKey) {
        return res.status(500).json({
          success: false,
          error:
            "firebase_web_api_key_missing",
        });
      }

      const response = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${firebaseWebApiKey}`,
        {
          method: "POST",

          headers: {
            "Content-Type": "application/json",
          },

          body: JSON.stringify({
            requestType: "PASSWORD_RESET",
            email,
          }),
        },
      );

      const data =
        await response.json();

      if (!response.ok) {
        return res.status(400).json({
          success: false,
          error: "password_reset_failed",
          message:
            "Unable to send password reset email.",
        });
      }

      return res.json({
        success: true,
        message:
          "Password reset email sent.",
      });
    } catch (error) {
      console.error(
        "Forgot password error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// AUTH — CURRENT USER
// ============================================================

app.get(
  "/api/auth/me",
  authenticate,
  async (req, res) => {
    try {
      const user =
        await getUser(req.user.uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      return res.json({
        success: true,
        user: publicUser(user),
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// USER BOOTSTRAP
// ============================================================

app.post(
  "/api/user/bootstrap",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      let user =
        await getUser(uid);

      if (!user) {
        let referralCode;

        for (let attempt = 0; attempt < 10; attempt++) {
          const candidate =
            generateReferralCode();

          const existing =
            await db
              .ref(`referralCodes/${candidate}`)
              .once("value");

          if (!existing.exists()) {
            referralCode = candidate;
            break;
          }
        }

        if (!referralCode) {
          return res.status(500).json({
            success: false,
            error:
              "referral_code_generation_failed",
          });
        }

        const timestamp = now();

        user = {
          uid,

          name:
            req.user.name ||
            req.user.email ||
            "",

          email:
            req.user.email || "",

          fanBalance: 0,
          afamBalance: 0,

          miningRate:
            CONFIG.baseMiningRate,

          dailyAdCount: 0,
          dailyAdBoost: 0,
          dailyAdDate: todayKey(),

          activeReferralCount: 0,

          referralCode,

          referrerUid: null,

          miningActive: false,
          miningStartedAt: null,
          miningEndsAt: null,

          createdAt: timestamp,
          updatedAt: timestamp,
        };

        await db.ref().update({
          [`users/${uid}`]: user,
          [`referralCodes/${referralCode}`]: uid,
        });
      }

      return res.json({
        success: true,
        user: publicUser(user),
      });
    } catch (error) {
      console.error(
        "Bootstrap error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// USER PROFILE
// ============================================================

app.get(
  "/api/user/profile",
  authenticate,
  async (req, res) => {
    try {
      const user =
        await getUser(req.user.uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      return res.json({
        success: true,
        user: publicUser(user),
      });
    } catch (error) {
      console.error(
        "Profile error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// CONFIG — MINING
// ============================================================

app.get(
  "/api/mining/config",
  (req, res) => {
    res.json({
      success: true,

      coin: CONFIG.miningCoin,

      baseMiningRate:
        CONFIG.baseMiningRate,

      adBoostPerAd:
        CONFIG.adBoostPerAd,

      maximumDailyAds:
        CONFIG.maximumDailyAds,

      maximumAdBoost:
        CONFIG.maximumAdBoost,

      activeReferralMiningBonus:
        CONFIG.activeReferralMiningBonus,

      maximumMiningRate:
        CONFIG.maximumMiningRate,

      miningSessionHours:
        CONFIG.miningSessionHours,
    });
  },
);

// ============================================================
// CONFIG — REFERRAL
// ============================================================

app.get(
  "/api/referral/config",
  (req, res) => {
    res.json({
      success: true,

      newUserReward:
        CONFIG.newUserReferralReward,

      inviterReward:
        CONFIG.inviterReferralReward,

      miningRatePerActiveReferral:
        CONFIG.activeReferralMiningBonus,
    });
  },
);

// ============================================================
// CONFIG — SOCIAL
// ============================================================

app.get(
  "/api/social/config",
  (req, res) => {
    res.json({
      success: true,

      dailyReward:
        CONFIG.dailySocialReward,

      coin: CONFIG.miningCoin,
    });
  },
);

// ============================================================
// ADS — CLAIM BOOST
// ============================================================

app.post(
  "/api/ads/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      let newCount = 0;
      let newBoost = 0;

      const result =
        await userRef.transaction((user) => {
          if (!user) {
            return user;
          }

          const date =
            todayKey();

          if (
            user.dailyAdDate !== date
          ) {
            user.dailyAdDate = date;
            user.dailyAdCount = 0;
            user.dailyAdBoost = 0;
          }

          const count =
            safeNumber(
              user.dailyAdCount,
            );

          if (
            count >=
            CONFIG.maximumDailyAds
          ) {
            return;
          }

          const nextCount =
            count + 1;

          const nextBoost =
            Math.min(
              CONFIG.maximumAdBoost,
              nextCount *
                CONFIG.adBoostPerAd,
            );

          user.dailyAdCount =
            nextCount;

          user.dailyAdBoost =
            Number(
              nextBoost.toFixed(4),
            );

          user.miningRate =
            calculateMiningRate(user);

          user.updatedAt =
            now();

          newCount =
            nextCount;

          newBoost =
            nextBoost;

          return user;
        });

      if (!result.committed) {
        const user =
          await getUser(uid);

        if (
          user &&
          safeNumber(
            user.dailyAdCount,
          ) >=
            CONFIG.maximumDailyAds
        ) {
          return res.status(400).json({
            success: false,
            error:
              "daily_ad_limit_reached",
            dailyAdCount:
              user.dailyAdCount,
            dailyAdBoost:
              user.dailyAdBoost,
          });
        }

        return res.status(400).json({
          success: false,
          error: "ad_claim_failed",
        });
      }

      return res.json({
        success: true,
        message:
          "Mining boost added.",

        dailyAdCount:
          newCount,

        dailyAdBoost:
          Number(
            newBoost.toFixed(4),
          ),

        miningRate:
          calculateMiningRate(
            result.snapshot.val(),
          ),
      });
    } catch (error) {
      console.error(
        "Ad claim error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// MINING — START
// ============================================================

app.post(
  "/api/mining/start",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      const snapshot =
        await userRef.once("value");

      if (!snapshot.exists()) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      const user =
        snapshot.val();

      if (user.miningActive === true) {
        return res.status(400).json({
          success: false,
          error:
            "mining_already_active",
          miningEndsAt:
            user.miningEndsAt,
        });
      }

      const timestamp =
        now();

      const endsAt =
        timestamp +
        CONFIG.miningSessionHours *
          60 *
          60 *
          1000;

      const rate =
        calculateMiningRate(user);

      await userRef.update({
        miningActive: true,

        miningStartedAt:
          timestamp,

        miningEndsAt:
          endsAt,

        miningRate:
          rate,

        updatedAt:
          timestamp,
      });

      return res.json({
        success: true,

        message:
          "Mining session started.",

        coin:
          CONFIG.miningCoin,

        miningRate:
          rate,

        miningStartedAt:
          timestamp,

        miningEndsAt:
          endsAt,
      });
    } catch (error) {
      console.error(
        "Mining start error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// MINING — STATUS
// ============================================================

app.get(
  "/api/mining/status",
  authenticate,
  async (req, res) => {
    try {
      const user =
        await getUser(req.user.uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      const active =
        user.miningActive === true;

      const endsAt =
        safeNumber(
          user.miningEndsAt,
        );

      const remaining =
        active
          ? Math.max(
              0,
              endsAt - now(),
            )
          : 0;

      return res.json({
        success: true,

        miningActive:
          active,

        miningRate:
          calculateMiningRate(user),

        miningStartedAt:
          user.miningStartedAt ||
          null,

        miningEndsAt:
          user.miningEndsAt ||
          null,

        remainingMilliseconds:
          remaining,

        fanBalance:
          safeNumber(
            user.fanBalance,
          ),
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// MINING — CLAIM
// ============================================================

app.post(
  "/api/mining/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      let earnedAmount = 0;

      const result =
        await userRef.transaction((user) => {
          if (!user) {
            return user;
          }

          if (
            user.miningActive !== true
          ) {
            return;
          }

          const currentTime =
            now();

          const endsAt =
            safeNumber(
              user.miningEndsAt,
            );

          if (
            currentTime <
            endsAt
          ) {
            return;
          }

          const startedAt =
            safeNumber(
              user.miningStartedAt,
              currentTime,
            );

          const elapsedHours =
            Math.min(
              CONFIG.miningSessionHours,
              Math.max(
                0,
                (endsAt -
                  startedAt) /
                  (60 *
                    60 *
                    1000),
              ),
            );

          const rate =
            calculateMiningRate(user);

          earnedAmount =
            Number(
              (
                rate *
                elapsedHours
              ).toFixed(8),
            );

          user.fanBalance =
            Number(
              user.fanBalance || 0,
            ) +
            earnedAmount;

          user.miningActive =
            false;

          user.miningStartedAt =
            null;

          user.miningEndsAt =
            null;

          user.miningRate =
            rate;

          user.updatedAt =
            currentTime;

          return user;
        });

      if (!result.committed) {
        const user =
          await getUser(uid);

        if (!user) {
          return res.status(404).json({
            success: false,
            error: "user_not_found",
          });
        }

        if (
          user.miningActive === true
        ) {
          return res.status(400).json({
            success: false,
            error:
              "mining_not_finished",
            miningEndsAt:
              user.miningEndsAt,
          });
        }

        return res.status(400).json({
          success: false,
          error: "nothing_to_claim",
        });
      }

      const finalUser =
        result.snapshot.val();

      return res.json({
        success: true,

        earned:
          earnedAmount,

        coin:
          CONFIG.miningCoin,

        fanBalance:
          safeNumber(
            finalUser.fanBalance,
          ),

        miningActive:
          false,
      });
    } catch (error) {
      console.error(
        "Mining claim error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// REFERRAL — APPLY
// ============================================================

app.post(
  "/api/referral/apply",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const code =
        cleanString(
          req.body.referralCode,
        ).toUpperCase();

      if (!code) {
        return res.status(400).json({
          success: false,
          error:
            "referral_code_required",
        });
      }

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

      if (user.referrerUid) {
        return res.status(400).json({
          success: false,
          error:
            "referral_already_used",
        });
      }

      const inviterSnapshot =
        await db
          .ref(`referralCodes/${code}`)
          .once("value");

      if (!inviterSnapshot.exists()) {
        return res.status(400).json({
          success: false,
          error:
            "invalid_referral_code",
        });
      }

      const inviterUid =
        inviterSnapshot.val();

      if (inviterUid === uid) {
        return res.status(400).json({
          success: false,
          error:
            "cannot_refer_yourself",
        });
      }

      const inviterRef =
        db.ref(`users/${inviterUid}`);

      const inviterSnapshotUser =
        await inviterRef.once("value");

      if (
        !inviterSnapshotUser.exists()
      ) {
        return res.status(400).json({
          success: false,
          error:
            "inviter_not_found",
        });
      }

      const inviter =
        inviterSnapshotUser.val();

      const timestamp =
        now();

      const updates = {};

      updates[
        `users/${uid}/referrerUid`
      ] = inviterUid;

      updates[
        `users/${uid}/fanBalance`
      ] =
        safeNumber(user.fanBalance) +
        CONFIG.newUserReferralReward;

      updates[
        `users/${uid}/updatedAt`
      ] = timestamp;

      updates[
        `users/${inviterUid}/fanBalance`
      ] =
        safeNumber(
          inviter.fanBalance,
        ) +
        CONFIG.inviterReferralReward;

      updates[
        `users/${inviterUid}/activeReferralCount`
      ] =
        safeNumber(
          inviter.activeReferralCount,
        ) + 1;

      updates[
        `users/${inviterUid}/miningRate`
      ] =
        calculateMiningRate({
          ...inviter,
          activeReferralCount:
            safeNumber(
              inviter.activeReferralCount,
            ) + 1,
        });

      updates[
        `users/${inviterUid}/updatedAt`
      ] = timestamp;

      updates[
        `referrals/${inviterUid}/${uid}`
      ] = {
        uid,
        active: true,
        createdAt: timestamp,
      };

      await db.ref().update(updates);

      return res.json({
        success: true,

        message:
          "Referral successfully applied.",

        newUserReward:
          CONFIG.newUserReferralReward,

        inviterReward:
          CONFIG.inviterReferralReward,

        activeReferralMiningBonus:
          CONFIG.activeReferralMiningBonus,
      });
    } catch (error) {
      console.error(
        "Referral error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// REFERRAL — LIST
// ============================================================

app.get(
  "/api/referral/list",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const snapshot =
        await db
          .ref(`referrals/${uid}`)
          .once("value");

      const data =
        snapshot.val() || {};

      const referrals =
        Object.values(data);

      return res.json({
        success: true,

        activeReferralCount:
          referrals.filter(
            (item) =>
              item.active === true,
          ).length,

        referrals,
      });
    } catch (error) {
      console.error(
        "Referral list error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// SOCIAL — DAILY CLAIM
// ============================================================

app.post(
  "/api/social/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const date =
        todayKey();

      const claimRef =
        db.ref(
          `socialClaims/${uid}/${date}`,
        );

      const claimResult =
        await claimRef.transaction(
          (existing) => {
            if (existing) {
              return;
            }

            return {
              reward:
                CONFIG.dailySocialReward,

              coin:
                CONFIG.miningCoin,

              claimedAt:
                now(),
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

      const userRef =
        db.ref(`users/${uid}`);

      const userSnapshot =
        await userRef.once("value");

      if (!userSnapshot.exists()) {
        await claimRef.remove();

        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      let finalBalance = 0;

      const balanceResult =
        await userRef.transaction(
          (user) => {
            if (!user) {
              return user;
            }

            user.fanBalance =
              safeNumber(
                user.fanBalance,
              ) +
              CONFIG.dailySocialReward;

            user.updatedAt =
              now();

            finalBalance =
              user.fanBalance;

            return user;
          },
        );

      if (!balanceResult.committed) {
        await claimRef.remove();

        return res.status(500).json({
          success: false,
          error:
            "social_reward_failed",
        });
      }

      return res.json({
        success: true,

        reward:
          CONFIG.dailySocialReward,

        coin:
          CONFIG.miningCoin,

        fanBalance:
          finalBalance,
      });
    } catch (error) {
      console.error(
        "Social claim error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// WALLET
// ============================================================

app.get(
  "/api/wallet",
  authenticate,
  async (req, res) => {
    try {
      const user =
        await getUser(req.user.uid);

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
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

        walletStatus:
          "COMING SOON",
      });
    } catch (error) {
      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// LOGOUT
// ============================================================

app.post(
  "/api/auth/logout",
  authenticate,
  async (req, res) => {
    try {
      await auth.revokeRefreshTokens(
        req.user.uid,
      );

      return res.json({
        success: true,
        message:
          "Session revoked.",
      });
    } catch (error) {
      console.error(
        "Logout error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "logout_failed",
      });
    }
  },
);

// ============================================================
// 404
// ============================================================

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: "not_found",
    message:
      "API endpoint not found.",
  });
});

// ============================================================
// GLOBAL ERROR HANDLER
// ============================================================

app.use(
  (
    error,
    req,
    res,
    next,
  ) => {
    console.error(
      "Unhandled server error:",
      error,
    );

    if (res.headersSent) {
      return next(error);
    }

    res.status(500).json({
      success: false,
      error:
        "internal_server_error",
    });
  },
);

// ============================================================
// START SERVER
// ============================================================

app.listen(
  PORT,
  "0.0.0.0",
  () => {
    console.log(
      `POWER FAN NETWORK API running on port ${PORT}`,
    );
  },
);
