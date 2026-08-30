require("dotenv").config();

const express = require("express");
const cors = require("cors");
const admin = require("firebase-admin");

const app = express();

const PORT = process.env.PORT || 3000;

// ============================================================
// FIREBASE ADMIN INITIALIZATION
// ============================================================

if (!process.env.FIREBASE_PROJECT_ID ||
    !process.env.FIREBASE_CLIENT_EMAIL ||
    !process.env.FIREBASE_PRIVATE_KEY) {
  console.error("Missing Firebase server environment variables.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
  }),
});

const db = admin.firestore();
const auth = admin.auth();

// ============================================================
// APP CONFIGURATION
// ============================================================

const CONFIG = {
  coin: "FAN",

  baseMiningRate: 0.2,
  adBoostPerAd: 0.1,
  maximumDailyAds: 7,
  maximumAdBoost: 0.7,
  maximumMiningRate: 0.9,

  miningSessionHours: 24,

  newUserReferralReward: 20,
  inviterReferralReward: 5,
  activeReferralMiningBoost: 0.02,

  dailySocialReward: 10,
};

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(cors());
app.use(express.json());

// ============================================================
// HELPERS
// ============================================================

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function hoursBetween(start, end) {
  return Math.max(0, (end.getTime() - start.getTime()) / 3600000);
}

function calculateMiningRate(user) {
  const referralBoost =
    Number(user.activeReferrals || 0) *
    CONFIG.activeReferralMiningBoost;

  const adBoost = Math.min(
    Number(user.adBoost || 0),
    CONFIG.maximumAdBoost
  );

  return Math.min(
    CONFIG.baseMiningRate + referralBoost + adBoost,
    CONFIG.maximumMiningRate
  );
}

// ============================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================

async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || "";

    if (!header.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message: "Firebase authentication token is required",
      });
    }

    const token = header.substring(7);

    const decodedToken = await auth.verifyIdToken(token);

    req.user = decodedToken;

    next();
  } catch (error) {
    console.error("Authentication error:", error);

    return res.status(401).json({
      success: false,
      error: "invalid_token",
      message: "Authentication failed",
    });
  }
}

// ============================================================
// PUBLIC INFORMATION
// ============================================================

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: "POWER FAN NETWORK",
    service: "Production Backend",
    version: "1.0.0",
    status: "online",
  });
});

app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "ok",
    service: "POWER FAN NETWORK Backend",
    time: new Date().toISOString(),
  });
});

app.get("/api/status", (req, res) => {
  res.json({
    success: true,
    app: "POWER FAN NETWORK",
    backend: true,
    database: "Firebase Firestore",
    authentication: "Firebase Authentication",
    status: "online",
  });
});

// ============================================================
// CONFIGURATION
// ============================================================

app.get("/api/mining/config", (req, res) => {
  res.json({
    success: true,
    coin: CONFIG.coin,
    baseMiningRate: CONFIG.baseMiningRate,
    adBoostPerAd: CONFIG.adBoostPerAd,
    maximumDailyAds: CONFIG.maximumDailyAds,
    maximumAdBoost: CONFIG.maximumAdBoost,
    maximumMiningRate: CONFIG.maximumMiningRate,
    miningSessionHours: CONFIG.miningSessionHours,
  });
});

app.get("/api/referral/config", (req, res) => {
  res.json({
    success: true,
    newUserReward: CONFIG.newUserReferralReward,
    inviterReward: CONFIG.inviterReferralReward,
    miningRatePerActiveReferral:
      CONFIG.activeReferralMiningBoost,
  });
});

app.get("/api/social/config", (req, res) => {
  res.json({
    success: true,
    coin: CONFIG.coin,
    dailyReward: CONFIG.dailySocialReward,
  });
});

// ============================================================
// CREATE / INITIALIZE USER PROFILE
// ============================================================

