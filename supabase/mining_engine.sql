-- ============================================================
-- POWER FAN NETWORK
-- FINAL MINING ENGINE
-- CORRECTED MINING + BOOST ADS ENGINE
-- ============================================================
--
-- BASE MINING RATE:
--   0.20 FAN/H
--
-- SESSION:
--   24 HOURS
--
-- BASE SESSION REWARD:
--   4.80 FAN
--
-- NORMAL REWARDED ADS:
--   +0.10 FAN/H PER VERIFIED AD
--   MAX 7 ADS PER SESSION
--   MAX BOOST = +0.70 FAN/H
--   BOOST STARTS AT EXACT SERVER watched_at
--   NO RETROACTIVE BOOST
--   NO SESSION EXTENSION
--
-- CLAIM AD:
--   REQUIRED BEFORE CLAIM
--   SEPARATE FROM NORMAL BOOST ADS
--   DOES NOT CHANGE MINING RATE
--   DOES NOT EXTEND SESSION
--   VERIFIED BY LEVELPLAY S2S
--
-- REFERRAL:
--   +0.02 FAN/H PER ACTIVE REFERRAL
--
-- SERVER TIME = SOURCE OF TRUTH
-- CLIENT CANNOT CREATE REWARDS
-- ============================================================


-- ============================================================
-- 1. PROFILE COLUMNS
-- ============================================================

alter table public.profiles
add column if not exists last_mining_at timestamptz;

alter table public.profiles
add column if not exists inactivity_penalty_at timestamptz;

create index if not exists idx_profiles_last_mining_at
on public.profiles(last_mining_at)
where last_mining_at is not null;


-- ============================================================
-- 2. LEVELPLAY EVENT TRACKING
-- ============================================================

alter table public.ad_rewards
add column if not exists levelplay_event_id text;

create unique index if not exists idx_ad_rewards_levelplay_event_id
on public.ad_rewards(levelplay_event_id)
where levelplay_event_id is not null;


-- ============================================================
-- 3. CLAIM AD REQUEST TABLE
-- ============================================================

create table if not exists public.mining_claim_ad_requests (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    session_id uuid not null
        references public.mining_sessions(id)
        on delete cascade,

    created_at timestamptz not null default now(),

    expires_at timestamptz not null,

    verified_at timestamptz,

    levelplay_event_id text,

    consumed_at timestamptz,

    status text not null default 'pending',

    constraint mining_claim_ad_requests_status_check
    check (
        status in (
            'pending',
            'verified',
            'consumed',
            'expired',
            'cancelled'
        )
    )
);


create index if not exists idx_claim_ad_requests_user
on public.mining_claim_ad_requests(user_id);


create index if not exists idx_claim_ad_requests_session
on public.mining_claim_ad_requests(session_id);


create index if not exists idx_claim_ad_requests_status
on public.mining_claim_ad_requests(status);


create unique index if not exists idx_claim_ad_requests_levelplay_event
on public.mining_claim_ad_requests(levelplay_event_id)
where levelplay_event_id is not null;


create unique index if not exists idx_one_open_claim_ad_per_user
on public.mining_claim_ad_requests(user_id)
where status in ('pending', 'verified');


-- ============================================================
-- 4. ACTIVE REFERRALS
-- ============================================================

