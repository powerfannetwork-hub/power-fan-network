const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");
const crypto = require("crypto");

const app = express();

const PORT = process.env.PORT || 3000;

// ============================================================
// FIREBASE ADMIN — PRODUCTION
// ============================================================

const projectId = process.env.FIREBASE_PROJECT_ID;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
const privateKey = process.env.FIREBASE_PRIVATE_KEY;

if (!projectId || !clientEmail || !privateKey) {
  console.error(
    "Missing Firebase environment variables: " +
    "FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY"
  );

  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: projectId,
    clientEmail: clientEmail,
    privateKey: privateKey.replace(/\\n/g, "\n"),
  }),

  databaseURL:
    process.env.FIREBASE_DATABASE_URL ||
    `https://${projectId}-default-rtdb.firebaseio.com`,
});

const db = admin.database();
const auth = admin.auth();

// ============================================================
// APP CONFIGURATION
// ============================================================

const CONFIG = {
  appName: "POWER FAN NETWORK",

  coin: "FAN",

  originalCoin: "AFAM",

  // Mining
  baseMiningRate: 0.2,
  adBoostPerAd: 0.1,
  maximumDailyAds: 7,
  maximumAdBoost: 0.7,
  maximumMiningRate: 0.9,
  miningSessionHours: 24,

  // Referral
  newUserReferralReward: 20,
  inviterReferralReward: 5,
  activeReferralMiningBonus: 0.02,

  // Social
  dailySocialReward: 10,
};

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(
  cors({
    origin: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json({ limit: "1mb" }));

// ============================================================
// HELPERS
// ============================================================

function now() {
  return Date.now();
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function generateReferralCode() {
  return crypto.randomBytes(5).toString("hex").toUpperCase();
}

function cleanEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function calculateMiningRate(user) {
  const activeReferrals =
    Number(user.activeReferralCount || 0);

  const adBoost =
    Number(user.dailyAdBoost || 0);

  const referralBoost =
    activeReferrals *
    CONFIG.activeReferralMiningBonus;

  const total =
    CONFIG.baseMiningRate +
    referralBoost +
    adBoost;

  return Math.min(
    Number(total.toFixed(4)),
    CONFIG.maximumMiningRate
  );
}

async function getUser(uid) {
  const snapshot = await db
    .ref(`users/${uid}`)
    .once("value");

  if (!snapshot.exists()) {
    return null;
  }

  return snapshot.val();
}

async function createUniqueReferralCode() {
  let code;
  let exists = true;

  while (exists) {
    code = generateReferralCode();

    const snapshot = await db
      .ref(`referralCodes/${code}`)
      .once("value");

    exists = snapshot.exists();
  }

  return code;
}

// ============================================================
// PUBLIC INFORMATION
// ============================================================

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: CONFIG.appName,
    version: "1.0.0",
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
// AUTHENTICATION
// ============================================================

// ------------------------------------------------------------
// REGISTER
// ------------------------------------------------------------

app.post("/api/auth/register", async (req, res) => {
  try {
    const name = String(
      req.body.name || ""
    ).trim();

    const email = cleanEmail(
      req.body.email
    );

    const password = String(
      req.body.password || ""
    );

    if (!name) {
      return res.status(400).json({
        success: false,
        error: "name_required",
        message: "Full name is required.",
      });
    }

    if (!email) {
      return res.status(400).json({
        success: false,
        error: "email_required",
        message: "Email is required.",
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

    let firebaseUser;

    try {
      firebaseUser = await auth.createUser({
        email,
        password,
        displayName: name,
        emailVerified: false,
      });
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        return res.status(409).json({
          success: false,
          error: "email_already_exists",
          message:
            "An account already exists with this email.",
        });
      }

      throw error;
    }

    const uid = firebaseUser.uid;

    const referralCode =
      await createUniqueReferralCode();

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

      activeReferralCount: 0,

      referralCode,

      miningActive: false,
      miningStartedAt: null,
      miningEndsAt: null,

      createdAt: timestamp,
      updatedAt: timestamp,
    };

    try {
      await db.ref(`users/${uid}`).set(user);

      await db
        .ref(`referralCodes/${referralCode}`)
        .set(uid);
    } catch (databaseError) {
      // If database initialization fails after Firebase
      // account creation, remove the Firebase account
      // to avoid leaving a broken account behind.

      try {
        await auth.deleteUser(uid);
      } catch (_) {}

      throw databaseError;
    }

    return res.status(201).json({
      success: true,
      message: "Account created successfully.",

      user: {
        uid,
        name,
        email,
        referralCode,
        fanBalance: 0,
        afamBalance: 0,
        miningRate:
          CONFIG.baseMiningRate,
      },
    });
  } catch (error) {
    console.error(
      "Register error:",
      error
    );

    return res.status(500).json({
      success: false,
      error: "server_error",
      message:
        "Unable to create account.",
    });
  }
});

// ------------------------------------------------------------
// LOGIN
// ------------------------------------------------------------
//
// IMPORTANT:
// Firebase Admin SDK does not provide a password-login
// endpoint directly.
//
// The Flutter client will eventually use Firebase Auth
// to exchange email/password for a Firebase ID token,
// while this backend remains responsible for all protected
// application data and mining operations.
//
// Therefore this endpoint is intentionally not pretending
// to perform password authentication itself.
// ------------------------------------------------------------

app.post("/api/auth/login", async (req, res) => {
  return res.status(400).json({
    success: false,
    error: "client_auth_required",
    message:
      "Email/password authentication must be completed by Firebase Authentication before calling protected backend APIs.",
  });
});

// ------------------------------------------------------------
// AUTHENTICATE FIREBASE ID TOKEN
// ------------------------------------------------------------

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
        message:
          "Authentication token is empty.",
      });
    }

    const decodedToken =
      await auth.verifyIdToken(token);

    req.user = decodedToken;

    next();
  } catch (error) {
    console.error(
      "Authentication error:",
      error.message
    );

    return res.status(401).json({
      success: false,
      error: "invalid_authentication",
      message:
        "Invalid or expired Firebase ID token.",
    });
  }
}

