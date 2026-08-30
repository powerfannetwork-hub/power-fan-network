// ============================================================
// POWER FAN NETWORK
// FIREBASE ADMIN / FIRESTORE ONLY
// ============================================================
//
// Firebase Authentication: NOT USED
// Realtime Database: NOT USED
// Firestore: USED
// ============================================================

const admin = require("firebase-admin");

let db = null;
let initialized = false;

function initializeFirebase() {
  if (initialized) {
    return db;
  }

  try {
    /*
     * Option 1:
     * FIREBASE_SERVICE_ACCOUNT
     *
     * Wannan environment variable ya kamata ya ƙunshi
     * complete Firebase service account JSON.
     */

    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const serviceAccount = JSON.parse(
        process.env.FIREBASE_SERVICE_ACCOUNT
      );

      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else {
      /*
       * Option 2:
       * GOOGLE_APPLICATION_CREDENTIALS
       *
       * Ko kuma hosting environment wanda ke samar da
       * Google credentials.
       */

      admin.initializeApp();
    }

    db = admin.firestore();

    /*
     * Firestore settings.
     */

    db.settings({
      ignoreUndefinedProperties: true,
    });

    initialized = true;

    console.log("==========================================");
    console.log("POWER FAN NETWORK");
    console.log("Firebase Authentication: DISABLED");
    console.log("Realtime Database: DISABLED");
    console.log("Firestore: ENABLED");
    console.log("Firebase Admin: CONNECTED");
    console.log("==========================================");

    return db;
  } catch (error) {
    console.error("==========================================");
    console.error("FIRESTORE INITIALIZATION FAILED");
    console.error(error.message);
    console.error("==========================================");

    db = null;

    return null;
  }
}

function getDb() {
  if (!initialized) {
    initializeFirebase();
  }

  return db;
}

module.exports = {
  admin,
  initializeFirebase,
  getDb,
};
