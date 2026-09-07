-- ============================================================
-- POWER FAN NETWORK
-- MINING ENGINE
-- ============================================================
--
-- Base rate:              0.20 FAN/H
-- Mining session:         24 hours
-- Rewarded ad bonus:      +0.10 FAN/H
-- Maximum ads/session:    7
-- Referral bonus:         +0.02 FAN/H per active referral
--
-- IMPORTANT:
-- Reward calculation is SERVER-SIDE.
-- The Flutter client cannot choose the time or reward.
--
-- BONUS TIMING:
-- Ad bonus starts at ad watched_at.
-- Referral bonus is earned only while the referred user
-- has an overlapping mining session.
-- ============================================================


create extension if not exists "pgcrypto";


-- ============================================================
-- 1. REQUIRED COLUMNS
-- ============================================================

alter table public.profiles
add column if not exists fan_balance numeric(30,8)
not null default 0;

alter table public.profiles
add column if not exists afam_balance numeric(30,8)
not null default 0;

alter table public.profiles
add column if not exists mining_rate numeric(12,4)
not null default 0.2;

alter table public.profiles
add column if not exists active_referrals integer
not null default 0;

alter table public.profiles
add column if not exists daily_ads_watched integer
not null default 0;

alter table public.profiles
add column if not exists ad_boost numeric(12,4)
not null default 0;

alter table public.profiles
add column if not exists mining_active boolean
not null default false;

alter table public.profiles
add column if not exists mining_started_at timestamptz;

alter table public.profiles
add column if not exists mining_ends_at timestamptz;


-- ============================================================
-- 2. MINING SESSIONS
-- ============================================================

create table if not exists public.mining_sessions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    started_at timestamptz not null,

    ends_at timestamptz not null,

    mining_rate numeric(12,4)
        not null default 0.2,

    reward numeric(30,8)
        not null default 0,

    status text
        not null default 'active',

    claimed_at timestamptz,

    created_at timestamptz
        not null default now(),

    constraint mining_sessions_status_check
    check (
        status in (
            'active',
            'completed',
            'claimed',
            'cancelled'
        )
    ),

    constraint mining_sessions_time_check
    check (ends_at > started_at)
);


create index if not exists mining_sessions_user_id_idx
on public.mining_sessions(user_id);

create index if not exists mining_sessions_status_idx
on public.mining_sessions(status);

create index if not exists mining_sessions_started_at_idx
on public.mining_sessions(started_at);

create index if not exists mining_sessions_ends_at_idx
on public.mining_sessions(ends_at);


create unique index if not exists
mining_sessions_one_active_per_user_idx
on public.mining_sessions(user_id)
where status = 'active';


-- ============================================================
-- 3. REWARDED ADS
-- ============================================================

create table if not exists public.ad_rewards (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    ad_number integer not null,

    reward_rate numeric(12,4)
        not null default 0.1,

    watched_at timestamptz
        not null default now(),

    constraint ad_rewards_number_check
    check (ad_number >= 1),

    constraint ad_rewards_rate_check
    check (reward_rate >= 0)
);


create index if not exists ad_rewards_user_id_idx
on public.ad_rewards(user_id);

create index if not exists ad_rewards_watched_at_idx
on public.ad_rewards(watched_at);


-- ============================================================
-- 4. COUNT CURRENT ACTIVE REFERRALS
-- ============================================================
--
-- A referral is considered active when the referred user
-- currently has mining_active = true.
--
-- There is intentionally NO referral limit.
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
    from public.profiles
    where referred_by = p_user_id
      and mining_active = true;
$$;


-- ============================================================
-- 5. CALCULATE TIME-WEIGHTED AD REWARD
-- ============================================================
--
-- Every verified/recorded ad gives +0.10 FAN/H
-- from watched_at until session end.
--
-- Maximum 7 ads.
-- ============================================================

create or replace function public.calculate_ad_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        sum(
            (
                extract(
                    epoch from (
                        p_ends_at - ar.watched_at
                    )
                ) / 3600.0
            )
            * least(ar.reward_rate, 0.10)
        ),
        0
    )
    from (
        select
            reward_rate,
            watched_at
        from public.ad_rewards
        where user_id = p_user_id
          and watched_at >= p_started_at
          and watched_at < p_ends_at
        order by watched_at
        limit 7
    ) ar;
$$;