app.post("/api/users/profile", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    if (userSnap.exists) {
      return res.json({
        success: true,
        created: false,
        user: userSnap.data(),
      });
    }

    const referralCode =
      String(req.body.referralCode || "")
        .trim()
        .toUpperCase();

    const ownReferralCode = uid.substring(0, 8).toUpperCase();

    const newUser = {
      uid,
      email: req.user.email || null,

      fanBalance: 0,
      afamBalance: 0,

      miningActive: false,
      miningStartedAt: null,
      miningEndsAt: null,

      miningRate: CONFIG.baseMiningRate,

      adBoost: 0,
      adsWatchedToday: 0,
      adsDate: todayKey(),

      activeReferrals: 0,
      referralCode: ownReferralCode,
      referredBy: null,

      lastSocialClaimDate: null,

      kycLevel: 0,
      dailyCheckInStreak: 0,

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.runTransaction(async (transaction) => {
      const freshUser = await transaction.get(userRef);

      if (freshUser.exists) {
        return;
      }

      transaction.set(userRef, newUser);

      // --------------------------------------------------------
      // REAL REFERRAL PROCESS
      // --------------------------------------------------------

      if (referralCode) {
        const inviterQuery = await db
          .collection("users")
          .where("referralCode", "==", referralCode)
          .limit(1)
          .get();

        if (!inviterQuery.empty) {
          const inviterDoc = inviterQuery.docs[0];

          if (inviterDoc.id !== uid) {
            const inviterRef = inviterDoc.ref;

            transaction.update(userRef, {
              fanBalance: CONFIG.newUserReferralReward,
              referredBy: inviterDoc.id,
            });

            transaction.update(inviterRef, {
              fanBalance: admin.firestore.FieldValue.increment(
                CONFIG.inviterReferralReward
              ),
              activeReferrals:
                admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }
    });

    const finalSnap = await userRef.get();

    return res.status(201).json({
      success: true,
      created: true,
      user: finalSnap.data(),
    });
  } catch (error) {
    console.error("Create profile error:", error);

    return res.status(500).json({
      success: false,
      error: "profile_creation_failed",
      message: "Unable to create user profile",
    });
  }
});

// ============================================================
// GET CURRENT USER
// ============================================================

app.get("/api/users/me", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();

    if (!snap.exists) {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
        message: "User profile not found",
      });
    }

    const user = snap.data();

    user.miningRate = calculateMiningRate(user);

    return res.json({
      success: true,
      user,
    });
  } catch (error) {
    console.error("Get user error:", error);

    return res.status(500).json({
      success: false,
      error: "server_error",
    });
  }
});

// ============================================================
// START MINING
// ============================================================

app.post("/api/mining/start", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);

    const result = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(userRef);

      if (!snap.exists) {
        throw new Error("USER_NOT_FOUND");
      }

      const user = snap.data();

      if (user.miningActive === true) {
        throw new Error("MINING_ALREADY_ACTIVE");
      }

      const now = new Date();

      const end = new Date(
        now.getTime() +
        CONFIG.miningSessionHours * 60 * 60 * 1000
      );

      const rate = calculateMiningRate(user);

      transaction.update(userRef, {
        miningActive: true,
        miningStartedAt: admin.firestore.Timestamp.fromDate(now),
        miningEndsAt: admin.firestore.Timestamp.fromDate(end),
        miningRate: rate,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        miningActive: true,
        miningRate: rate,
        miningStartedAt: now.toISOString(),
        miningEndsAt: end.toISOString(),
      };
    });

    return res.json({
      success: true,
      message: "Mining session started",
      ...result,
    });
  } catch (error) {
    if (error.message === "USER_NOT_FOUND") {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
      });
    }

    if (error.message === "MINING_ALREADY_ACTIVE") {
      return res.status(409).json({
        success: false,
        error: "mining_already_active",
      });
    }

    console.error("Start mining error:", error);

    return res.status(500).json({
      success: false,
      error: "mining_start_failed",
    });
  }
});

// ============================================================
// CLAIM MINING REWARD
// ============================================================

app.post("/api/mining/claim", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);

    const result = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(userRef);

      if (!snap.exists) {
        throw new Error("USER_NOT_FOUND");
      }

      const user = snap.data();

      if (!user.miningActive) {
        throw new Error("MINING_NOT_ACTIVE");
      }

      if (!user.miningStartedAt || !user.miningEndsAt) {
        throw new Error("INVALID_MINING_SESSION");
      }

      const now = new Date();
      const started = user.miningStartedAt.toDate();
      const ends = user.miningEndsAt.toDate();

      const elapsedHours = Math.min(
        CONFIG.miningSessionHours,
        hoursBetween(started, now)
      );

      if (now < ends) {
        throw new Error("MINING_NOT_FINISHED");
      }

      const rate = calculateMiningRate(user);

      const reward = Number(
        (elapsedHours * rate).toFixed(8)
      );

      transaction.update(userRef, {
        fanBalance:
          admin.firestore.FieldValue.increment(reward),

        miningActive: false,
        miningStartedAt: null,
        miningEndsAt: null,

        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        reward,
        miningRate: rate,
        elapsedHours,
      };
    });

    return res.json({
      success: true,
      message: "Mining reward claimed",
      coin: CONFIG.coin,
      ...result,
    });
  } catch (error) {
    if (error.message === "MINING_NOT_FINISHED") {
      return res.status(400).json({
        success: false,
        error: "mining_not_finished",
        message: "Mining session has not finished yet",
      });
    }

    if (error.message === "MINING_NOT_ACTIVE") {
      return res.status(400).json({
        success: false,
        error: "mining_not_active",
      });
    }

    console.error("Claim mining error:", error);

    return res.status(500).json({
      success: false,
      error: "mining_claim_failed",
    });
  }
});