create or replace function public.calculate_active_referrals(
    p_user_id uuid
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer
    from public.profiles referred
    where referred.referred_by = p_user_id
      and exists (
          select 1
          from public.mining_sessions rs
          where rs.user_id = referred.id
            and rs.claimed = false
            and rs.started_at < now()
            and rs.ends_at > now()
      );
$$;


-- ============================================================
-- 5. TIME-WEIGHTED BOOST AD REWARD
-- ============================================================
--
-- IMPORTANT:
--
-- Every verified boost ad starts exactly at watched_at.
--
-- Example:
--
-- Session starts 10:00
-- Ad watched 14:00
--
-- +0.10 FAN/H applies from 14:00
-- until session ends.
--
-- It does NOT apply from 10:00.
--
-- Maximum 7 ads.
-- ============================================================

create or replace function public.calculate_ad_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
    v_reward numeric := 0;
begin

    select coalesce(
        sum(
            (
                extract(
                    epoch from (
                        p_ends_at -
                        greatest(
                            ar.watched_at,
                            p_started_at
                        )
                    )
                ) / 3600.0
            )
            *
            greatest(
                least(
                    coalesce(ar.reward_amount, 0.10),
                    0.10
                ),
                0
            )
        ),
        0
    )
    into v_reward
    from (
        select
            reward_amount,
            watched_at
        from public.ad_rewards
        where user_id = p_user_id

          and session_id in (
              select id
              from public.mining_sessions
              where user_id = p_user_id
                and started_at = p_started_at
                and ends_at = p_ends_at
          )

          and watched_at >= p_started_at
          and watched_at < p_ends_at

        order by watched_at asc

        limit 7
    ) ar;


    return round(
        greatest(v_reward, 0),
        8
    );

end;
$function$;


-- ============================================================
-- 6. TIME-WEIGHTED REFERRAL REWARD
-- ============================================================

create or replace function public.calculate_referral_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
    v_reward numeric := 0;
begin

    select coalesce(
        sum(
            (
                extract(
                    epoch from (
                        least(
                            rs.ends_at,
                            p_ends_at
                        )
                        -
                        greatest(
                            rs.started_at,
                            p_started_at,
                            r.activated_at
                        )
                    )
                ) / 3600.0
            )
            * 0.02
        ),
        0
    )
    into v_reward

    from public.profiles referred

    join public.mining_sessions rs
      on rs.user_id = referred.id

    join public.referrals r
      on r.referred_id = referred.id
     and r.referrer_id = p_user_id

    where referred.referred_by = p_user_id

      and r.activated_at is not null

      and rs.claimed = false

      and rs.started_at < p_ends_at

      and rs.ends_at > p_started_at

      and greatest(
          rs.started_at,
          p_started_at,
          r.activated_at
      )
      <
      least(
          rs.ends_at,
          p_ends_at
      );


    return round(
        greatest(v_reward, 0),
        8
    );

end;
$function$;


-- ============================================================
-- 7. INACTIVITY PENALTY
-- ============================================================

create or replace function public.apply_inactivity_penalty(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare

    v_last_mining timestamptz;

    v_penalty_at timestamptz;

    v_now timestamptz := now();

    v_elapsed_hours numeric;

    v_due_periods integer;

    v_penalty numeric;

    v_old_balance numeric;

    v_new_balance numeric;

begin

    select
        last_mining_at,
        inactivity_penalty_at,
        coalesce(fan_balance, 0)

    into
        v_last_mining,
        v_penalty_at,
        v_old_balance

    from public.profiles

    where id = p_user_id

    for update;


    if not found then

        return jsonb_build_object(
            'success', false,
            'message', 'Profile not found'
        );

    end if;


    if v_last_mining is null then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance
        );

    end if;


    v_elapsed_hours :=
        extract(
            epoch from (
                v_now - v_last_mining
            )
        ) / 3600.0;


    if v_elapsed_hours <= 72 then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance,
            'inactive_hours',
            round(v_elapsed_hours, 2)
        );

    end if;


    if v_penalty_at is null then

        v_due_periods :=
            floor(
                (v_elapsed_hours - 72) / 24
            )::integer;

    else

        v_due_periods :=
            floor(
                extract(
                    epoch from (
                        v_now - v_penalty_at
                    )
                ) / 86400.0
            )::integer;

    end if;


    if v_due_periods <= 0 then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance,
            'inactive_hours',
            round(v_elapsed_hours, 2)
        );

    end if;


    v_penalty :=
        v_due_periods * 20.0;


    v_new_balance :=
        greatest(
            coalesce(v_old_balance, 0) - v_penalty,
            0
        );


    update public.profiles

    set
        fan_balance = v_new_balance,

        inactivity_penalty_at =
            coalesce(
                v_penalty_at,
                last_mining_at
                + interval '72 hours'
            )
            +
            (
                v_due_periods
                * interval '24 hours'
            ),

        updated_at = v_now

    where id = p_user_id;


    return jsonb_build_object(
        'success', true,
        'penalty_applied', true,
        'penalty_periods', v_due_periods,
        'penalty', v_penalty,
        'old_balance', v_old_balance,
        'fan_balance', v_new_balance,
        'inactive_hours',
        round(v_elapsed_hours, 2)
    );

end;
$function$;


-- ============================================================
-- 8. CURRENT MINING RATE
-- ============================================================
--
-- FIXED BOOST ADS WATCHED:
--
-- ads_watched is calculated ONLY from the currently active
-- mining session.
--
-- Old sessions cannot carry ads into the new session.
--
-- Maximum = 7.
--
-- Rate:
--
-- 0.20
-- + ads * 0.10
-- + active referrals * 0.02
-- ============================================================

create or replace function public.get_user_mining_rate()
returns numeric
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_ads integer := 0;

    v_referrals integer := 0;

    v_rate numeric(12,4);

begin

    v_user_id := auth.uid();


    if v_user_id is null then

        raise exception 'Authentication required';

    end if;


    select *
    into v_session

    from public.mining_sessions

    where user_id = v_user_id

      and claimed = false

      and started_at <= now()

      and ends_at > now()

    order by started_at desc

    limit 1;


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    if v_session.id is not null then

        select count(*)::integer
        into v_ads

        from public.ad_rewards

        where user_id = v_user_id

          and session_id = v_session.id

          and watched_at >= v_session.started_at

          and watched_at < v_session.ends_at;


        v_ads :=
            least(
                greatest(
                    coalesce(v_ads, 0),
                    0
                ),
                7
            );

    else

        v_ads := 0;

    end if;


    v_rate :=
        round(
            0.20
            + (v_ads * 0.10)
            + (v_referrals * 0.02),
            4
        );


    update public.profiles

    set
        mining_rate = v_rate,

        active_referrals = v_referrals,

        daily_ads_watched = v_ads,

        ad_boost =
            round(
                v_ads * 0.10,
                4
            ),

        updated_at = now()

    where id = v_user_id;


    return v_rate;

end;
$function$;


