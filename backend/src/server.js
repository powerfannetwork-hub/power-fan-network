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
  console.error("Missing Firebase environment variables.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: projectId,
    clientEmail: clientEmail,
    privateKey: privateKey.replace(/\\n/g, "\n"),
  }),
  databaseURL: `https://${projectId}-default-rtdb.firebaseio.com`,
});

const db = admin.database();
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

  activeReferralMiningBonus: 0.02,

  dailySocialReward: 10,
};

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(cors());
app.use(express.json({ limit: "1mb" }));

// ============================================================
// BASIC API
// ============================================================

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: "POWER FAN NETWORK",
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
    app: "POWER FAN NETWORK",
    backend: true,
    database: "Firebase Realtime Database",
    status: "online",
  });
});

// ============================================================
// CONFIG
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
      CONFIG.activeReferralMiningBonus,
  });
});

app.get("/api/social/config", (req, res) => {
  res.json({
    success: true,
    dailyReward: CONFIG.dailySocialReward,
    coin: CONFIG.coin,
  });
});

// ============================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================

async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization;

    if (!header || !header.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
        message: "Firebase ID token is required.",
      });
    }

    const token = header.substring(7);

    const decodedToken = await auth.verifyIdToken(token);

    req.user = decodedToken;

    next();
  } catch (error) {
    console.error("Authentication error:", error.message);

    return res.status(401).json({
      success: false,
      error: "invalid_authentication",
      message: "Invalid or expired Firebase ID token.",
    });
  }
}

// ============================================================
// HELPERS
// ============================================================

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function generateReferralCode() {
  return crypto.randomBytes(4).toString("hex").toUpperCase();
}

function calculateMiningRate(user) {
  const activeReferrals =
    Number(user.activeReferralCount || 0);

  const adBoost =
    Number(user.dailyAdBoost || 0);

  const referralBoost =
    activeReferrals * CONFIG.activeReferralMiningBonus;

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
  const snapshot = await db.ref(`users/${uid}`).once("value");

  return snapshot.exists() ? snapshot.val() : null;
}

// ============================================================
// CREATE / INITIALIZE USER
// ============================================================

app.post("/api/user/bootstrap", authenticate, async (req, res) => {
  try {
    const uid = req.user.uid;

    let user = await getUser(uid);

    if (!user) {
      let referralCode = generateReferralCode();

      let exists = await db
        .ref("referralCodes/" + referralCode)
        .once("value");

      while (exists.exists()) {
        referralCode = generateReferralCode();

        exists = await db
          .ref("referralCodes/" + referralCode)
          .once("value");
      }

      user = {
        uid,

        email: req.user.email || "",

        fanBalance: 0,
        afamBalance: 0,

        miningRate: CONFIG.baseMiningRate,

        dailyAdCount: 0,
        dailyAdBoost: 0,

        activeReferralCount: 0,

        referralCode,

        miningActive: false,
        miningStartedAt: null,
        miningEndsAt: null,

        createdAt: Date.now(),
        updatedAt: Date.now(),
      };

      await db.ref(`users/${uid}`).set(user);

      await db
        .ref(`referralCodes/${referralCode}`)
        .set(uid);
    }

    return res.json({
      success: true,
      user,
    });
  } catch (error) {
    console.error("Bootstrap error:", error);

    return res.status(500).json({
      success: false,
      error: "server_error",
    });
  }
});

// ============================================================
// GET USER PROFILE
// ============================================================

app.get("/api/user/profile", authenticate, async (req, res) => {
  try {
    const user = await getUser(req.user.uid);

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
    console.error("Profile error:", error);

    return res.status(500).json({
      success: false,
      error: "server_error",
    });
  }
});

// ============================================================
// START MINING
// ============================================================

app.post("/api/mining/start", authenticate, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.ref(`users/${uid}`);

    const snapshot = await userRef.once("value");

    if (!snapshot.exists()) {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
      });
    }

    const user = snapshot.val();

    if (user.miningActive === true) {
      return res.status(400).json({
        success: false,
        error: "mining_already_active",
        miningEndsAt: user.miningEndsAt,
      });
    }

    const now = Date.now();

    const endsAt =
      now +
      CONFIG.miningSessionHours *
        60 *
        60 *
        1000;

    const rate = calculateMiningRate(user);

    await userRef.update({
      miningActive: true,
      miningStartedAt: now,
      miningEndsAt: endsAt,
      miningRate: rate,
      updatedAt: now,
    });

    return res.json({
      success: true,
      message: "Mining session started.",
      miningRate: rate,
      miningStartedAt: now,
      miningEndsAt: endsAt,
    });
  } catch (error) {
    console.error("Mining start error:", error);

    return res.status(500).json({
      success: false,
      error: "server_error",
    });
  }
});

// ============================================================
// CLAIM MINING
// ============================================================

