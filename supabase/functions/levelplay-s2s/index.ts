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

function clean(
  value: string | null,
): string {
  return (value ?? "").trim();
}

function md5(
  value: string,
): string {
  return CryptoJS.MD5(value)
    .toString(CryptoJS.enc.Hex)
    .toLowerCase();
}

function safeEqual(
  a: string,
  b: string,
): boolean {
  const left = a.toLowerCase();
  const right = b.toLowerCase();

  if (left.length !== right.length) {
    return false;
  }

  let result = 0;

  for (let i = 0; i < left.length; i++) {
    result |=
      left.charCodeAt(i) ^
      right.charCodeAt(i);
  }

  return result === 0;
}

Deno.serve(async (request: Request) => {
  /*
   * ==========================================================
   * LEVELPLAY S2S REWARDED AD CALLBACK
   * ==========================================================
   *
   * IMPORTANT:
   *
   * This endpoint is NOT authenticated with Supabase JWT.
   *
   * LevelPlay calls it directly.
   *
   * Security is provided by:
   *
   * 1. LEVELPLAY private-key signature
   * 2. EVENT_ID duplicate protection
   * 3. USER_ID / dynamicUserId validation
   * 4. Server-side Supabase service_role
   * 5. Database-side session validation
   * 6. Database-side 7-ad limit
   * 7. Database-side fixed reward = 0.10 FAN/H
   *
   * The Flutter client NEVER receives permission
   * to create the rewarded-ad database record.
   * ==========================================================
   */

  if (request.method !== "GET" &&
      request.method !== "POST") {
    return response(
      "Method not allowed",
      405,
    );
  }

  if (!supabaseUrl ||
      !serviceRoleKey) {
    console.error(
      "Supabase environment variables are missing.",
    );

    return response(
      "Server configuration error",
      500,
    );
  }

  if (!privateKey) {
    console.error(
      "LEVELPLAY_S2S_PRIVATE_KEY is missing.",
    );

    return response(
      "Server configuration error",
      500,
    );
  }

  try {
    /*
     * --------------------------------------------------------
     * Read LevelPlay callback parameters.
     * --------------------------------------------------------
     *
     * Support both names used by LevelPlay integrations:
     *
     * applicationUserId
     * dynamicUserId
     * userId
     */

    const url =
      new URL(request.url);

    const params =
      url.searchParams;

    let body:
      Record<string, unknown> = {};

    if (request.method === "POST") {
      const contentType =
        request.headers.get(
          "content-type",
        ) ?? "";

      if (
        contentType.includes(
          "application/json",
        )
      ) {
        body =
          await request.json()
            .catch(
              () => ({}),
            );
      } else {
        const text =
          await request.text();

        const form =
          new URLSearchParams(text);

        form.forEach(
          (value, key) => {
            body[key] = value;
          },
        );
      }
    }

    const getParam = (
      ...names: string[]
    ): string => {
      for (const name of names) {
        const queryValue =
          params.get(name);

        if (
          queryValue !== null &&
          queryValue.trim() !== ""
        ) {
          return clean(queryValue);
        }

        const bodyValue =
          body[name];

        if (
          bodyValue !== undefined &&
          bodyValue !== null &&
          String(bodyValue).trim() !== ""
        ) {
          return clean(
            String(bodyValue),
          );
        }
      }

      return "";
    };

    const userId =
      getParam(
        "dynamicUserId",
        "applicationUserId",
        "appUserId",
        "userId",
      );

    const eventId =
      getParam(
        "eventId",
        "EVENT_ID",
      );

    const rewards =
      getParam(
        "rewards",
        "REWARDS",
      );

    const timestamp =
      getParam(
        "timestamp",
        "TIMESTAMP",
      );

    const signature =
      getParam(
        "signature",
        "SIGNATURE",
      );

    const appKey =
      getParam(
        "appKey",
        "APP_KEY",
      );

    /*
     * --------------------------------------------------------
     * Validate mandatory LevelPlay parameters.
     * --------------------------------------------------------
     */

    if (!userId) {
      return response(
        "Missing user ID",
        400,
      );
    }

    if (!eventId) {
      return response(
        "Missing event ID",
        400,
      );
    }

    if (!rewards) {
      return response(
        "Missing rewards",
        400,
      );
    }

    if (!timestamp) {
      return response(
        "Missing timestamp",
        400,
      );
    }

    if (!signature) {
      return response(
        "Missing signature",
        400,
      );
    }

    /*
     * LevelPlay dynamicUserId must be 1-64 characters.
     *
     * The Supabase user UUID is 36 characters,
     * so it fits safely.
     */

    if (
      userId.length < 1 ||
      userId.length > 64
    ) {
      return response(
        "Invalid user ID",
        400,
      );
    }

    if (
      eventId.length < 1 ||
      eventId.length > 255
    ) {
      return response(
        "Invalid event ID",
        400,
      );
    }

    /*
     * --------------------------------------------------------
     * Optional App Key validation.
     * --------------------------------------------------------
     *
     * If LEVELPLAY_APP_KEY is configured as a Supabase
     * secret, reject callbacks belonging to another app.
     *
     * If it is not configured, signature validation remains
     * the primary authentication mechanism.
     */

    if (
      expectedAppKey &&
      appKey &&
      appKey !== expectedAppKey
    ) {
      console.error(
        "LevelPlay S2S app key mismatch.",
      );

      return response(
        "Invalid app key",
        403,
      );
    }

    /*
     * --------------------------------------------------------
     * Validate USER_ID as a Supabase UUID.
     * --------------------------------------------------------
     */

    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    if (!uuidPattern.test(userId)) {
      return response(
        "Invalid user ID",
        400,
      );
    }

    /*
     * --------------------------------------------------------
     * Validate reward value.
     * --------------------------------------------------------
     *
     * LevelPlay sends the reward amount in the callback.
     *
     * IMPORTANT:
     *
     * We DO NOT use this client/network value to determine
     * the FAN mining boost.
     *
     * The database function fixes the mining boost at:
     *
     *             +0.10 FAN/H
     *
     * This prevents someone from changing the reward amount
     * to manipulate the mining rate.
     */

    const rewardNumber =
      Number(rewards);

    if (
      !Number.isFinite(
        rewardNumber,
      ) ||
      rewardNumber <= 0
    ) {
      return response(
        "Invalid reward amount",
        400,
      );
    }

    /*
     * --------------------------------------------------------
     * Validate timestamp.
     * --------------------------------------------------------
     *
     * LevelPlay uses:
     *
     * YYYYMMDDHHMM
     *
     * Example:
     *
     * 202609101245
     *
     * We allow a reasonable clock window to prevent replaying
     * very old signed callbacks.
     */

    if (
      !/^\d{12}$/.test(
        timestamp,
      )
    ) {
      return response(
        "Invalid timestamp",
        400,
      );
    }

    const year =
      Number(
        timestamp.substring(
          0,
          4,
        ),
      );

    const month =
      Number(
        timestamp.substring(
          4,
          6,
        ),
      );

    const day =
      Number(
        timestamp.substring(
          6,
          8,
        ),
      );

    const hour =
      Number(
        timestamp.substring(
          8,
          10,
        ),
      );

    const minute =
      Number(
        timestamp.substring(
          10,
          12,
        ),
      );

    const callbackDate =
      new Date(
        Date.UTC(
          year,
          month - 1,
          day,
          hour,
          minute,
        ),
      );

    if (
      Number.isNaN(
        callbackDate.getTime(),
      )
    ) {
      return response(
        "Invalid timestamp",
        400,
      );
    }

    /*
     * --------------------------------------------------------
     * LEVELPLAY SIGNATURE VALIDATION
     * --------------------------------------------------------
     *
     * Unity LevelPlay / ironSource formula:
     *
     * MD5(
     *   TIMESTAMP +
     *   EVENT_ID +
     *   USER_ID +
     *   REWARDS +
     *   PRIVATE_KEY
     * )
     *
     * USER_ID is the decoded value.
     */

    const signaturePayload =
      timestamp +
      eventId +
      userId +
      rewards +
      privateKey;

    const expectedSignature =
      md5(
        signaturePayload,
      );

    if (
      !safeEqual(
        expectedSignature,
        signature,
      )
    ) {
      console.error(
        "LevelPlay S2S signature validation failed.",
      );

      return response(
        "Invalid signature",
        403,
      );
    }

    /*
     * --------------------------------------------------------
     * EVENT ID DUPLICATE PROTECTION
     * --------------------------------------------------------
     *
     * The database already has:
     *
     * UNIQUE(levelplay_event_id)
     *
     * and record_levelplay_reward() also checks it.
     *
     * Therefore an S2S retry cannot grant the same ad twice.
     *
     * We deliberately let the database remain authoritative.
     */

    /*
     * --------------------------------------------------------
     * SERVER-SIDE REWARD
     * --------------------------------------------------------
     *
     * The callback does NOT directly update:
     *
     * profiles.fan_balance
     *
     * and does NOT trust:
     *
     * rewards
     *
     * for the FAN mining rate.
     *
     * Instead it calls the existing trusted RPC:
     *
     * record_levelplay_reward(uuid, text)
     *
     * which already enforces:
     *
     * +0.10 FAN/H
     * maximum 7 ads
     * active mining session
     * unique EVENT_ID
     * server timestamp
     */

    const {
      data,
      error,
    } = await admin.rpc(
      "record_levelplay_reward",
      {
        p_user_id: userId,
        p_event_id: eventId,
      },
    );

    if (error) {
      /*
       * If the database reports that this event was already
       * processed, returning 200 + EVENT_ID:OK prevents
       * unnecessary LevelPlay retries.
       */

      const message =
        String(
          error.message ??
            "",
        );

      if (
        message
          .toLowerCase()
          .includes(
            "already processed",
          )
      ) {
        return response(
          `${eventId}:OK`,
          200,
        );
      }

      console.error(
        "LevelPlay S2S database reward error:",
        error,
      );

      /*
       * Do NOT acknowledge failed reward processing.
       *
       * LevelPlay can retry the callback.
       */

      return response(
        "Reward processing failed",
        500,
      );
    }

    /*
     * --------------------------------------------------------
     * SUCCESS
     * --------------------------------------------------------
     *
     * LevelPlay requires HTTP 200 and EVENT_ID:OK.
     */

    console.log(
      "LevelPlay S2S reward processed:",
      JSON.stringify(
        data,
      ),
    );

    return response(
      `${eventId}:OK`,
      200,
    );
  } catch (error) {
    console.error(
      "LevelPlay S2S callback error:",
      error,
    );

    /*
     * Do not acknowledge unexpected failures.
     * LevelPlay will retry.
     */

    return response(
      "Internal server error",
      500,
    );
  }
});