-- ============================================================
-- 9. USER-ID RATE WRAPPER
-- ============================================================

create or replace function public.get_user_mining_rate(
    p_user_id uuid
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.get_user_mining_rate();

end;
$$;


-- ============================================================
-- 10. START MINING
-- ============================================================
--
-- IMPORTANT:
--
-- If an active session exists:
--   return that same session.
--
-- If a completed unclaimed session exists:
--   DO NOT create another session.
--   DO NOT auto-claim.
--   Return claim_required=true.
--
-- Only after successful claim can a NEW session be created.
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_existing public.mining_sessions%rowtype;

    v_session_id uuid;

    v_started_at timestamptz;

    v_ends_at timestamptz;

    v_referrals integer;

    v_ads integer;

    v_rate numeric(12,4);

    v_penalty_result jsonb;

begin

    v_user_id := auth.uid();


    if v_user_id is null then

        raise exception 'Authentication required';

    end if;


    perform 1

    from public.profiles

    where id = v_user_id

    for update;


    if not found then

        raise exception 'Profile not found';

    end if;


    v_penalty_result :=
        public.apply_inactivity_penalty(
            v_user_id
        );


    select *

    into v_existing

    from public.mining_sessions

    where user_id = v_user_id

      and claimed = false

    order by started_at desc

    limit 1

    for update;


    -- ========================================================
    -- EXISTING SESSION
    -- ========================================================

    if found then


        -- ====================================================
        -- ACTIVE SESSION
        -- ====================================================

        if now() < v_existing.ends_at then


            select count(*)::integer

            into v_ads

            from public.ad_rewards

            where user_id = v_user_id

              and session_id = v_existing.id

              and watched_at >= v_existing.started_at

              and watched_at < v_existing.ends_at;


            v_ads :=
                least(
                    greatest(
                        coalesce(v_ads, 0),
                        0
                    ),
                    7
                );


            v_referrals :=
                public.calculate_active_referrals(
                    v_user_id
                );


            v_rate :=
                round(
                    0.20
                    + (v_ads * 0.10)
                    + (v_referrals * 0.02),
                    4
                );


            update public.profiles

            set
                mining_active = true,

                mining_started_at =
                    v_existing.started_at,

                mining_ends_at =
                    v_existing.ends_at,

                mining_rate =
                    v_rate,

                active_referrals =
                    v_referrals,

                daily_ads_watched =
                    v_ads,

                ad_boost =
                    round(
                        v_ads * 0.10,
                        4
                    ),

                updated_at = now()

            where id = v_user_id;


            return jsonb_build_object(

                'success', true,

                'already_active', true,

                'claim_required', false,

                'session_id',
                    v_existing.id,

                'started_at',
                    v_existing.started_at,

                'ends_at',
                    v_existing.ends_at,

                'mining_rate',
                    v_rate,

                'ads_watched',
                    v_ads,

                'ad_boost',
                    round(v_ads * 0.10, 4),

                'active_referrals',
                    v_referrals,

                'status',
                    'active'

            );

        end if;


        -- ====================================================
        -- COMPLETED SESSION
        -- ====================================================
        --
        -- DO NOT AUTO CLAIM.
        --
        -- The claim advertisement is mandatory.
        -- ====================================================

        update public.profiles

        set
            mining_active = false,

            mining_started_at = null,

            mining_ends_at = null,

            daily_ads_watched = 0,

            ad_boost = 0,

            updated_at = now()

        where id = v_user_id;


        return jsonb_build_object(

            'success', false,

            'already_active', false,

            'claim_required', true,

            'expired', true,

            'session_id',
                v_existing.id,

            'started_at',
                v_existing.started_at,

            'ends_at',
                v_existing.ends_at,

            'status',
                'claimable',

            'message',
                'Your 24-hour mining session is complete and ready to claim.'

        );

    end if;


    -- ========================================================
    -- CREATE NEW SESSION
    -- ========================================================

    v_started_at :=
        now();


    v_ends_at :=
        v_started_at
        + interval '24 hours';


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_rate :=
        round(
            0.20
            + (v_referrals * 0.02),
            4
        );


    insert into public.mining_sessions (

        user_id,

        started_at,

        ends_at,

        mining_rate,

        claimed,

        reward_amount

    )

    values (

        v_user_id,

        v_started_at,

        v_ends_at,

        v_rate,

        false,

        0

    )

    returning id

    into v_session_id;


    update public.profiles

    set
        mining_active = true,

        mining_started_at =
            v_started_at,

        mining_ends_at =
            v_ends_at,

        mining_rate =
            v_rate,

        active_referrals =
            v_referrals,

        daily_ads_watched = 0,

        ad_boost = 0,

        last_mining_at =
            v_started_at,

        inactivity_penalty_at = null,

        updated_at = now()

    where id = v_user_id;


    return jsonb_build_object(

        'success', true,

        'already_active', false,

        'claim_required', false,

        'session_id',
            v_session_id,

        'started_at',
            v_started_at,

        'ends_at',
            v_ends_at,

        'mining_rate',
            v_rate,

        'active_referrals',
            v_referrals,

        'ads_watched',
            0,

        'ad_boost',
            0,

        'status',
            'active',

        'inactivity_penalty',
            coalesce(
                v_penalty_result -> 'penalty',
                '0'::jsonb
            )

    );

end;
$function$;


-- ============================================================
-- 11. START MINING USER WRAPPER
-- ============================================================

create or replace function public.start_mining(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.start_mining();

end;
$$;


-- ============================================================
-- 12. GET ACTIVE MINING
-- ============================================================
--
-- This is the MAIN server state used by the app.
--
-- ACTIVE:
--   remaining_seconds > 0
--
-- EXPIRED:
--   claimable = true
--
-- NO SESSION:
--   active = false
--   claimable = false
--
-- ads_watched is ALWAYS for this exact session.
-- ============================================================

create or replace function public.get_active_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_ads integer := 0;

    v_referrals integer := 0;

    v_rate numeric(12,4);

    v_reward numeric(30,8);

    v_elapsed numeric;

    v_remaining numeric;

    v_until_now timestamptz;

begin

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception 'Authentication required';

    end if;


    select *

    into v_session

    from public.mining_sessions

    where user_id = v_user_id

      and claimed = false

    order by started_at desc

    limit 1

    for update;


    -- ========================================================
    -- NO SESSION
    -- ========================================================

    if not found then


        update public.profiles

        set
            mining_active = false,

            mining_started_at = null,

            mining_ends_at = null,

            daily_ads_watched = 0,

            ad_boost = 0,

            mining_rate = 0.20,

            updated_at = now()

        where id = v_user_id;


        return jsonb_build_object(

            'success', true,

            'active', false,

            'mining_active', false,

            'expired', false,

            'claimable', false,

            'reward', 0,

            'mining_rate', 0.20,

            'ads_watched', 0,

            'ad_boost', 0,

            'active_referrals', 0

        );

    end if;


    -- ========================================================
    -- EXPIRED / CLAIMABLE
    -- ========================================================

    if now() >= v_session.ends_at then


        update public.profiles

        set
            mining_active = false,

            mining_started_at = null,

            mining_ends_at = null,

            daily_ads_watched = 0,

            ad_boost = 0,

            updated_at = now()

        where id = v_user_id;


        return jsonb_build_object(

            'success', true,

            'active', false,

            'mining_active', false,

            'expired', true,

            'claimable', true,

            'session_id',
                v_session.id,

            'started_at',
                v_session.started_at,

            'ends_at',
                v_session.ends_at,

            'message',
                'Your 24-hour mining session is complete and ready to claim.'

        );

    end if;


    -- ========================================================
    -- ACTIVE SESSION
    -- ========================================================

    v_until_now :=
        least(
            now(),
            v_session.ends_at
        );


    -- ========================================================
    -- COUNT BOOST ADS FOR THIS SESSION ONLY
    -- ========================================================

    select count(*)::integer

    into v_ads

    from public.ad_rewards

    where user_id = v_user_id

      and session_id = v_session.id

      and watched_at >= v_session.started_at

      and watched_at < v_session.ends_at;


    v_ads :=
        least(
            greatest(
                coalesce(v_ads, 0),
                0
            ),
            7
        );


    -- ========================================================
    -- ACTIVE REFERRALS
    -- ========================================================

    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    -- ========================================================
    -- CURRENT RATE
    -- ========================================================

    v_rate :=
        round(
            0.20
            + (v_ads * 0.10)
            + (v_referrals * 0.02),
            4
        );


    -- ========================================================
    -- TIME
    -- ========================================================

    v_elapsed :=
        extract(
            epoch from (
                v_until_now
                - v_session.started_at
            )
        );


    v_remaining :=
        greatest(
            extract(
                epoch from (
                    v_session.ends_at
                    - now()
                )
            ),
            0
        );


    -- ========================================================
    -- BASE REWARD
    -- ========================================================

    v_reward :=
        (
            greatest(
                v_elapsed,
                0
            )
            / 3600.0
        )
        * 0.20;


    -- ========================================================
    -- BOOST AD REWARD
    -- ========================================================

    v_reward :=
        v_reward
        +
        public.calculate_ad_bonus_reward(
            v_user_id,
            v_session.started_at,
            v_until_now
        );


    -- ========================================================
    -- REFERRAL REWARD
    -- ========================================================

    v_reward :=
        v_reward
        +
        public.calculate_referral_bonus_reward(
            v_user_id,
            v_session.started_at,
            v_until_now
        );


    v_reward :=
        round(
            greatest(
                v_reward,
                0
            ),
            8
        );


    -- ========================================================
    -- SYNCHRONIZE PROFILE
    -- ========================================================

    update public.profiles

    set
        mining_active = true,

        mining_started_at =
            v_session.started_at,

        mining_ends_at =
            v_session.ends_at,

        mining_rate =
            v_rate,

        active_referrals =
            v_referrals,

        daily_ads_watched =
            v_ads,

        ad_boost =
            round(
                v_ads * 0.10,
                4
            ),

        updated_at = now()

    where id = v_user_id;


    -- ========================================================
    -- RESPONSE
    -- ========================================================

    return jsonb_build_object(

        'success', true,

        'active', true,

        'mining_active', true,

        'expired', false,

        'claimable', false,

        'session_id',
            v_session.id,

        'started_at',
            v_session.started_at,

        'ends_at',
            v_session.ends_at,

        'elapsed_seconds',
            greatest(
                v_elapsed,
                0
            ),

        'remaining_seconds',
            v_remaining,

        'reward',
            v_reward,

        'mining_rate',
            v_rate,

        'ads_watched',
            v_ads,

        'ad_boost',
            round(
                v_ads * 0.10,
                4
            ),

        'active_referrals',
            v_referrals

    );

end;
$function$;


-- ============================================================
-- 13. REQUEST CLAIM AD
-- ============================================================

create or replace function public.request_claim_ad()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_request public.mining_claim_ad_requests%rowtype;

    v_request_id uuid;

    v_now timestamptz :=
        now();

begin

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception 'Authentication required';

    end if;


    select *

    into v_session

    from public.mining_sessions

    where user_id = v_user_id

      and claimed = false

      and ends_at <= v_now

    order by ends_at desc

    limit 1

    for update;


    if not found then

        raise exception
            'No completed mining session is available';

    end if;


    update public.mining_claim_ad_requests

    set
        status = 'expired'

    where user_id = v_user_id

      and status = 'pending'

      and expires_at <= v_now;


    select *

    into v_request

    from public.mining_claim_ad_requests

    where user_id = v_user_id

      and status in (
          'pending',
          'verified'
      )

    order by created_at desc

    limit 1

    for update;


    if found then

        return jsonb_build_object(

            'success', true,

            'request_id',
                v_request.id,

            'session_id',
                v_request.session_id,

            'status',
                v_request.status,

            'expires_at',
                v_request.expires_at

        );

    end if;


    insert into public.mining_claim_ad_requests (

        user_id,

        session_id,

        expires_at,

        status

    )

    values (

        v_user_id,

        v_session.id,

        v_now + interval '5 minutes',

        'pending'

    )

    returning id

    into v_request_id;


    return jsonb_build_object(

        'success', true,

        'request_id',
            v_request_id,

        'session_id',
            v_session.id,

        'status',
            'pending',

        'expires_at',
            v_now + interval '5 minutes',

        'message',
            'Claim advertisement request created'

    );

end;
$function$;


-- ============================================================
-- 14. GET CLAIM AD STATUS
-- ============================================================

create or replace function public.get_claim_ad_status(
    p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_request public.mining_claim_ad_requests%rowtype;

begin

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception 'Authentication required';

    end if;


    select *

    into v_request

    from public.mining_claim_ad_requests

    where id = p_request_id

      and user_id = v_user_id

    limit 1;


    if not found then

        raise exception
            'Claim advertisement request not found';

    end if;


    if v_request.status = 'pending'

       and v_request.expires_at <= now() then


        update public.mining_claim_ad_requests

        set
            status = 'expired'

        where id = v_request.id

          and status = 'pending';


        v_request.status :=
            'expired';

    end if;


    return jsonb_build_object(

        'success', true,

        'request_id',
            v_request.id,

        'session_id',
            v_request.session_id,

        'status',
            v_request.status,

        'verified',
            v_request.status = 'verified',

        'expires_at',
            v_request.expires_at,

        'verified_at',
            v_request.verified_at,

        'levelplay_event_id',
            v_request.levelplay_event_id

    );

end;
$function$;


-- ============================================================
-- 15. LEVELPLAY S2S CLAIM AD VERIFICATION
-- ============================================================

create or replace function public.verify_levelplay_claim_ad(
    p_user_id uuid,
    p_event_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_request
        public.mining_claim_ad_requests%rowtype;

    v_session
        public.mining_sessions%rowtype;

    v_existing
        public.mining_claim_ad_requests%rowtype;

    v_now timestamptz :=
        now();

begin

    if p_user_id is null then

        raise exception
            'User ID is required';

    end if;


    if p_event_id is null

       or length(trim(p_event_id)) = 0 then

        raise exception
            'LevelPlay EVENT_ID is required';

    end if;


    if length(p_event_id) > 255 then

        raise exception
            'Invalid LevelPlay EVENT_ID';

    end if;


    -- ========================================================
    -- DUPLICATE EVENT PROTECTION
    -- ========================================================

    select *

    into v_existing

    from public.mining_claim_ad_requests

    where levelplay_event_id = p_event_id

    limit 1;


    if found then

        return jsonb_build_object(

            'success', true,

            'verified', true,

            'duplicate', true,

            'request_id',
                v_existing.id,

            'session_id',
                v_existing.session_id,

            'levelplay_event_id',
                v_existing.levelplay_event_id

        );

    end if;


    -- ========================================================
    -- FIND OPEN REQUEST
    -- ========================================================

    select *

    into v_request

    from public.mining_claim_ad_requests

    where user_id = p_user_id

      and status = 'pending'

      and expires_at > v_now

    order by created_at desc

    limit 1

    for update;


    if not found then

        raise exception
            'No pending claim advertisement request found';

    end if;


    -- ========================================================
    -- LOCK COMPLETED SESSION
    -- ========================================================

    select *

    into v_session

    from public.mining_sessions

    where id = v_request.session_id

      and user_id = p_user_id

      and claimed = false

      and ends_at <= v_now

    limit 1

    for update;


    if not found then

        raise exception
            'Mining session is not available for claim';

    end if;


    update public.mining_claim_ad_requests

    set
        status = 'verified',

        verified_at = v_now,

        levelplay_event_id =
            p_event_id

    where id = v_request.id

      and status = 'pending';


    if not found then

        raise exception
            'Claim advertisement verification failed';

    end if;


    return jsonb_build_object(

        'success', true,

        'verified', true,

        'duplicate', false,

        'request_id',
            v_request.id,

        'session_id',
            v_session.id,

        'levelplay_event_id',
            p_event_id,

        'message',
            'Claim advertisement verified successfully'

    );

end;
$function$;


-- ============================================================
-- 16. NORMAL LEVELPLAY S2S BOOST AD
-- ============================================================
--
-- THIS IS THE IMPORTANT BOOST ADS FIX.
--
-- One verified LevelPlay event:
--   = one ad
--
-- Maximum:
--   7 ads per CURRENT session
--
-- Each:
--   +0.10 FAN/H
--
-- Maximum:
--   +0.70 FAN/H
--
-- watched_at:
--   exact SERVER time the reward is recorded.
-- ============================================================

create or replace function public.record_levelplay_reward(
    p_user_id uuid,
    p_event_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_session
        public.mining_sessions%rowtype;

    v_existing
        public.ad_rewards%rowtype;

    v_ads integer;

    v_next_ad integer;

    v_ad_id uuid;

    v_referrals integer;

    v_rate numeric(12,4);

    v_now timestamptz :=
        now();

begin

    if p_user_id is null then

        raise exception
            'User ID is required';

    end if;


    if p_event_id is null

       or length(trim(p_event_id)) = 0 then

        raise exception
            'LevelPlay EVENT_ID is required';

    end if;


    if length(p_event_id) > 255 then

        raise exception
            'Invalid LevelPlay EVENT_ID';

    end if;


    -- ========================================================
    -- DUPLICATE LEVELPLAY EVENT
    -- ========================================================

    select *

    into v_existing

    from public.ad_rewards

    where levelplay_event_id = p_event_id

    limit 1;


    if found then

        return jsonb_build_object(

            'success', true,

            'duplicate', true,

            'verified', true,

            'ad_id',
                v_existing.id,

            'session_id',
                v_existing.session_id,

            'ad_number',
                v_existing.ad_number,

            'reward_rate',
                0.10,

            'ads_watched',
                v_existing.ad_number,

            'ad_boost',
                round(
                    least(
                        greatest(
                            v_existing.ad_number,
                            0
                        ),
                        7
                    )
                    * 0.10,
                    4
                ),

            'levelplay_event_id',
                v_existing.levelplay_event_id

        );

    end if;


    -- ========================================================
    -- ACTIVE CURRENT SESSION ONLY
    -- ========================================================

    select *

    into v_session

    from public.mining_sessions

    where user_id = p_user_id

      and claimed = false

      and started_at <= v_now

      and ends_at > v_now

    order by started_at desc

    limit 1

    for update;


    if not found then

        raise exception
            'No active mining session found';

    end if;


    -- ========================================================
    -- COUNT ADS FOR THIS SESSION ONLY
    -- ========================================================

    select count(*)::integer

    into v_ads

    from public.ad_rewards

    where user_id = p_user_id

      and session_id = v_session.id

      and watched_at >= v_session.started_at

      and watched_at < v_session.ends_at;


    v_ads :=
        least(
            greatest(
                coalesce(v_ads, 0),
                0
            ),
            7
        );


    -- ========================================================
    -- MAX 7 ADS
    -- ========================================================

    if v_ads >= 7 then

        raise exception
            'Maximum of 7 rewarded ads reached';

    end if;


    v_next_ad :=
        v_ads + 1;


    -- ========================================================
    -- RECORD VERIFIED AD
    -- ========================================================

    insert into public.ad_rewards (

        user_id,

        session_id,

        ad_number,

        watched_at,

        reward_amount,

        levelplay_event_id

    )

    values (

        p_user_id,

        v_session.id,

        v_next_ad,

        v_now,

        0.10,

        p_event_id

    )

    returning id

    into v_ad_id;


    -- ========================================================
    -- ACTIVE REFERRALS
    -- ========================================================

    v_referrals :=
        public.calculate_active_referrals(
            p_user_id
        );


    -- ========================================================
    -- NEW CURRENT RATE
    -- ========================================================

    v_rate :=
        round(
            0.20

            + (v_next_ad * 0.10)

            + (v_referrals * 0.02),

            4
        );


    -- ========================================================
    -- SYNCHRONIZE PROFILE
    -- ========================================================

    update public.profiles

    set

        mining_active = true,

        mining_started_at =
            v_session.started_at,

        mining_ends_at =
            v_session.ends_at,

        mining_rate =
            v_rate,

        daily_ads_watched =
            v_next_ad,

        ad_boost =
            round(
                v_next_ad * 0.10,
                4
            ),

        active_referrals =
            v_referrals,

        updated_at =
            v_now

    where id = p_user_id;


    return jsonb_build_object(

        'success', true,

        'duplicate', false,

        'verified', true,

        'ad_id',
            v_ad_id,

        'session_id',
            v_session.id,

        'ad_number',
            v_next_ad,

        'ads_watched',
            v_next_ad,

        'reward_rate',
            0.10,

        'ad_boost',
            round(
                v_next_ad * 0.10,
                4
            ),

        'mining_rate',
            v_rate,

        'levelplay_event_id',
            p_event_id,

        'message',
            'LevelPlay S2S boost ad recorded successfully'

    );

end;
$function$;


-- ============================================================
-- 17. CLAIM MINING
-- ============================================================
--
-- REQUIREMENTS:
--
-- 1. Completed 24-hour session
-- 2. Verified claim ad
--
-- After successful claim:
--
-- claimed = true
-- profile mining_active = false
-- ads_watched = 0
-- ad_boost = 0
--
-- Then the next START MINING creates a NEW 24-hour session.
-- ============================================================

create or replace function public.claim_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_session
        public.mining_sessions%rowtype;

    v_claim_ad
        public.mining_claim_ad_requests%rowtype;

    v_penalty_result jsonb;

    v_old_balance numeric(24,8);

    v_new_balance numeric(24,8);

    v_base_reward numeric(30,8);

    v_ad_reward numeric(30,8);

    v_referral_reward numeric(30,8);

    v_reward numeric(30,8);

    v_active_referrals integer;

    v_final_rate numeric(12,4);

begin

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception
            'Authentication required';

    end if;


    -- ========================================================
    -- LOCK PROFILE
    -- ========================================================

    select fan_balance

    into v_old_balance

    from public.profiles

    where id = v_user_id

    for update;


    if not found then

        raise exception
            'Profile not found';

    end if;


    -- ========================================================
    -- LOCK COMPLETED SESSION
    -- ========================================================

    select *

    into v_session

    from public.mining_sessions

    where user_id = v_user_id

      and claimed = false

      and ends_at <= now()

    order by ends_at desc

    limit 1

    for update;


    if not found then

        raise exception
            'No completed mining session is available to claim';

    end if;


    -- ========================================================
    -- REQUIRED CLAIM AD
    -- ========================================================

    select *

    into v_claim_ad

    from public.mining_claim_ad_requests

    where user_id = v_user_id

      and session_id = v_session.id

      and status = 'verified'

      and consumed_at is null

    order by verified_at desc

    limit 1

    for update;


    if not found then

        raise exception
            'Watch and complete the claim advertisement before claiming';

    end if;


    -- ========================================================
    -- INACTIVITY PENALTY
    -- ========================================================

    v_penalty_result :=
        public.apply_inactivity_penalty(
            v_user_id
        );


    -- ========================================================
    -- BASE REWARD
    -- ========================================================

    v_base_reward :=
        round(

            (
                extract(
                    epoch from (
                        v_session.ends_at
                        -
                        v_session.started_at
                    )
                )
                / 3600.0
            )

            * 0.20,

            8
        );


    -- ========================================================
    -- BOOST AD REWARD
    -- ========================================================

    v_ad_reward :=
        round(

            public.calculate_ad_bonus_reward(

                v_user_id,

                v_session.started_at,

                v_session.ends_at

            ),

            8
        );


    -- ========================================================
    -- REFERRAL REWARD
    -- ========================================================

    v_referral_reward :=
        round(

            public.calculate_referral_bonus_reward(

                v_user_id,

                v_session.started_at,

                v_session.ends_at

            ),

            8
        );


    -- ========================================================
    -- TOTAL REWARD
    -- ========================================================

    v_reward :=
        greatest(

            round(

                v_base_reward

                + v_ad_reward

                + v_referral_reward,

                8

            ),

            0

        );


    v_new_balance :=
        round(

            greatest(
                coalesce(
                    v_old_balance,
                    0
                ),
                0
            )

            + v_reward,

            8
        );


    -- ========================================================
    -- CURRENT ACTIVE REFERRALS
    -- ========================================================

    v_active_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_final_rate :=
        round(

            0.20
            + (
                v_active_referrals
                * 0.02
            ),

            4

        );


    -- ========================================================
    -- MARK SESSION CLAIMED
    -- ========================================================

    update public.mining_sessions

    set

        claimed = true,

        reward_amount = v_reward,

        claimed_at = now()

    where id = v_session.id

      and claimed = false;


    if not found then

        raise exception
            'Mining reward could not be claimed';

    end if;


    -- ========================================================
    -- CONSUME CLAIM AD
    -- ========================================================

    update public.mining_claim_ad_requests

    set

        status = 'consumed',

        consumed_at = now()

    where id = v_claim_ad.id

      and status = 'verified'

      and consumed_at is null;


    if not found then

        raise exception
            'Claim advertisement could not be consumed';

    end if;


    -- ========================================================
    -- RESET PROFILE MINING STATE
    -- ========================================================

    update public.profiles

    set

        fan_balance =
            v_new_balance,

        mining_active =
            false,

        mining_started_at =
            null,

        mining_ends_at =
            null,

        daily_ads_watched =
            0,

        ad_boost =
            0,

        mining_rate =
            v_final_rate,

        active_referrals =
            v_active_referrals,

        updated_at =
            now()

    where id = v_user_id;


    return jsonb_build_object(

        'success', true,

        'session_id',
            v_session.id,

        'claim_ad_verified',
            true,

        'claim_ad_request_id',
            v_claim_ad.id,

        'reward',
            v_reward,

        'fan_reward',
            v_reward,

        'base_reward',
            v_base_reward,

        'ad_reward',
            v_ad_reward,

        'referral_reward',
            v_referral_reward,

        'fan_balance',
            v_new_balance,

        'started_at',
            v_session.started_at,

        'ends_at',
            v_session.ends_at,

        'inactivity_penalty',
            coalesce(
                v_penalty_result -> 'penalty',
                '0'::jsonb
            ),

        'message',
            'Mining reward claimed successfully'

    );

end;
$function$;


-- ============================================================
-- 18. CLAIM USER WRAPPER
-- ============================================================

create or replace function public.claim_mining(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.claim_mining();

end;
$$;


-- ============================================================
-- 19. COMPLETE EXPIRED SESSION
-- ============================================================
--
-- This function DOES NOT claim the reward.
--
-- It only synchronizes the profile.
--
-- The mining session remains:
--
-- claimed = false
--
-- until the claim-ad flow is completed.
-- ============================================================

create or replace function public.complete_expired_mining_session()
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_session_id uuid;

begin

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception
            'Authentication required';

    end if;


    select id

    into v_session_id

    from public.mining_sessions

    where user_id = v_user_id

      and claimed = false

      and ends_at <= now()

    order by ends_at desc

    limit 1

    for update;


    if v_session_id is null then

        return false;

    end if;


    update public.profiles

    set

        mining_active = false,

        mining_started_at = null,

        mining_ends_at = null,

        daily_ads_watched = 0,

        ad_boost = 0,

        updated_at = now()

    where id = v_user_id;


    return true;

end;
$function$;


-- ============================================================
-- 20. INACTIVITY CRON
-- ============================================================

drop function if exists public.run_inactivity_penalties();


create or replace function public.run_inactivity_penalties()
returns void
language plpgsql
security definer
set search_path = public
as $function$

declare

    r record;

begin

    for r in

        select id

        from public.profiles

        where last_mining_at is not null

          and last_mining_at
              <= now() - interval '72 hours'

    loop

        perform
            public.apply_inactivity_penalty(
                r.id
            );

    end loop;

end;
$function$;


-- ============================================================
-- 21. SECURITY
-- ============================================================

revoke execute
on function public.calculate_active_referrals(uuid)
from public, anon, authenticated;


revoke execute
on function public.calculate_ad_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
from public, anon, authenticated;


revoke execute
on function public.calculate_referral_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
from public, anon, authenticated;


revoke execute
on function public.apply_inactivity_penalty(uuid)
from public, anon, authenticated;


revoke execute
on function public.run_inactivity_penalties()
from public, anon, authenticated;


-- ============================================================
-- OLD CLIENT AD FUNCTIONS LOCKED
-- ============================================================

revoke execute
on function public.record_rewarded_ad()
from public, anon, authenticated;


revoke execute
on function public.record_rewarded_ad(uuid)
from public, anon, authenticated;


revoke execute
on function public.verify_rewarded_ad(uuid)
from public, anon, authenticated;


-- ============================================================
-- LEVELPLAY S2S ONLY
-- ============================================================

revoke execute
on function public.record_levelplay_reward(uuid, text)
from public, anon, authenticated;


revoke execute
on function public.verify_levelplay_claim_ad(uuid, text)
from public, anon, authenticated;


grant execute
on function public.record_levelplay_reward(uuid, text)
to service_role;


grant execute
on function public.verify_levelplay_claim_ad(uuid, text)
to service_role;


-- ============================================================
-- 22. APPLICATION RPC GRANTS
-- ============================================================

grant execute
on function public.get_user_mining_rate()
to authenticated;


grant execute
on function public.get_user_mining_rate(uuid)
to authenticated;


grant execute
on function public.start_mining()
to authenticated;


grant execute
on function public.start_mining(uuid)
to authenticated;


grant execute
on function public.get_active_mining()
to authenticated;


grant execute
on function public.request_claim_ad()
to authenticated;


grant execute
on function public.get_claim_ad_status(uuid)
to authenticated;


grant execute
on function public.claim_mining()
to authenticated;


grant execute
on function public.claim_mining(uuid)
to authenticated;


grant execute
on function public.complete_expired_mining_session()
to authenticated;


-- ============================================================
-- 23. CRON
-- ============================================================

do $cron$
begin

    if not exists (

        select 1

        from cron.job

        where jobname =
            'pfn-inactivity-penalty-hourly'

    ) then

        perform cron.schedule(

            'pfn-inactivity-penalty-hourly',

            '0 * * * *',

            'select public.run_inactivity_penalties();'

        );

    end if;

end;
$cron$;


-- ============================================================
-- END OF POWER FAN NETWORK MINING ENGINE
-- ============================================================