-- ============================================================
-- 6. CALCULATE TIME-WEIGHTED REFERRAL REWARD
-- ============================================================
--
-- Each referred user contributes +0.02 FAN/H
-- only during the time their mining session overlaps
-- the referrer's mining session.
--
-- No referral limit.
-- ============================================================

create or replace function public.calculate_referral_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
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
                            p_started_at
                        )
                    )
                ) / 3600.0
            ) * 0.02
        ),
        0
    )
    from public.profiles referred
    join public.mining_sessions rs
      on rs.user_id = referred.id
    where referred.referred_by = p_user_id
      and rs.status in (
          'active',
          'completed',
          'claimed'
      )
      and rs.started_at < p_ends_at
      and rs.ends_at > p_started_at;
$$;


-- ============================================================
-- 7. CURRENT MINING RATE
-- ============================================================
--
-- This is the CURRENT display rate.
-- It is not used as the final historical reward.
-- ============================================================

create or replace function public.get_user_mining_rate()
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;

    v_active_referrals integer := 0;
    v_ad_count integer := 0;

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
      and status = 'active'
    order by started_at desc
    limit 1;


    v_active_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    if v_session.id is not null then

        select count(*)::integer
        into v_ad_count
        from public.ad_rewards
        where user_id = v_user_id
          and watched_at >= v_session.started_at
          and watched_at < least(
              v_session.ends_at,
              now()
          );

    end if;


    v_ad_count :=
        least(
            coalesce(v_ad_count, 0),
            7
        );


    v_rate :=
          0.20
        + (v_active_referrals * 0.02)
        + (v_ad_count * 0.10);


    v_rate :=
        round(
            greatest(v_rate, 0.20),
            4
        );


    update public.profiles
    set
        active_referrals = v_active_referrals,
        daily_ads_watched = v_ad_count,
        ad_boost = round(
            v_ad_count * 0.10,
            4
        ),
        mining_rate = v_rate,
        updated_at = now()
    where id = v_user_id;


    return v_rate;

end;
$$;


-- ============================================================
-- 8. START MINING
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;

    v_session_id uuid;

    v_started_at timestamptz;
    v_ends_at timestamptz;

    v_active_referrals integer;
    v_initial_rate numeric(12,4);
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    -- Lock profile.
    perform 1
    from public.profiles
    where id = v_user_id
    for update;


    if not found then
        raise exception 'Profile not found';
    end if;


    -- Check existing active session.
    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and status = 'active'
    order by started_at desc
    limit 1
    for update;


    if found then

        if now() < v_session.ends_at then

            return jsonb_build_object(
                'success', true,
                'already_active', true,
                'session_id', v_session.id,
                'started_at', v_session.started_at,
                'ends_at', v_session.ends_at,
                'mining_rate',
                    public.get_user_mining_rate(),
                'status', 'active'
            );

        end if;


        update public.mining_sessions
        set
            status = 'completed'
        where id = v_session.id
          and status = 'active';

    end if;


    v_started_at := now();

    v_ends_at :=
        v_started_at
        + interval '24 hours';


    v_active_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_initial_rate :=
        round(
            0.20
            + (
                v_active_referrals * 0.02
            ),
            4
        );


    insert into public.mining_sessions (
        user_id,
        started_at,
        ends_at,
        mining_rate,
        reward,
        status
    )
    values (
        v_user_id,
        v_started_at,
        v_ends_at,
        v_initial_rate,
        0,
        'active'
    )
    returning id
    into v_session_id;


    update public.profiles
    set
        mining_rate = v_initial_rate,
        active_referrals = v_active_referrals,
        daily_ads_watched = 0,
        ad_boost = 0,
        mining_active = true,
        mining_started_at = v_started_at,
        mining_ends_at = v_ends_at,
        updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'already_active', false,
        'session_id', v_session_id,
        'started_at', v_started_at,
        'ends_at', v_ends_at,
        'mining_rate', v_initial_rate,
        'status', 'active'
    );

end;
$$;


-- ============================================================
-- 9. GET ACTIVE MINING
-- ============================================================

