import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import CryptoJS from "npm:crypto-js@4.2.0";

const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ?? "";

const serviceRoleKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const privateKey =
  Deno.env.get("LEVELPLAY_S2S_PRIVATE_KEY") ?? "";

const expectedAppKey =
  Deno.env.get("LEVELPLAY_APP_KEY") ?? "";

const admin = createClient(
  supabaseUrl,
  serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

function response(
  body: string,
  status = 200,
): Response {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
}

function clean(value: string | null): string {
  return (value ?? "").trim();
}

function md5(value: string): string {
  return CryptoJS.MD5(value)
    .toString(CryptoJS.enc.Hex)
    .toLowerCase();
}

function safeEqual(a: string, b: string): boolean {
  const left = a.toLowerCase();
  const right = b.toLowerCase();

  if (left.length !== right.length) {
    return false;
  }

  let result = 0;

  for (let i = 0; i < left.length; i++) {
    result |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }

  return result === 0;
}

function normalizeUuid(value: string): string {
  const trimmed = value.trim();

  if (
    /^[0-9a-f]{32}$/i.test(trimmed)
  ) {
    return [
      trimmed.substring(0, 8),
      trimmed.substring(8, 12),
      trimmed.substring(12, 16),
      trimmed.substring(16, 20),
      trimmed.substring(20, 32),
    ].join("-");
  }

  return trimmed;
}

function isValidUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

function isValidLevelPlayTimestamp(
  timestamp: string,
): boolean {
  if (!/^\d{12}$/.test(timestamp)) {
    return false;
  }

  const year = Number(timestamp.substring(0, 4));
  const month = Number(timestamp.substring(4, 6));
  const day = Number(timestamp.substring(6, 8));
  const hour = Number(timestamp.substring(8, 10));
  const minute = Number(timestamp.substring(10, 12));

  if (
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return false;
  }

  const date = new Date(
    Date.UTC(
      year,
      month - 1,
      day,
      hour,
      minute,
    ),
  );

  return (
    !Number.isNaN(date.getTime()) &&
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day &&
    date.getUTCHours() === hour &&
    date.getUTCMinutes() === minute
  );
}

Deno.serve(
  async (request: Request): Promise<Response> => {
    if (
      request.method !== "GET" &&
      request.method !== "POST"
    ) {
      return response("Method not allowed", 405);
    }

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Supabase environment variables are missing.");
      return response("Server configuration error", 500);
    }

    if (!privateKey || !expectedAppKey) {
      console.error("LevelPlay S2S environment variables are missing.");
      return response("Server configuration error", 500);
    }

    try {
      const url = new URL(request.url);
      const queryParams = url.searchParams;
      const body: Record<string, unknown> = {};

      if (request.method === "POST") {
        const contentType =
          request.headers.get("content-type") ?? "";

        if (
          contentType.toLowerCase().includes("application/json")
        ) {
          const json = await request.json().catch(() => ({}));

          if (
            json &&
            typeof json === "object" &&
            !Array.isArray(json)
          ) {
            Object.assign(body, json);
          }
        } else {
          const text = await request.text();
          const form = new URLSearchParams(text);

          form.forEach((value, key) => {
            body[key] = value;
          });
        }
      }

      const getParam = (...names: string[]): string => {
        for (const name of names) {
          const queryValue = queryParams.get(name);

          if (
            queryValue !== null &&
            queryValue.trim() !== ""
          ) {
            return clean(queryValue);
          }

          const bodyValue = body[name];

          if (
            bodyValue !== undefined &&
            bodyValue !== null &&
            String(bodyValue).trim() !== ""
          ) {
            return clean(String(bodyValue));
          }
        }

        return "";
      };

      const rawUserId = getParam(
        "applicationUserId",
        "appUserId",
        "dynamicUserId",
        "userId",
        "userid",
        "user_id",
        "USER_ID",
      );

      const eventId = getParam(
        "eventId",
        "eventID",
        "event_id",
        "EVENT_ID",
      );

      const rewards = getParam(
        "rewards",
        "reward",
        "REWARDS",
      );

      const timestamp = getParam(
        "timestamp",
        "TIMESTAMP",
      );

      const signature = getParam(
        "signature",
        "SIGNATURE",
      );

      const appKey = getParam(
        "appKey",
        "APP_KEY",
      );

      const placementName = getParam(
        "placementName",
        "placement_name",
        "PLACEMENT_NAME",
        "placement",
      );

      if (!rawUserId) {
        return response("Missing user ID", 400);
      }

      if (!eventId) {
        return response("Missing event ID", 400);
      }

      if (!rewards) {
        return response("Missing rewards", 400);
      }

      if (!timestamp) {
        return response("Missing timestamp", 400);
      }

      if (!signature) {
        return response("Missing signature", 400);
      }

      if (!appKey) {
        return response("Missing app key", 403);
      }

      if (
        rawUserId.length < 1 ||
        rawUserId.length > 64
      ) {
        return response("Invalid user ID", 400);
      }

      const userId = normalizeUuid(rawUserId);

      if (!isValidUuid(userId)) {
        return response("Invalid user ID", 400);
      }

      if (
        eventId.length < 1 ||
        eventId.length > 255
      ) {
        return response("Invalid event ID", 400);
      }

      const rewardNumber = Number(rewards);

      if (
        !Number.isFinite(rewardNumber) ||
        rewardNumber <= 0
      ) {
        return response("Invalid reward amount", 400);
      }

      if (!isValidLevelPlayTimestamp(timestamp)) {
        return response("Invalid timestamp", 400);
      }

      if (!safeEqual(appKey, expectedAppKey)) {
        console.error("LevelPlay app key mismatch.");
        return response("Invalid app key", 403);
      }

      /*
       * Muhimmi:
       * Ana amfani da rawUserId a signature domin kada
       * normalization ya canza payload ɗin LevelPlay.
       */
      const signaturePayload =
        timestamp +
        eventId +
        rawUserId +
        rewards +
        privateKey;

      const expectedSignature = md5(signaturePayload);

      if (!safeEqual(expectedSignature, signature)) {
        console.error("LevelPlay S2S signature validation failed.");
        return response("Invalid signature", 403);
      }

      /*
       * AFAM MIGRATION REWARDED AD
       *
       * Ana shiga wannan sashe ne kawai idan callback ya aika
       * placementName = AFAM_MIGRATION.
       *
       * Sauran ads suna ci gaba da tsohon tsarin mining/claim.
       */
      if (placementName === "AFAM_MIGRATION") {
        const {
          data: migrationData,
          error: migrationError,
        } = await admin.rpc(
          "record_levelplay_afam_migration_reward",
          {
            p_user_id: userId,
            p_event_id: eventId,
          },
        );

        if (migrationError) {
          console.error(
            "AFAM migration reward verification failed:",
            migrationError,
          );

          return response(
            "AFAM reward processing failed",
            500,
          );
        }

        if (
          !migrationData ||
          typeof migrationData !== "object"
        ) {
          return response(
            "Invalid AFAM reward response",
            500,
          );
        }

        const result =
          migrationData as Record<string, unknown>;

        if (result.success !== true) {
          /*
           * Idan an riga an karɓi event ɗin, a amsa OK
           * domin LevelPlay kada ya ci gaba da retry.
           */
          if (result.duplicate === true) {
            return response(`${eventId}:OK`, 200);
          }

          console.error(
            "AFAM migration reward rejected:",
            JSON.stringify(migrationData),
          );

          return response("AFAM reward rejected", 400);
        }

        console.log(
          "LevelPlay AFAM migration ad verified:",
          eventId,
        );

        return response(`${eventId}:OK`, 200);
      }

      /*
       * CLAIM AD
       *
       * Ba ya ƙara FAN kai tsaye.
       */
      const {
        data: claimData,
        error: claimError,
      } = await admin.rpc(
        "verify_levelplay_claim_ad",
        {
          p_user_id: userId,
          p_event_id: eventId,
        },
      );

      if (
        !claimError &&
        claimData &&
        typeof claimData === "object"
      ) {
        const claimResult =
          claimData as Record<string, unknown>;

        if (
          claimResult.success === true &&
          claimResult.verified === true
        ) {
          console.log(
            "LevelPlay CLAIM AD verified:",
            JSON.stringify(claimData),
          );

          return response(`${eventId}:OK`, 200);
        }

        if (claimResult.duplicate === true) {
          console.log(
            "LevelPlay duplicate CLAIM AD:",
            eventId,
          );

          return response(`${eventId}:OK`, 200);
        }
      }

      /*
       * NORMAL MINING AD
       *
       * Ana kiyaye tsohon RPC na mining reward.
       */
      const {
        data: normalData,
        error: normalError,
      } = await admin.rpc(
        "record_levelplay_reward",
        {
          p_user_id: userId,
          p_event_id: eventId,
        },
      );

      if (normalError) {
        const message = String(normalError.message ?? "");

        if (
          message.toLowerCase().includes("already processed")
        ) {
          console.log(
            "LevelPlay duplicate NORMAL AD acknowledged:",
            eventId,
          );

          return response(`${eventId}:OK`, 200);
        }

        console.error(
          "LevelPlay normal ad database error:",
          normalError,
        );

        return response("Reward processing failed", 500);
      }

      console.log(
        "LevelPlay NORMAL AD reward processed:",
        JSON.stringify(normalData),
      );

      return response(`${eventId}:OK`, 200);
    } catch (error) {
      console.error("LevelPlay S2S callback error:", error);
      return response("Internal server error", 500);
    }
  },
);
