// ============================================================
// POWER FAN NETWORK — SESSION STORE
// FILE: src/services/session_store.js
// ============================================================

const {
  hashSessionToken,
  isSessionExpired,
} = require("./session_service");

class SessionStore {
  constructor(db) {
    if (!db) {
      throw new Error(
        "Firebase Realtime Database instance is required.",
      );
    }

    this.db = db;
    this.sessionsRef = db.ref("sessions");
  }

  async create(session) {
    if (!session || !session.tokenHash || !session.uid) {
      throw new Error("Invalid session.");
    }

    await this.sessionsRef
      .child(session.tokenHash)
      .set({
        uid: session.uid,
        tokenHash: session.tokenHash,
        createdAt: session.createdAt,
        expiresAt: session.expiresAt,
      });

    return session;
  }

  async get(tokenHash) {
    if (!tokenHash) {
      return null;
    }

    const snapshot =
      await this.sessionsRef
        .child(tokenHash)
        .once("value");

    if (!snapshot.exists()) {
      return null;
    }

    const session = snapshot.val();

    if (isSessionExpired(session)) {
      await this.delete(tokenHash);
      return null;
    }

    return session;
  }

  async getByToken(token) {
    if (!token) {
      return null;
    }

    const tokenHash =
      hashSessionToken(token);

    return this.get(tokenHash);
  }

  async delete(tokenHash) {
    if (!tokenHash) {
      return;
    }

    await this.sessionsRef
      .child(tokenHash)
      .remove();
  }

  async deleteByToken(token) {
    if (!token) {
      return;
    }

    const tokenHash =
      hashSessionToken(token);

    await this.delete(tokenHash);
  }

  async deleteUserSessions(uid) {
    if (!uid) {
      return;
    }

    const snapshot =
      await this.sessionsRef.once("value");

    if (!snapshot.exists()) {
      return;
    }

    const sessions =
      snapshot.val() || {};

    const updates = {};

    Object.entries(sessions).forEach(
      ([tokenHash, session]) => {
        if (
          session &&
          session.uid === uid
        ) {
          updates[tokenHash] = null;
        }
      },
    );

    if (Object.keys(updates).length > 0) {
      await this.sessionsRef.update(
        updates,
      );
    }
  }

  async refresh(session) {
    if (!session || !session.tokenHash) {
      throw new Error("Invalid session.");
    }

    const existing =
      await this.get(session.tokenHash);

    if (!existing) {
      return null;
    }

    const updatedSession = {
      ...existing,
      expiresAt: session.expiresAt,
    };

    await this.sessionsRef
      .child(session.tokenHash)
      .set(updatedSession);

    return updatedSession;
  }

  async cleanupExpired() {
    const snapshot =
      await this.sessionsRef.once("value");

    if (!snapshot.exists()) {
      return 0;
    }

    const sessions =
      snapshot.val() || {};

    const updates = {};
    let removed = 0;

    Object.entries(sessions).forEach(
      ([tokenHash, session]) => {
        if (
          isSessionExpired(session)
        ) {
          updates[tokenHash] = null;
          removed++;
        }
      },
    );

    if (removed > 0) {
      await this.sessionsRef.update(
        updates,
      );
    }

    return removed;
  }
}

module.exports = SessionStore;
