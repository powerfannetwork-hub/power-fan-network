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
      "Content-Type":
        "text/plain; charset=utf-8",
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

  for (
    let i = 0;
    i < left.length;
    i++
  ) {
    result |=
      left.charCodeAt(i) ^
      right.charCodeAt(i);
  }

  return result === 0;
}

function isValidUuid(
  value: string,
): boolean {
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

  const year =
    Number(timestamp.substring(0, 4));

  const month =
    Number(timestamp.substring(4, 6));

  const day =
    Number(timestamp.substring(6, 8));

  const hour =
    Number(timestamp.substring(8, 10));

  const minute =
    Number(timestamp.substring(10, 12));

  if (
    month < 1 ||
    month > 12 ||
    day < 1 ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return false;
  }

  const date =
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
      date.getTime(),
    )
  ) {
    return false;
  }

  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day &&
    date.getUTCHours() === hour &&
    date.getUTCMinutes() === minute
  );
}

Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    /*
     * ==========================================================
     * POWER FAN NETWORK
     * LEVELPLAY S2S REWARDED AD CALLBACK
     * ==========================================================
     *
     * Security model:
     *
     * 1. LevelPlay private-key signature
     * 2. USER_ID UUID validation
     * 3. EVENT_ID validation
     * 4. Optional APP_KEY validation
     * 5. Supabase service_role RPC
     * 6. Database duplicate EVENT_ID protection
     * 7. Database active-session validation
     * 8. Database maximum 7 ads/session
     * 9. Database fixed +0.10 FAN/H reward rate
     *
     * The Flutter client cannot call
     * record_levelplay_reward().
     * ==========================================================
     */

    if (
      request.method !== "GET" &&
      request.method !== "POST"
    ) {
      return response(
        "Method not allowed",
        405,
      );
    }

    if (
      !supabaseUrl ||
      !serviceRoleKey
    ) {
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
       * Parse request
       * --------------------------------------------------------
       */

      const url =
        new URL(request.url);

      const queryParams =
        url.searchParams;

      const body:
        Record<string, unknown> = {};

      if (
        request.method === "POST"
      ) {
        const contentType =
          request.headers.get(
            "content-type",
          ) ?? "";

        if (
          contentType
            .toLowerCase()
            .includes(
              "application/json",
            )
        ) {
          const json =
            await request
              .json()
              .catch(
                () => ({}),
              );

          if (
            json &&
            typeof json === "object" &&
            !Array.isArray(json)
          ) {
            Object.assign(
              body,
              json,
            );
          }
        } else {
          const text =
            await request.text();

          const form =
            new URLSearchParams(
              text,
            );

          form.forEach(
            (
              value,
              key,
            ) => {
              body[key] = value;
            },
          );
        }
      }

      /*
       * --------------------------------------------------------
       * Parameter reader
       * --------------------------------------------------------
       */

      const getParam = (
        ...names: string[]
      ): string => {
        for (
          const name of names
        ) {
          const queryValue =
            queryParams.get(
              name,
            );

          if (
            queryValue !== null &&
            queryValue.trim() !== ""
          ) {
            return clean(
              queryValue,
            );
          }

          const bodyValue =
            body[name];

          if (
            bodyValue !== undefined &&
            bodyValue !== null &&
            String(
              bodyValue,
            ).trim() !== ""
          ) {
            return clean(
              String(bodyValue),
            );
          }
        }

        return "";
      };

      /*
       * --------------------------------------------------------
       * LevelPlay parameters
       * --------------------------------------------------------
       *
       * LevelPlay documentation commonly uses:
       *
       * applicationUserId
       * appUserId
       *
       * We support both.
       */

      const userId =
        getParam(
          "applicationUserId",
          "appUserId",
          "dynamicUserId",
          "userId",
          "userid",
          "user_id",
          "USER_ID",
        );

      const eventId =
        getParam(
          "eventId",
          "eventID",
          "event_id",
          "EVENT_ID",
        );

      const rewards =
        getParam(
          "rewards",
          "reward",
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
       * Required parameter validation
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
       * --------------------------------------------------------
       * USER_ID validation
       * --------------------------------------------------------
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

      if (!isValidUuid(userId)) {
        return response(
          "Invalid user ID",
          400,
        );
      }

      /*
       * --------------------------------------------------------
       * EVENT_ID validation
       * --------------------------------------------------------
       */

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
       * REWARDS validation
       * --------------------------------------------------------
       *
       * This value is authenticated by the LevelPlay
       * signature, but is NOT trusted for FAN calculation.
       *
       * Database always controls the actual mining boost:
       *
       * +0.10 FAN/H
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
       * TIMESTAMP validation
       * --------------------------------------------------------
       *
       * Expected:
       *
       * YYYYMMDDHHMM
       *
       * Example:
       *
       * 202609101245
       * --------------------------------------------------------
       */

      if (
        !isValidLevelPlayTimestamp(
          timestamp,
        )
      ) {
        return response(
          "Invalid timestamp",
          400,
        );
      }

      /*
       * --------------------------------------------------------
       * OPTIONAL APP KEY
       * --------------------------------------------------------
       *
       * If LEVELPLAY_APP_KEY is configured on the server,
       * LevelPlay MUST provide a matching appKey.
       */

      if (expectedAppKey) {
        if (!appKey) {
          console.error(
            "LevelPlay app key is missing.",
          );

          return response(
            "Missing app key",
            403,
          );
        }

        if (
          !safeEqual(
            appKey,
            expectedAppKey,
          )
        ) {
          console.error(
            "LevelPlay app key mismatch.",
          );

          return response(
            "Invalid app key",
            403,
          );
        }
      }

      /*
       * --------------------------------------------------------
       * LEVELPLAY SIGNATURE
       * --------------------------------------------------------
       *
       * Official formula:
       *
       * MD5(
       *   TIMESTAMP +
       *   EVENT_ID +
       *   USER_ID +
       *   REWARDS +
       *   PRIVATE_KEY
       * )
       *
       * URLSearchParams already gives us the decoded USER_ID.
       * --------------------------------------------------------
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
       * TRUSTED DATABASE RPC
       * --------------------------------------------------------
       *
       * Existing SQL function:
       *
       * record_levelplay_reward(
       *   uuid,
       *   text
       * )
       *
       * It already controls:
       *
       * - duplicate EVENT_ID
       * - active mining session
       * - maximum 7 ads
       * - +0.10 FAN/H
       * - server timestamp
       * - mining-rate update
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
        const message =
          String(
            error.message ?? "",
          );

        /*
         * Normally duplicate EVENT_ID is handled inside
         * record_levelplay_reward() and returned as JSON.
         *
         * This fallback handles a duplicate-related database
         * error without causing unnecessary LevelPlay retries.
         */

        if (
          message
            .toLowerCase()
            .includes(
              "already processed",
            )
        ) {
          console.log(
            "LevelPlay duplicate event acknowledged:",
            eventId,
          );

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
         * Do not acknowledge failed processing.
         *
         * LevelPlay can retry the event.
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
       */

      console.log(
        "LevelPlay S2S reward processed:",
        JSON.stringify(
          data,
        ),
      );

      /*
       * LevelPlay requires:
       *
       * HTTP 200
       * EVENT_ID:OK
       */

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
       * Unexpected error:
       * do NOT acknowledge.
       *
       * LevelPlay may retry.
       */

      return response(
        "Internal server error",
        500,
      );
    }
  },
);