// ------------------------------------------------------------
// CURRENT USER
// ------------------------------------------------------------

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
        user,
      });
    } catch (error) {
      console.error(
        "Auth me error:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// USER BOOTSTRAP
// ============================================================

app.post(
  "/api/user/bootstrap",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;

      let user =
        await getUser(uid);

      if (!user) {
        const referralCode =
          await createUniqueReferralCode();

        const timestamp = now();

        user = {
          uid,

          name:
            req.user.name ||
            req.user.email ||
            "",

          email:
            req.user.email ||
            "",

          fanBalance: 0,
          afamBalance: 0,

          miningRate:
            CONFIG.baseMiningRate,

          dailyAdCount: 0,
          dailyAdBoost: 0,

          activeReferralCount: 0,

          referralCode,

          miningActive: false,
          miningStartedAt: null,
          miningEndsAt: null,

          createdAt: timestamp,
          updatedAt: timestamp,
        };

        await db
          .ref(`users/${uid}`)
          .set(user);

        await db
          .ref(`referralCodes/${referralCode}`)
          .set(uid);
      }

      return res.json({
        success: true,
        user,
      });
    } catch (error) {
      console.error(
        "Bootstrap error:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
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
        user,
      });
    } catch (error) {
      console.error(
        "Profile error:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// MINING CONFIGURATION
// ============================================================

app.get(
  "/api/mining/config",
  (req, res) => {
    res.json({
      success: true,

      coin: CONFIG.coin,

      baseMiningRate:
        CONFIG.baseMiningRate,

      adBoostPerAd:
        CONFIG.adBoostPerAd,

      maximumDailyAds:
        CONFIG.maximumDailyAds,

      maximumAdBoost:
        CONFIG.maximumAdBoost,

      maximumMiningRate:
        CONFIG.maximumMiningRate,

      miningSessionHours:
        CONFIG.miningSessionHours,
    });
  }
);

// ============================================================
// START MINING
// ============================================================

app.post(
  "/api/mining/start",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;

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
          error: "mining_already_active",
          miningEndsAt:
            user.miningEndsAt,
        });
      }

      const timestamp = now();

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
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// CLAIM MINING
// ============================================================

app.post(
  "/api/mining/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      let earnedAmount = 0;

      let claimCompleted = false;

      await userRef.transaction(
        (user) => {
          if (!user) {
            return user;
          }

          if (
            user.miningActive !== true
          ) {
            return user;
          }

          const timestamp =
            now();

          const endsAt =
            Number(
              user.miningEndsAt || 0
            );

          if (timestamp < endsAt) {
            return user;
          }

          const start =
            Number(
              user.miningStartedAt ||
                timestamp
            );

          const elapsedHours =
            Math.max(
              0,
              Math.min(
                CONFIG.miningSessionHours,
                (endsAt - start) /
                  (60 * 60 * 1000)
              )
            );

          const rate =
            calculateMiningRate(user);

          earnedAmount =
            Number(
              (
                rate *
                elapsedHours
              ).toFixed(8)
            );

          user.fanBalance =
            Number(
              user.fanBalance || 0
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

          user.lastMiningClaimAt =
            timestamp;

          user.updatedAt =
            timestamp;

          claimCompleted = true;

          return user;
        }
      );

      const finalUser =
        await getUser(uid);

      if (!finalUser) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      if (!claimCompleted) {
        if (
          finalUser.miningActive
        ) {
          return res.status(400).json({
            success: false,
            error:
              "mining_not_finished",
            miningEndsAt:
              finalUser.miningEndsAt,
          });
        }

        return res.status(400).json({
          success: false,
          error:
            "nothing_to_claim",
        });
      }

      return res.json({
        success: true,

        earned:
          earnedAmount,

        coin:
          CONFIG.coin,

        fanBalance:
          finalUser.fanBalance,
      });
    } catch (error) {
      console.error(
        "Mining claim error:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// REFERRAL CONFIGURATION
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
  }
);

// ============================================================
// APPLY REFERRAL
// ============================================================

app.post(
  "/api/referral/apply",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;

      const code =
        String(
          req.body.referralCode ||
            ""
        )
          .trim()
          .toUpperCase();

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
          error:
            "user_not_found",
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
          .ref(
            `referralCodes/${code}`
          )
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
        await inviterRef.once(
          "value"
        );

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

      const newUserBalance =
        Number(
          user.fanBalance || 0
        ) +
        CONFIG.newUserReferralReward;

      const inviterBalance =
        Number(
          inviter.fanBalance || 0
        ) +
        CONFIG.inviterReferralReward;

      const newReferralCount =
        Number(
          inviter.activeReferralCount ||
            0
        ) + 1;

      await db.ref().update({
        [`users/${uid}/referrerUid`]:
          inviterUid,

        [`users/${uid}/fanBalance`]:
          newUserBalance,

        [`users/${uid}/updatedAt`]:
          timestamp,

        [`users/${inviterUid}/fanBalance`]:
          inviterBalance,

        [`users/${inviterUid}/activeReferralCount`]:
          newReferralCount,

        [`users/${inviterUid}/updatedAt`]:
          timestamp,

        [`referrals/${inviterUid}/${uid}`]:
          {
            uid,

            active: true,

            createdAt:
              timestamp,
          },
      });

      return res.json({
        success: true,

        message:
          "Referral successfully applied.",

        newUserReward:
          CONFIG.newUserReferralReward,

        inviterReward:
          CONFIG.inviterReferralReward,

        activeReferralCount:
          newReferralCount,
      });
    } catch (error) {
      console.error(
        "Referral error:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// SOCIAL CONFIGURATION
// ============================================================

app.get(
  "/api/social/config",
  (req, res) => {
    res.json({
      success: true,

      dailyReward:
        CONFIG.dailySocialReward,

      coin:
        CONFIG.coin,
    });
  }
);

// ============================================================
// CLAIM DAILY SOCIAL REWARD
// ============================================================

app.post(
  "/api/social/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;

      const date =
        todayKey();

      const claimRef =
        db.ref(
          `socialClaims/${uid}/${date}`
        );

      const existing =
        await claimRef.once(
          "value"
        );

      if (existing.exists()) {
        return res.status(400).json({
          success: false,
          error:
            "social_reward_already_claimed",
        });
      }

      const userRef =
        db.ref(`users/${uid}`);

      const userSnapshot =
        await userRef.once(
          "value"
        );

      if (!userSnapshot.exists()) {
        return res.status(404).json({
          success: false,
          error:
            "user_not_found",
        });
      }

      const user =
        userSnapshot.val();

      const timestamp =
        now();

      const newBalance =
        Number(
          user.fanBalance || 0
        ) +
        CONFIG.dailySocialReward;

      await db.ref().update({
        [`users/${uid}/fanBalance`]:
          newBalance,

        [`users/${uid}/updatedAt`]:
          timestamp,

        [`socialClaims/${uid}/${date}`]:
          {
            reward:
              CONFIG.dailySocialReward,

            coin:
              CONFIG.coin,

            claimedAt:
              timestamp,
          },
      });

      return res.json({
        success: true,

        reward:
          CONFIG.dailySocialReward,

        coin:
          CONFIG.coin,

        fanBalance:
          newBalance,
      });
    } catch (error) {
      console.error(
        "Social reward error:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// 404
// ============================================================

app.use(
  (req, res) => {
    res.status(404).json({
      success: false,
      error: "not_found",
      message:
        "API endpoint not found.",
    });
  }
);

// ============================================================
// GLOBAL ERROR HANDLER
// ============================================================

app.use(
  (error, req, res, next) => {
    console.error(
      "Unhandled server error:",
      error
    );

    res.status(500).json({
      success: false,
      error:
        "internal_server_error",
    });
  }
);

// ============================================================
// START SERVER
// ============================================================

app.listen(
  PORT,
  "0.0.0.0",
  () => {
    console.log(
      `POWER FAN NETWORK API running on port ${PORT}`
    );

    console.log(
      `Environment: ${
        process.env.NODE_ENV ||
        "production"
      }`
    );
  }
);