// ============================================================
// REWARDED AD
// ============================================================

app.post("/api/mining/ad-reward", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);

    const result = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(userRef);

      if (!snap.exists) {
        throw new Error("USER_NOT_FOUND");
      }

      const user = snap.data();

      const today = todayKey();

      let adsWatched = Number(user.adsWatchedToday || 0);
      let adBoost = Number(user.adBoost || 0);

      if (user.adsDate !== today) {
        adsWatched = 0;
        adBoost = 0;
      }

      if (adsWatched >= CONFIG.maximumDailyAds) {
        throw new Error("DAILY_AD_LIMIT");
      }

      adsWatched += 1;

      adBoost = Math.min(
        adsWatched * CONFIG.adBoostPerAd,
        CONFIG.maximumAdBoost
      );

      const miningRate = calculateMiningRate({
        ...user,
        adsWatchedToday: adsWatched,
        adBoost,
      });

      transaction.update(userRef, {
        adsWatchedToday: adsWatched,
        adsDate: today,
        adBoost,
        miningRate,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        adsWatchedToday: adsWatched,
        adBoost,
        miningRate,
      };
    });

    return res.json({
      success: true,
      message: "Ad reward recorded",
      ...result,
    });
  } catch (error) {
    if (error.message === "DAILY_AD_LIMIT") {
      return res.status(429).json({
        success: false,
        error: "daily_ad_limit",
        message: "Maximum 7 rewarded ads per day",
      });
    }

    console.error("Ad reward error:", error);

    return res.status(500).json({
      success: false,
      error: "ad_reward_failed",
    });
  }
});

// ============================================================
// DAILY SOCIAL REWARD
// ============================================================

app.post("/api/social/claim", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);

    const result = await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(userRef);

      if (!snap.exists) {
        throw new Error("USER_NOT_FOUND");
      }

      const user = snap.data();
      const today = todayKey();

      if (user.lastSocialClaimDate === today) {
        throw new Error("ALREADY_CLAIMED");
      }

      transaction.update(userRef, {
        fanBalance:
          admin.firestore.FieldValue.increment(
            CONFIG.dailySocialReward
          ),

        lastSocialClaimDate: today,

        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        reward: CONFIG.dailySocialReward,
        date: today,
      };
    });

    return res.json({
      success: true,
      message: "Daily social reward claimed",
      coin: CONFIG.coin,
      ...result,
    });
  } catch (error) {
    if (error.message === "ALREADY_CLAIMED") {
      return res.status(409).json({
        success: false,
        error: "already_claimed",
        message: "Daily social reward already claimed",
      });
    }

    console.error("Social reward error:", error);

    return res.status(500).json({
      success: false,
      error: "social_reward_failed",
    });
  }
});

// ============================================================
// REFERRAL INFORMATION
// ============================================================

app.get("/api/referrals", requireAuth, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();

    if (!snap.exists) {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
      });
    }

    const user = snap.data();

    const referrals = await db
      .collection("users")
      .where("referredBy", "==", uid)
      .get();

    return res.json({
      success: true,
      referralCode: user.referralCode,
      activeReferrals: user.activeReferrals || 0,
      totalReferrals: referrals.size,
    });
  } catch (error) {
    console.error("Referral error:", error);

    return res.status(500).json({
      success: false,
      error: "referral_fetch_failed",
    });
  }
});

// ============================================================
// 404
// ============================================================

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: "not_found",
    message: "API endpoint not found",
  });
});

// ============================================================
// ERROR HANDLER
// ============================================================

app.use((err, req, res, next) => {
  console.error(err);

  res.status(500).json({
    success: false,
    error: "internal_server_error",
  });
});

// ============================================================
// START SERVER
// ============================================================

app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `POWER FAN NETWORK production backend running on port ${PORT}`
  );
});