app.post("/api/mining/claim", authenticate, async (req, res) => {
  try {
    const uid = req.user.uid;

    const userRef = db.ref(`users/${uid}`);

    let earnedAmount = 0;
    let finalUser = null;

    await userRef.transaction((user) => {
      if (!user) {
        return user;
      }

      if (!user.miningActive) {
        return user;
      }

      const now = Date.now();
      const endsAt = Number(user.miningEndsAt || 0);

      if (now < endsAt) {
        return user;
      }

      const start =
        Number(user.miningStartedAt || now);

      const elapsedHours =
        Math.min(
          CONFIG.miningSessionHours,
          (endsAt - start) / (60 * 60 * 1000)
        );

      const rate = calculateMiningRate(user);

      earnedAmount = Number(
        (rate * elapsedHours).toFixed(8)
      );

      user.fanBalance =
        Number(user.fanBalance || 0) +
        earnedAmount;

      user.miningActive = false;
      user.miningStartedAt = null;
      user.miningEndsAt = null;
      user.miningRate = rate;
      user.updatedAt = now;

      return user;
    });

    finalUser = await getUser(uid);

    if (!finalUser) {
      return res.status(404).json({
        success: false,
        error: "user_not_found",
      });
    }

    if (earnedAmount <= 0) {
      if (finalUser.miningActive) {
        return res.status(400).json({
          success: false,
          error: "mining_not_finished",
          miningEndsAt: finalUser.miningEndsAt,
        });
      }

      return res.status(400).json({
        success: false,
        error: "nothing_to_claim",
      });
    }

    return res.json({
      success: true,
      earned: earnedAmount,
      coin: CONFIG.coin,
      fanBalance: finalUser.fanBalance,
    });
  } catch (error) {
    console.error("Mining claim error:", error);

    return res.status(500).json({
      success: false,
      error: "server_error",
    });
  }
});

// ============================================================
// REFERRAL
// ============================================================

app.post(
  "/api/referral/apply",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;

      const code = String(
        req.body.referralCode || ""
      )
        .trim()
        .toUpperCase();

      if (!code) {
        return res.status(400).json({
          success: false,
          error: "referral_code_required",
        });
      }

      const userRef = db.ref(`users/${uid}`);

      const userSnapshot = await userRef.once("value");

      if (!userSnapshot.exists()) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      const user = userSnapshot.val();

      if (user.referrerUid) {
        return res.status(400).json({
          success: false,
          error: "referral_already_used",
        });
      }

      const inviterSnapshot = await db
        .ref(`referralCodes/${code}`)
        .once("value");

      if (!inviterSnapshot.exists()) {
        return res.status(400).json({
          success: false,
          error: "invalid_referral_code",
        });
      }

      const inviterUid = inviterSnapshot.val();

      if (inviterUid === uid) {
        return res.status(400).json({
          success: false,
          error: "cannot_refer_yourself",
        });
      }

      const inviterRef =
        db.ref(`users/${inviterUid}`);

      const inviterUserSnapshot =
        await inviterRef.once("value");

      if (!inviterUserSnapshot.exists()) {
        return res.status(400).json({
          success: false,
          error: "inviter_not_found",
        });
      }

      const now = Date.now();

      await db.ref().update({
        [`users/${uid}/referrerUid`]: inviterUid,

        [`users/${uid}/fanBalance`]:
          Number(user.fanBalance || 0) +
          CONFIG.newUserReferralReward,

        [`users/${uid}/updatedAt`]: now,

        [`users/${inviterUid}/fanBalance`]:
          Number(inviterUserSnapshot.val().fanBalance || 0) +
          CONFIG.inviterReferralReward,

        [`users/${inviterUid}/activeReferralCount`]:
          Number(
            inviterUserSnapshot.val()
              .activeReferralCount || 0
          ) + 1,

        [`users/${inviterUid}/updatedAt`]: now,

        [`referrals/${inviterUid}/${uid}`]: {
          uid,
          active: true,
          createdAt: now,
        },
      });

      return res.json({
        success: true,
        message: "Referral successfully applied.",
        newUserReward:
          CONFIG.newUserReferralReward,
        inviterReward:
          CONFIG.inviterReferralReward,
      });
    } catch (error) {
      console.error("Referral error:", error);

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  }
);

// ============================================================
// DAILY SOCIAL REWARD
// ============================================================

app.post(
  "/api/social/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid = req.user.uid;
      const date = todayKey();

      const claimRef = db.ref(
        `socialClaims/${uid}/${date}`
      );

      const existing =
        await claimRef.once("value");

      if (existing.exists()) {
        return res.status(400).json({
          success: false,
          error: "social_reward_already_claimed",
        });
      }

      const userRef = db.ref(`users/${uid}`);

      const userSnapshot =
        await userRef.once("value");

      if (!userSnapshot.exists()) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      const user = userSnapshot.val();

      const now = Date.now();

      await db.ref().update({
        [`users/${uid}/fanBalance`]:
          Number(user.fanBalance || 0) +
          CONFIG.dailySocialReward,

        [`users/${uid}/updatedAt`]: now,

        [`socialClaims/${uid}/${date}`]: {
          reward: CONFIG.dailySocialReward,
          coin: CONFIG.coin,
          claimedAt: now,
        },
      });

      return res.json({
        success: true,
        reward: CONFIG.dailySocialReward,
        coin: CONFIG.coin,
      });
    } catch (error) {
      console.error("Social reward error:", error);

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

app.use((error, req, res, next) => {
  console.error("Unhandled error:", error);

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
    `POWER FAN NETWORK API running on port ${PORT}`
  );
});
