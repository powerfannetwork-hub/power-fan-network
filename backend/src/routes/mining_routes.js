// ============================================================
// POWER FAN NETWORK
// MINING + REFERRAL ROUTES
// ============================================================

const express = require("express");

const {
  authenticate,
} = require("../../middleware/auth");

const { getDb } =
  require("../firebase");

const router = express.Router();

const BASE_RATE = 0.2;
const AD_BOOST = 0.1;
const MAX_ADS = 7;
const REFERRAL_BOOST = 0.02;
const SESSION_HOURS = 24;

// ============================================================
// START MINING
// ============================================================

router.post(
  "/start",
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

      const userRef =
        db
          .collection("users")
          .doc(req.userId);

      let result = null;

      await db.runTransaction(
        async (transaction) => {
          const userDoc =
            await transaction.get(
              userRef
            );

          if (!userDoc.exists) {
            throw new Error(
              "USER_NOT_FOUND"
            );
          }

          const user =
            userDoc.data();

          if (user.miningActive) {
            throw new Error(
              "MINING_ALREADY_ACTIVE"
            );
          }

          const now =
            new Date();

          const endsAt =
            new Date(
              now.getTime() +
                SESSION_HOURS *
                  60 *
                  60 *
                  1000
            );

          /*
           * Current referral boost is based
           * on active referrals.
           */

          const activeReferrals =
            Number(
              user.activeReferrals ||
                0
            );

          const adBoost =
            Number(
              user.adBoost || 0
            );

          const miningRate =
            BASE_RATE +
            activeReferrals *
              REFERRAL_BOOST +
            adBoost;

          const updateData = {
            miningActive:
              true,

            miningStartedAt:
              now.toISOString(),

            miningEndsAt:
              endsAt.toISOString(),

            miningRate,

            updatedAt:
              now.toISOString(),
          };

          transaction.update(
            userRef,
            updateData
          );

          /*
           * If this user was invited by
           * another user, starting mining
           * makes this referral ACTIVE.
           */

          if (
            user.referredBy &&
            !user.referralActiveForSession
          ) {
            const referrerRef =
              db
                .collection("users")
                .doc(
                  user.referredBy
                );

            const referrerDoc =
              await transaction.get(
                referrerRef
              );

            if (referrerDoc.exists) {
              const referrer =
                referrerDoc.data();

              const active =
                Number(
                  referrer.activeReferrals ||
                    0
                );

              const newActive =
                active + 1;

              const referrerAdBoost =
                Number(
                  referrer.adBoost ||
                    0
                );

              const newRate =
                BASE_RATE +
                newActive *
                  REFERRAL_BOOST +
                referrerAdBoost;

              transaction.update(
                referrerRef,
                {
                  activeReferrals:
                    newActive,

                  miningRate:
                    newRate,

                  updatedAt:
                    now.toISOString(),
                }
              );

              transaction.update(
                userRef,
                {
                  referralActiveForSession:
                    true,
                }
              );
            }
          }

          result = {
            startedAt:
              now.toISOString(),

            endsAt:
              endsAt.toISOString(),

            miningRate,
          };
        }
      );

      return res.json({
        success: true,

        message:
          "Mining started.",

        mining: {
          active: true,
          ...result,
        },
      });
    } catch (error) {
      console.error(
        "START MINING ERROR:",
        error
      );

      if (
        error.message ===
        "MINING_ALREADY_ACTIVE"
      ) {
        return res.status(400).json({
          success: false,
          message:
            "Mining is already active.",
        });
      }

      return res.status(500).json({
        success: false,
        message:
          "Could not start mining.",
      });
    }
  }
);

// ============================================================
// CLAIM MINING
// ============================================================