create or replace function public.get_active_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;

    v_rate numeric(12,4);
    v_ads integer;
    v_referrals integer;

    v_elapsed_seconds numeric;
    v_remaining_seconds numeric;

    v_current_reward numeric;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and status = 'active'
    order by started_at desc
    limit 1
    for update;


    if not found then

        return jsonb_build_object(
            'success', true,
            'is_mining', false,
            'mining_active', false,
            'reward', 0,
            'mining_rate', 0.20
        );

    end if;


    if now() >= v_session.ends_at then

        update public.mining_sessions
        set
            status = 'completed'
        where id = v_session.id
          and status = 'active';


        update public.profiles
        set
            mining_active = false,
            mining_started_at = null,
            mining_ends_at = null,
            updated_at = now()
        where id = v_user_id;


        return jsonb_build_object(
            'success', true,
            'is_mining', false,
            'mining_active', false,
            'session_finished', true,
            'claimable', true,
            'started_at', v_session.started_at,
            'ends_at', v_session.ends_at,
            'session_id', v_session.id
        );

    end if;


    select count(*)::integer
    into v_ads
    from public.ad_rewards
    where user_id = v_user_id
      and watched_at >= v_session.started_at
      and watched_at < now();


    v_ads :=
        least(
            coalesce(v_ads, 0),
            7
        );


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_rate :=
        round(
            0.20
            + (v_referrals * 0.02)
            + (v_ads * 0.10),
            4
        );


    v_elapsed_seconds :=
        extract(
            epoch from (
                now() - v_session.started_at
            )
        );


    v_remaining_seconds :=
        extract(
            epoch from (
                v_session.ends_at - now()
            )
        );


    v_current_reward :=
        round(
            (
                extract(
                    epoch from (
                        least(
                            now(),
                            v_session.ends_at
                        )
                        - v_session.started_at
                    )
                ) / 3600.0
            ) * 0.20
            +
            public.calculate_ad_bonus_reward(
                v_user_id,
                v_session.started_at,
                least(
                    now(),
                    v_session.ends_at
                )
            )
            +
            public.calculate_referral_bonus_reward(
                v_user_id,
                v_session.started_at,
                least(
                    now(),
                    v_session.ends_at
                )
            ),
            8
        );


    update public.profiles
    set
        mining_rate = v_rate,
        active_referrals = v_referrals,
        daily_ads_watched = v_ads,
        ad_boost = round(
            v_ads * 0.10,
            4
        ),
        updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'is_mining', true,
        'mining_active', true,
        'session_finished', false,
        'started_at', v_session.started_at,
        'ends_at', v_session.ends_at,
        'elapsed_seconds',
            greatest(v_elapsed_seconds, 0),
        'remaining_seconds',
            greatest(v_remaining_seconds, 0),
        'reward',
            greatest(v_current_reward, 0),
        'mining_rate', v_rate,
        'ads_watched', v_ads,
        'ad_boost',
            round(v_ads * 0.10, 4),
        'active_referrals', v_referrals,
        'session_id', v_session.id
    );

end;
$$;


-- ============================================================
-- 10. RECORD REWARDED AD
-- ============================================================

create or replace function public.record_rewarded_ad()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;

    v_count integer;
    v_next_ad integer;

    v_ad_id uuid;

    v_referrals integer;
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
      and status = 'active'
    order by started_at desc
    limit 1
    for update;


    if not found then
        raise exception
            'Start a mining session before watching rewarded ads';
    end if;


    if now() >= v_session.ends_at then
        raise exception
            'Your mining session has ended';
    end if;


    select count(*)::integer
    into v_count
    from public.ad_rewards
    where user_id = v_user_id
      and watched_at >= v_session.started_at
      and watched_at < v_session.ends_at;


    v_count :=
        least(
            coalesce(v_count, 0),
            7
        );


    if v_count >= 7 then
        raise exception
            'Maximum of 7 rewarded ads per mining session reached';
    end if;


    v_next_ad :=
        v_count + 1;


    insert into public.ad_rewards (
        user_id,
        ad_number,
        reward_rate,
        watched_at
    )
    values (
        v_user_id,
        v_next_ad,
        0.10,
        now()
    )
    returning id
    into v_ad_id;


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_rate :=
        round(
            0.20
            + (v_referrals * 0.02)
            + (v_next_ad * 0.10),
            4
        );


    update public.profiles
    set
        mining_rate = v_rate,
        daily_ads_watched = v_next_ad,
        ad_boost = round(
            v_next_ad * 0.10,
            4
        ),
        active_referrals = v_referrals,
        updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'ad_id', v_ad_id,
        'ad_number', v_next_ad,
        'ads_watched', v_next_ad,
        'reward_rate', 0.10,
        'ad_boost',
            round(v_next_ad * 0.10, 4),
        'mining_rate', v_rate,
        'message',
            'Rewarded ad recorded successfully'
    );

