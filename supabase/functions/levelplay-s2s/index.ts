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
    day > 31 ||
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
     * Supports:
     *
     * 1. NORMAL MINING BOOST ADS
     *
     * 2. CLAIM ADS
     *
     * NORMAL AD:
     *
     *   +0.10 FAN/H
     *   maximum 7 per session
     *
     * CLAIM AD:
     *
     *   verifies claim permission only
     *   does NOT add FAN immediately
     *   does NOT extend mining
     *   does NOT change mining rate
     *
     * SECURITY:
     *
     *   LevelPlay signature
     *   App key
     *   UUID validation
     *   EVENT_ID validation
     *   Supabase service_role
     *   Database duplicate protection
     *   Database session validation
     *
     * The Flutter client cannot call either S2S function.
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


    if (!expectedAppKey) {
      console.error(
        "LEVELPLAY_APP_KEY is missing.",
      );

      return response(
        "Server configuration error",
        500,
      );
    }


    try {

      /*
       * ========================================================
       * PARSE REQUEST
       * ========================================================
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
       * ========================================================
       * PARAMETER READER
       * ========================================================
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
       * ========================================================
       * LEVELPLAY PARAMETERS
       * ========================================================
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
       * ========================================================
       * REQUIRED PARAMETER VALIDATION
       * ========================================================
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


      if (!appKey) {
        console.error(
          "LevelPlay app key is missing.",
        );

        return response(
          "Missing app key",
          403,
        );
      }


      /*
       * ========================================================
       * USER ID VALIDATION
       * ========================================================
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
       * ========================================================
       * EVENT ID VALIDATION
       * ========================================================
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
       * ========================================================
       * REWARD VALIDATION
       * ========================================================
       *
       * The reward value is authenticated by LevelPlay,
       * but the application NEVER trusts it for FAN calculation.
       *
       * Database controls the actual reward:
       *
       * NORMAL AD = +0.10 FAN/H
       *
       * CLAIM AD = no immediate FAN
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
       * ========================================================
       * TIMESTAMP VALIDATION
       * ========================================================
       *
       * Expected:
       *
       * YYYYMMDDHHMM
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
       * ========================================================
       * APP KEY VALIDATION
       * ========================================================
       */

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


      /*
       * ========================================================
       * LEVELPLAY SIGNATURE VALIDATION
       * ========================================================
       *
       * Formula:
       *
       * MD5(
       *   TIMESTAMP +
       *   EVENT_ID +
       *   USER_ID +
       *   REWARDS +
       *   PRIVATE_KEY
       * )
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
       * ========================================================
       * STEP 1
       * CHECK WHETHER THIS EVENT BELONGS TO A CLAIM AD
       * ========================================================
       *
       * We intentionally check the claim request first.
       *
       * If the user has a valid pending claim-ad request,
       * the verified LevelPlay event unlocks that claim.
       *
       * No FAN is added at this point.
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


      /*
       * ========================================================
       * CLAIM AD SUCCESS
       * ========================================================
       */

      if (
        !claimError &&
        claimData &&
        typeof claimData === "object"
      ) {

        const claimResult =
          claimData as Record<
            string,
            unknown
          >;


        if (
          claimResult.success === true &&
          claimResult.verified === true
        ) {

          console.log(
            "LevelPlay CLAIM AD verified:",
            JSON.stringify(
              claimData,
            ),
          );


          return response(
            `${eventId}:OK`,
            200,
          );

        }

      }


      /*
       * ========================================================
       * CLAIM DUPLICATE
       * ========================================================
       *
       * A previously verified claim event should still receive
       * HTTP 200 so LevelPlay does not repeatedly retry it.
       */

      if (
        !claimError &&
        claimData &&
        typeof claimData === "object"
      ) {

        const claimResult =
          claimData as Record<
            string,
            unknown
          >;


        if (
          claimResult.duplicate === true
        ) {

          console.log(
            "LevelPlay duplicate CLAIM AD:",
            eventId,
          );


          return response(
            `${eventId}:OK`,
            200,
          );

        }

      }


      /*
       * ========================================================
       * STEP 2
       * NORMAL MINING AD
       * ========================================================
       *
       * If there was no valid claim request,
       * process this event as a normal mining boost ad.
       *
       * Database decides:
       *
       *   active session
       *   maximum 7 ads
       *   duplicate protection
       *   +0.10 FAN/H
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


      /*
       * ========================================================
       * NORMAL AD DATABASE ERROR
       * ========================================================
       */

      if (normalError) {

        const message =
          String(
            normalError.message ?? "",
          );


        /*
         * Duplicate event fallback.
         */

        if (
          message
            .toLowerCase()
            .includes(
              "already processed",
            )
        ) {

          console.log(
            "LevelPlay duplicate NORMAL AD acknowledged:",
            eventId,
          );


          return response(
            `${eventId}:OK`,
            200,
          );

        }


        console.error(
          "LevelPlay normal ad database error:",
          normalError,
        );


        /*
         * Do not acknowledge a failed reward.
         *
         * LevelPlay may retry.
         */

        return response(
          "Reward processing failed",
          500,
        );

      }


      /*
       * ========================================================
       * NORMAL AD SUCCESS
       * ========================================================
       */

      console.log(
        "LevelPlay NORMAL AD reward processed:",
        JSON.stringify(
          normalData,
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
       * Unexpected server error.
       *
       * Do NOT acknowledge the callback.
       *
       * LevelPlay can retry.
       */

      return response(
        "Internal server error",
        500,
      );

    }

  },
);