router.post(
  "/claim",
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

      const userRef =
        db
          .collection("users")
          .doc(req.userId);

      let result = null;

      await db.runTransaction(
        async (transaction) => {
          const userDoc =
            await transaction.get(
              userRef
            );

          if (!userDoc.exists) {
            throw new Error(
              "USER_NOT_FOUND"
            );
          }

          const user =
            userDoc.data();

          if (!user.miningActive) {
            throw new Error(
              "MINING_NOT_ACTIVE"
            );
          }

          if (!user.miningEndsAt) {
            throw new Error(
              "MISSING_END_TIME"
            );
          }

          const now =
            new Date();

          const endsAt =
            new Date(
              user.miningEndsAt
            );

          if (now < endsAt) {
            throw new Error(
              "MINING_NOT_FINISHED"
            );
          }

          const miningRate =
            Number(
              user.miningRate ||
                BASE_RATE
            );

          const reward =
            miningRate *
            SESSION_HOURS;

          const currentBalance =
            Number(
              user.fanBalance || 0
            );

          const newBalance =
            currentBalance +
            reward;

          transaction.update(
            userRef,
            {
              fanBalance:
                newBalance,

              miningActive:
                false,

              miningStartedAt:
                null,

              miningEndsAt:
                null,

              dailyAdsWatched:
                0,

              adBoost:
                0,

              miningRate:
                BASE_RATE +
                Number(
                  user.activeReferrals ||
                    0
                ) *
                  REFERRAL_BOOST,

              updatedAt:
                now.toISOString(),
            }
          );

          /*
           * Referral remains active while
           * the referred user's session is active.
           *
           * When the session ends, remove the
           * active referral boost.
           */

          if (
            user.referredBy &&
            user.referralActiveForSession
          ) {
            const referrerRef =
              db
                .collection("users")
                .doc(
                  user.referredBy
                );

            const referrerDoc =
              await transaction.get(
                referrerRef
              );

            if (referrerDoc.exists) {
              const referrer =
                referrerDoc.data();

              const active =
                Math.max(
                  0,
                  Number(
                    referrer.activeReferrals ||
                      0
                  ) - 1
                );

              const referrerRate =
                BASE_RATE +
                active *
                  REFERRAL_BOOST +
                Number(
                  referrer.adBoost ||
                    0
                );

              transaction.update(
                referrerRef,
                {
                  activeReferrals:
                    active,

                  miningRate:
                    referrerRate,

                  updatedAt:
                    now.toISOString(),
                }
              );
            }

            transaction.update(
              userRef,
              {
                referralActiveForSession:
                  false,
              }
            );
          }

          result = {
            reward,

            fanBalance:
              newBalance,
          };
        }
      );

      return res.json({
        success: true,

        message:
          "Mining reward claimed.",

        reward:
          result.reward,

        fanBalance:
          result.fanBalance,

        miningActive:
          false,
      });
    } catch (error) {
      console.error(
        "CLAIM MINING ERROR:",
        error
      );

      if (
        error.message ===
        "MINING_NOT_ACTIVE"
      ) {
        return res.status(400).json({
          success: false,
          message:
            "Mining session is not active.",
        });
      }

      if (
        error.message ===
        "MINING_NOT_FINISHED"
      ) {
        return res.status(400).json({
          success: false,
          message:
            "Mining session has not ended yet.",
        });
      }

      return res.status(500).json({
        success: false,
        message:
          "Could not claim mining reward.",
      });
    }
  }
);

// ============================================================
// WATCH REWARDED AD
// ============================================================

router.post(
  "/ad",
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

      const userRef =
        db
          .collection("users")
          .doc(req.userId);

      let result = null;

      await db.runTransaction(
        async (transaction) => {
          const userDoc =
            await transaction.get(
              userRef
            );

          if (!userDoc.exists) {
            throw new Error(
              "USER_NOT_FOUND"
            );
          }

          const user =
            userDoc.data();

          const watched =
            Number(
              user.dailyAdsWatched ||
                0
            );

          if (watched >= MAX_ADS) {
            throw new Error(
              "MAX_ADS"
            );
          }

          const newWatched =
            watched + 1;

          const newAdBoost =
            newWatched *
            AD_BOOST;

          const activeReferrals =
            Number(
              user.activeReferrals ||
                0
            );

          const newRate =
            BASE_RATE +
            activeReferrals *
              REFERRAL_BOOST +
            newAdBoost;

          transaction.update(
            userRef,
            {
              dailyAdsWatched:
                newWatched,

              adBoost:
                newAdBoost,

              miningRate:
                newRate,

              updatedAt:
                new Date().toISOString(),
            }
          );

          result = {
            adsWatched:
              newWatched,

            adBoost:
              newAdBoost,

            miningRate:
              newRate,
          };
        }
      );

      return res.json({
        success: true,

        message:
          "Ad reward applied.",

        ...result,
      });
    } catch (error) {
      console.error(
        "AD ERROR:",
        error
      );

      if (
        error.message ===
        "MAX_ADS"
      ) {
        return res.status(400).json({
          success: false,
          message:
            "You have reached the maximum of 7 rewarded ads today.",
        });
      }

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
      const db = getDb();

      if (!db) {
        return res.status(503).json({
          success: false,
          message:
            "Database is not connected.",
        });
      }

      const query =
        await db
          .collection("users")
          .where(
            "referredBy",
            "==",
            req.userId
          )
          .get();

      const referrals =
        query.docs.map(
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
              BASE_RATE
          ),

        referrals,
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

module.exports = router;