end;
$$;


-- ============================================================
-- 11. VERIFY REWARDED AD
-- ============================================================

create or replace function public.verify_rewarded_ad(
    p_ad_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_ad public.ad_rewards%rowtype;
    v_session public.mining_sessions%rowtype;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select *
    into v_ad
    from public.ad_rewards
    where id = p_ad_id
      and user_id = v_user_id;


    if not found then
        raise exception
            'Rewarded ad record not found';
    end if;


    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and v_ad.watched_at >= started_at
      and v_ad.watched_at < ends_at
    order by started_at desc
    limit 1;


    if not found then
        raise exception
            'Advertisement is not linked to a valid mining session';
    end if;


    return jsonb_build_object(
        'success', true,
        'verified', true,
        'ad_id', v_ad.id,
        'ad_number', v_ad.ad_number,
        'reward_rate', v_ad.reward_rate,
        'watched_at', v_ad.watched_at,
        'session_id', v_session.id
    );

end;
$$;


-- ============================================================
-- 12. CLAIM MINING
-- ============================================================
--
-- IMPORTANT:
-- The claim does NOT use:
--
--     24 * final_rate
--
-- Instead:
--
-- Base reward:
--     24h * 0.20
--
-- Ad reward:
--     +0.10 * remaining hours after each ad
--
-- Referral reward:
--     +0.02 * overlapping referral mining hours
--
-- This prevents retroactive bonus rewards.
-- ============================================================

create or replace function public.claim_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_old_balance numeric(30,8);
    v_new_balance numeric(30,8);

    v_base_reward numeric(30,8);
    v_ad_reward numeric(30,8);
    v_referral_reward numeric(30,8);

    v_reward numeric(30,8);
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    -- Lock user profile.
    select fan_balance
    into v_old_balance
    from public.profiles
    where id = v_user_id
    for update;


    if not found then
        raise exception 'Profile not found';
    end if;


    -- Find the newest completed session.
    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and status = 'completed'
    order by ends_at desc
    limit 1
    for update;


    -- If the active session has expired,
    -- complete it first.
    if not found then

        select *
        into v_session
        from public.mining_sessions
        where user_id = v_user_id
          and status = 'active'
          and now() >= ends_at
        order by ends_at desc
        limit 1
        for update;


        if found then

            update public.mining_sessions
            set status = 'completed'
            where id = v_session.id
              and status = 'active'
            returning *
            into v_session;

        end if;

    end if;


    if v_session.id is null then
        raise exception
            'No completed mining session is available to claim';
    end if;


    if v_session.status <> 'completed' then
        raise exception
            'Mining session is not ready to claim';
    end if;


    if v_session.ends_at > now() then
        raise exception
            'Mining session has not finished yet';
    end if;


    -- Base reward is ALWAYS 24 hours at 0.20 FAN/H.
    v_base_reward :=
        round(
            (
                extract(
                    epoch from (
                        v_session.ends_at
                        - v_session.started_at
                    )
                ) / 3600.0
            ) * 0.20,
            8
        );


    -- Time-weighted ad bonus.
    v_ad_reward :=
        round(
            public.calculate_ad_bonus_reward(
                v_user_id,
                v_session.started_at,
                v_session.ends_at
            ),
            8
        );


    -- Time-weighted referral bonus.
    v_referral_reward :=
        round(
            public.calculate_referral_bonus_reward(
                v_user_id,
                v_session.started_at,
                v_session.ends_at
            ),
            8
        );


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
            coalesce(v_old_balance, 0)
            + v_reward,
            8
        );


    -- Credit balance.
    update public.profiles
    set
        fan_balance = v_new_balance,
        mining_active = false,
        mining_started_at = null,
        mining_ends_at = null,
        daily_ads_watched = 0,
        ad_boost = 0,
        mining_rate = round(
            0.20
            + (
                public.calculate_active_referrals(
                    v_user_id
                ) * 0.02
            ),
            4
        ),
        updated_at = now()
    where id = v_user_id;


    -- Mark session claimed.
    update public.mining_sessions
    set
        status = 'claimed',
        reward = v_reward,
        claimed_at = now()
    where id = v_session.id
      and status = 'completed';


    if not found then
        raise exception
            'Mining reward could not be claimed safely';
    end if;


    return jsonb_build_object(
        'success', true,
        'session_id', v_session.id,
        'reward', v_reward,
        'fan_reward', v_reward,
        'base_reward', v_base_reward,
        'ad_reward', v_ad_reward,
        'referral_reward', v_referral_reward,
        'fan_balance', v_new_balance,
        'started_at', v_session.started_at,
        'ends_at', v_session.ends_at,
        'message',
            'Mining reward claimed successfully'
    );

end;
$$;


-- ============================================================
-- 13. SESSION AD COUNT
-- ============================================================

create or replace function public.get_session_ad_count(
    p_started_at timestamptz
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_count integer;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select count(*)::integer
    into v_count
    from public.ad_rewards
    where user_id = v_user_id
      and watched_at >= p_started_at
      and watched_at <= now();


    return least(
        coalesce(v_count, 0),
        7
    );

end;
$$;


-- ============================================================
-- 14. COMPLETE EXPIRED SESSIONS
-- ============================================================
--
-- This function ONLY changes active -> completed.
-- It does NOT credit FAN.
--
-- The exact reward is calculated by claim_mining().
-- ============================================================

create or replace function public.complete_expired_mining_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count integer;
begin

    with completed as (
        update public.mining_sessions
        set status = 'completed'
        where status = 'active'
          and ends_at <= now()
        returning user_id
    )
    select count(*)
    into v_count
    from completed;


    update public.profiles p
    set
        mining_active = false,
        mining_started_at = null,
        mining_ends_at = null,
        updated_at = now()
    where p.mining_active = true
      and not exists (
          select 1
          from public.mining_sessions ms
          where ms.user_id = p.id
            and ms.status = 'active'
      );


    return coalesce(v_count, 0);

end;
$$;


-- ============================================================
-- 15. SECURITY
-- ============================================================

revoke all
on function public.start_mining()
from public, anon, authenticated;

revoke all
on function public.get_active_mining()
from public, anon, authenticated;

revoke all
on function public.claim_mining()
from public, anon, authenticated;

revoke all
on function public.get_user_mining_rate()
from public, anon, authenticated;

revoke all
on function public.record_rewarded_ad()
from public, anon, authenticated;

revoke all
on function public.verify_rewarded_ad(uuid)
from public, anon, authenticated;

revoke all
on function public.get_session_ad_count(timestamptz)
from public, anon, authenticated;

revoke all
on function public.calculate_active_referrals(uuid)
from public, anon, authenticated;

revoke all
on function public.calculate_ad_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
from public, anon, authenticated;

revoke all
on function public.calculate_referral_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
from public, anon, authenticated;

revoke all
on function public.complete_expired_mining_sessions()
from public, anon, authenticated;


grant execute
on function public.start_mining()
to authenticated;

grant execute
on function public.get_active_mining()
to authenticated;

grant execute
on function public.claim_mining()
to authenticated;

grant execute
on function public.get_user_mining_rate()
to authenticated;

grant execute
on function public.record_rewarded_ad()
to authenticated;

grant execute
on function public.verify_rewarded_ad(uuid)
to authenticated;

grant execute
on function public.get_session_ad_count(timestamptz)
to authenticated;

grant execute
on function public.calculate_active_referrals(uuid)
to authenticated;

grant execute
on function public.calculate_ad_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
to authenticated;

grant execute
on function public.calculate_referral_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
to authenticated;


-- ============================================================
-- 16. RLS
-- ============================================================

alter table public.mining_sessions
enable row level security;

alter table public.ad_rewards
enable row level security;


drop policy if exists
    mining_sessions_select_own
on public.mining_sessions;


create policy
    mining_sessions_select_own
on public.mining_sessions
for select
to authenticated
using (
    user_id = auth.uid()
);


drop policy if exists
    ad_rewards_select_own
on public.ad_rewards;


create policy
    ad_rewards_select_own
on public.ad_rewards
for select
to authenticated
using (
    user_id = auth.uid()
);


-- ============================================================
-- 17. FINAL NORMALIZATION
-- ============================================================

update public.profiles
set
    mining_rate = greatest(
        coalesce(mining_rate, 0.20),
        0.20
    ),

    active_referrals = greatest(
        coalesce(active_referrals, 0),
        0
    ),

    daily_ads_watched = least(
        greatest(
            coalesce(daily_ads_watched, 0),
            0
        ),
        7
    ),

    ad_boost = least(
        greatest(
            coalesce(ad_boost, 0),
            0
        ),
        0.70
    );


-- ============================================================
-- END OF MINING ENGINE
-- ============================================================
