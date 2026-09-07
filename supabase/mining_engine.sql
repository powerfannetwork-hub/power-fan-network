-- ============================================================
-- POWER FAN NETWORK (AFAM)
-- OFFICIAL SERVER-SIDE MINING ENGINE
-- ============================================================
--
-- OFFICIAL RULES
--
-- Base mining rate       = 0.20 FAN/H
-- Mining session         = 24 hours
-- Rewarded ad            = +0.10 FAN/H
-- Maximum ads/session    = 7
-- Maximum ad boost       = +0.70 FAN/H
-- Referral bonus         = +0.02 FAN/H per active referral
--
-- IMPORTANT:
--
-- 1. Ad boost starts from the exact time the ad was watched.
-- 2. Ad boost is NOT retroactive.
-- 3. Referral bonus applies only while the referral is mining.
-- 4. Referral bonus is NOT retroactive.
-- 5. User must be mining to receive referral mining bonus.
-- 6. Referral bonus stops when referral mining stops.
-- 7. Boost does not extend the 24-hour session.
-- 8. Final reward is calculated from exact time periods.
-- 9. FAN is credited only by server-side RPC.
-- 10. Flutter cannot choose the reward amount.
--
-- ============================================================


create extension if not exists "pgcrypto";


-- ============================================================
-- 1. REQUIRED PROFILE COLUMNS
-- ============================================================

alter table public.profiles
  add column if not exists fan_balance numeric(30,8)
    not null default 0;

alter table public.profiles
  add column if not exists afam_balance numeric(30,8)
    not null default 0;

alter table public.profiles
  add column if not exists mining_rate numeric(12,4)
    not null default 0.20;

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
    not null default 0.20,

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
    )
);


create index if not exists
  mining_sessions_user_id_idx
on public.mining_sessions(user_id);


create index if not exists
  mining_sessions_status_idx
on public.mining_sessions(status);


create index if not exists
  mining_sessions_started_at_idx
on public.mining_sessions(started_at);


create index if not exists
  mining_sessions_ends_at_idx
on public.mining_sessions(ends_at);


create unique index if not exists
  mining_sessions_one_active_per_user_idx
on public.mining_sessions(user_id)
where status = 'active';


-- ============================================================
-- 3. AD REWARDS
-- ============================================================

create table if not exists public.ad_rewards (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  ad_number integer not null,

  reward_rate numeric(12,4)
    not null default 0.10,

  watched_at timestamptz
    not null default now()
);


-- Add session association to existing installations.
alter table public.ad_rewards
  add column if not exists mining_session_id uuid;


-- Add verification timestamp.
alter table public.ad_rewards
  add column if not exists verified_at timestamptz;


-- Add FK only when possible.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'ad_rewards_mining_session_id_fkey'
      and conrelid = 'public.ad_rewards'::regclass
  ) then

    alter table public.ad_rewards
      add constraint ad_rewards_mining_session_id_fkey
      foreign key (mining_session_id)
      references public.mining_sessions(id)
      on delete set null;

  end if;
end;
$$;


create index if not exists
  ad_rewards_user_id_idx
on public.ad_rewards(user_id);


create index if not exists
  ad_rewards_watched_at_idx
on public.ad_rewards(watched_at);


create index if not exists
  ad_rewards_session_id_idx
on public.ad_rewards(mining_session_id);


create unique index if not exists
  ad_rewards_session_number_unique_idx
on public.ad_rewards(
  mining_session_id,
  ad_number
)
where mining_session_id is not null;


-- ============================================================
-- 4. CALCULATE ACTIVE REFERRALS
-- ============================================================
--
-- A referral is active only when the referral has an
-- active mining session at the current server time.
--
-- The referred user's profile.referred_by is the source
-- of the referral relationship.
--
-- ============================================================

create or replace function public.calculate_active_referrals(
  p_user_id uuid
)
returns integer
language plpgsql
stable
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

  if p_user_id is null then
    raise exception 'User ID is required';
  end if;

  if p_user_id <> v_user_id then
    raise exception 'You can only calculate your own referral count';
  end if;


  select count(distinct ms.user_id)::integer
  into v_count
  from public.mining_sessions ms
  join public.profiles rp
    on rp.id = ms.user_id
  where rp.referred_by = v_user_id
    and ms.user_id <> v_user_id
    and ms.status = 'active'
    and ms.started_at <= now()
    and ms.ends_at > now();


  return coalesce(v_count, 0);

end;
$$;


-- ============================================================
-- 5. EXACT MINING REWARD CALCULATOR
-- ============================================================
--
-- This is the core of the official mining system.
--
-- The session is split into exact time segments using:
--
--   - session start
--   - session end
--   - verified ad times
--   - referral mining start times
--   - referral mining end times
--
-- Every segment gets its own mining rate.
--
-- Therefore:
--
-- Example:
--
-- 00:00 -> 02:00 = 0.20
-- 02:00 -> 05:00 = 0.30 after one ad
-- 05:00 -> 10:00 = 0.32 after one active referral
--
-- The earlier hours are NEVER recalculated using the later rate.
--
-- ============================================================

create or replace function public._calculate_mining_reward(
  p_user_id uuid,
  p_session_id uuid,
  p_until timestamptz
)
returns numeric(30,8)
language sql
stable
security definer
set search_path = public
as $$

with session_window as (

  select
    ms.id,
    ms.user_id,
    ms.started_at,
    ms.ends_at,

    least(
      ms.ends_at,
      coalesce(
        p_until,
        now()
      )
    ) as calc_until

  from public.mining_sessions ms

  where ms.id = p_session_id
    and ms.user_id = p_user_id

),

boundaries as (

  -- Session start.
  select
    sw.started_at as boundary
  from session_window sw

  union

  -- Session calculation end.
  select
    sw.calc_until as boundary
  from session_window sw

  union

  -- Every verified ad inside the session.
  select
    ar.watched_at as boundary
  from public.ad_rewards ar
  join session_window sw
    on sw.id = ar.mining_session_id
  where ar.verified_at is not null
    and ar.watched_at >= sw.started_at
    and ar.watched_at < sw.calc_until

  union

  -- Referral mining starts.
  select
    greatest(
      rs.started_at,
      sw.started_at
    ) as boundary
  from public.mining_sessions rs
  join public.profiles rp
    on rp.id = rs.user_id
  cross join session_window sw
  where rp.referred_by = sw.user_id
    and rs.user_id <> sw.user_id
    and rs.status in (
      'active',
      'completed',
      'claimed'
    )
    and rs.started_at < sw.calc_until
    and rs.ends_at > sw.started_at

  union

  -- Referral mining ends.
  select
    least(
      rs.ends_at,
      sw.calc_until
    ) as boundary
  from public.mining_sessions rs
  join public.profiles rp
    on rp.id = rs.user_id
  cross join session_window sw
  where rp.referred_by = sw.user_id
    and rs.user_id <> sw.user_id
    and rs.status in (
      'active',
      'completed',
      'claimed'
    )
    and rs.started_at < sw.calc_until
    and rs.ends_at > sw.started_at

),

ordered_boundaries as (

  select distinct
    boundary

  from boundaries

  where boundary is not null

),

segments as (

  select
    boundary as segment_start,

    lead(boundary)
      over (
        order by boundary
      ) as segment_end

  from ordered_boundaries

),

valid_segments as (

  select
    segment_start,
    segment_end

  from segments

  where segment_end is not null
    and segment_end > segment_start

),

priced_segments as (

  select

    vs.segment_start,
    vs.segment_end,

    extract(
      epoch from (
        vs.segment_end
        - vs.segment_start
      )
    ) / 3600.0 as hours,

    (
      0.20

      +

      (
        0.10 *

        least(

          7,

          (
            select count(*)::numeric

            from public.ad_rewards ar

            where ar.mining_session_id =
              sw.id

              and ar.verified_at is not null

              and ar.watched_at <=
                vs.segment_start
          )
        )
      )

      +

      (
        0.02 *

        (
          select count(distinct rs.user_id)::numeric

          from public.mining_sessions rs

          join public.profiles rp
            on rp.id = rs.user_id

          where rp.referred_by =
            sw.user_id

            and rs.user_id <>
              sw.user_id

            and rs.status in (
              'active',
              'completed',
              'claimed'
            )

            and rs.started_at <=
              vs.segment_start

            and rs.ends_at >
              vs.segment_start
        )
      )

    ) as rate

  from valid_segments vs

  cross join session_window sw

  where vs.segment_start >=
    sw.started_at

    and vs.segment_end <=
    sw.calc_until

)

select round(
  greatest(
    coalesce(
      sum(
        hours * rate
      ),
      0
    ),
    0
  ),
  8
)

from priced_segments;

$$;


-- ============================================================
-- 6. GET CURRENT SERVER-SIDE MINING RATE
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

  v_active_referrals integer;

  v_ad_count integer;

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


  if not found then

    update public.profiles

    set
      mining_rate = 0.20,
      active_referrals = 0,
      daily_ads_watched = 0,
      ad_boost = 0,
      mining_active = false,
      updated_at = now()

    where id = v_user_id;


    return 0.20;

  end if;


  if now() >= v_session.ends_at then

    return 0.20;

  end if;


  select
    public.calculate_active_referrals(
      v_user_id
    )

  into v_active_referrals;


  select count(*)::integer

  into v_ad_count

  from public.ad_rewards ar

  where ar.mining_session_id =
    v_session.id

    and ar.verified_at is not null;


  v_ad_count :=
    least(
      greatest(
        coalesce(
          v_ad_count,
          0
        ),
        0
      ),
      7
    );


  v_rate :=
      0.20

    + (
        v_active_referrals
        * 0.02
      )

    + (
        v_ad_count
        * 0.10
      );


  v_rate :=
    round(
      greatest(
        v_rate,
        0.20
      ),
      4
    );


  update public.profiles

  set
    mining_rate = v_rate,

    active_referrals =
      v_active_referrals,

    daily_ads_watched =
      v_ad_count,

    ad_boost =
      round(
        v_ad_count * 0.10,
        4
      ),

    updated_at = now()

  where id = v_user_id;


  return v_rate;

end;
$$;


-- ============================================================
-- 7. START 24-HOUR MINING SESSION
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare

  v_user_id uuid;

  v_profile public.profiles%rowtype;

  v_existing_session
    public.mining_sessions%rowtype;

  v_session_id uuid;

  v_started_at timestamptz;

  v_ends_at timestamptz;

  v_active_referrals integer;

  v_rate numeric(12,4);

begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Lock profile.
  select *
  into v_profile

  from public.profiles

  where id = v_user_id

  for update;


  if not found then
    raise exception 'Profile not found';
  end if;


  -- Check current active session.
  select *
  into v_existing_session

  from public.mining_sessions

  where user_id = v_user_id
    and status = 'active'

  order by started_at desc

  limit 1

  for update;


  if found then

    if now() < v_existing_session.ends_at then

      return jsonb_build_object(

        'success', true,

        'already_active', true,

        'session_id',
          v_existing_session.id,

        'started_at',
          v_existing_session.started_at,

        'ends_at',
          v_existing_session.ends_at,

        'mining_rate',
          v_existing_session.mining_rate,

        'status',
          'active'

      );

    end if;


    -- Complete expired session using exact accounting.
    update public.mining_sessions

    set
      reward =
        public._calculate_mining_reward(
          v_user_id,
          v_existing_session.id,
          v_existing_session.ends_at
        ),

      status = 'completed'

    where id =
      v_existing_session.id;


    update public.profiles

    set
      mining_active = false,

      mining_started_at = null,

      mining_ends_at = null,

      daily_ads_watched = 0,

      ad_boost = 0,

      updated_at = now()

    where id = v_user_id;

  end if;


  -- Server timestamp.
  v_started_at := now();

  v_ends_at :=
    v_started_at
    + interval '24 hours';


  -- Referral count at session start.
  v_active_referrals :=
    public.calculate_active_referrals(
      v_user_id
    );


  -- Base + referral rate at start.
  v_rate :=
      0.20
    + (
        v_active_referrals * 0.02
      );


  v_rate :=
    round(
      greatest(
        v_rate,
        0.20
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

    v_rate,

    0,

    'active'

  )

  returning id

  into v_session_id;


  update public.profiles

  set

    mining_rate =
      v_rate,

    active_referrals =
      v_active_referrals,

    mining_active =
      true,

    mining_started_at =
      v_started_at,

    mining_ends_at =
      v_ends_at,

    daily_ads_watched =
      0,

    ad_boost =
      0,

    updated_at =
      now()

  where id = v_user_id;


  return jsonb_build_object(

    'success', true,

    'already_active', false,

    'session_id',
      v_session_id,

    'started_at',
      v_started_at,

    'ends_at',
      v_ends_at,

    'mining_rate',
      v_rate,

    'status',
      'active'

  );

end;
$$;


-- ============================================================
-- 8. GET CURRENT MINING SESSION
-- ============================================================

create or replace function public.get_active_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare

  v_user_id uuid;

  v_session
    public.mining_sessions%rowtype;

  v_active_referrals integer;

  v_ad_count integer;

  v_rate numeric(12,4);

  v_reward numeric(30,8);

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

      'is_mining', false,

      'mining_active', false,

      'session_finished', false,

      'expired', false,

      'claimable', false,

      'started_at', null,

      'ends_at', null,

      'remaining_seconds', 0,

      'elapsed_seconds', 0,

      'ads_watched', 0,

      'ad_boost', 0,

      'active_referrals', 0,

      'mining_rate', 0.20,

      'reward', 0,

      'session_id', null

    );

  end if;


  -- ========================================================
  -- SESSION EXPIRED
  -- ========================================================

  if now() >= v_session.ends_at then

    v_reward :=
      public._calculate_mining_reward(

        v_user_id,

        v_session.id,

        v_session.ends_at

      );


    update public.mining_sessions

    set

      status = 'completed',

      reward = v_reward

    where id = v_session.id;


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

      'is_mining', false,

      'mining_active', false,

      'session_finished', true,

      'expired', true,

      'claimable', true,

      'started_at',
        v_session.started_at,

      'ends_at',
        v_session.ends_at,

      'remaining_seconds', 0,

      'elapsed_seconds',
        greatest(
          0,
          extract(
            epoch from (
              v_session.ends_at
              - v_session.started_at
            )
          )::integer
        ),

      'ads_watched',
        (
          select least(
            count(*)::integer,
            7
          )
          from public.ad_rewards
          where mining_session_id =
            v_session.id

            and verified_at is not null
        ),

      'ad_boost',
        (
          select round(
            least(
              count(*)::numeric,
              7
            ) * 0.10,
            4
          )
          from public.ad_rewards
          where mining_session_id =
            v_session.id

            and verified_at is not null
        ),

      'active_referrals',
        (
          select count(
            distinct rs.user_id
          )::integer

          from public.mining_sessions rs

          join public.profiles rp
            on rp.id = rs.user_id

          where rp.referred_by =
            v_user_id

            and rs.user_id <>
              v_user_id

            and rs.status in (
              'active',
              'completed',
              'claimed'
            )

            and rs.started_at <=
              v_session.ends_at

            and rs.ends_at >
              v_session.started_at
        ),

      'mining_rate',
        v_session.mining_rate,

      'reward',
        v_reward,

      'session_id',
        v_session.id

    );

  end if;


  -- ========================================================
  -- SESSION STILL ACTIVE
  -- ========================================================

  select
    public.calculate_active_referrals(
      v_user_id
    )

  into v_active_referrals;


  select count(*)::integer

  into v_ad_count

  from public.ad_rewards

  where mining_session_id =
    v_session.id

    and verified_at is not null;


  v_ad_count :=
    least(
      greatest(
        coalesce(
          v_ad_count,
          0
        ),
        0
      ),
      7
    );


  v_rate :=
      0.20

    + (
        v_active_referrals
        * 0.02
      )

    + (
        v_ad_count
        * 0.10
      );


  v_rate :=
    round(
      greatest(
        v_rate,
        0.20
      ),
      4
    );


  -- Exact current reward.
  v_reward :=
    public._calculate_mining_reward(

      v_user_id,

      v_session.id,

      least(
        now(),
        v_session.ends_at
      )

    );


  update public.profiles

  set

    mining_rate =
      v_rate,

    active_referrals =
      v_active_referrals,

    daily_ads_watched =
      v_ad_count,

    ad_boost =
      round(
        v_ad_count * 0.10,
        4
      ),

    mining_active =
      true,

    mining_started_at =
      v_session.started_at,

    mining_ends_at =
      v_session.ends_at,

    updated_at =
      now()

  where id = v_user_id;


  return jsonb_build_object(

    'success', true,

    'active', true,

    'is_mining', true,

    'mining_active', true,

    'session_finished', false,

    'expired', false,

    'claimable', false,

    'started_at',
      v_session.started_at,

    'ends_at',
      v_session.ends_at,

    'remaining_seconds',
      greatest(
        0,
        extract(
          epoch from (
            v_session.ends_at
            - now()
          )
        )::integer
      ),

    'elapsed_seconds',
      greatest(
        0,
        extract(
          epoch from (
            now()
            - v_session.started_at
          )
        )::integer
      ),

    'ads_watched',
      v_ad_count,

    'ad_boost',
      round(
        v_ad_count * 0.10,
        4
      ),

    'active_referrals',
      v_active_referrals,

    'mining_rate',
      v_rate,

    'reward',
      v_reward,

    'session_id',
      v_session.id

  );

end;
$$;


-- ============================================================
-- 9. RECORD REWARDED AD
-- ============================================================

create or replace function public.record_rewarded_ad()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare

  v_user_id uuid;

  v_session
    public.mining_sessions%rowtype;

  v_count integer;

  v_next_ad_number integer;

  v_ad_id uuid;

  v_rate numeric(12,4);

begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Lock current active session.
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


  -- Count ads in this exact session.
  select count(*)::integer

  into v_count

  from public.ad_rewards

  where mining_session_id =
    v_session.id;


  if v_count >= 7 then

    raise exception
      'Maximum of 7 rewarded ads per mining session reached';

  end if;


  v_next_ad_number :=
    v_count + 1;


  -- Server timestamp.
  insert into public.ad_rewards (

    user_id,

    mining_session_id,

    ad_number,

    reward_rate,

    watched_at,

    verified_at

  )

  values (

    v_user_id,

    v_session.id,

    v_next_ad_number,

    0.10,

    now(),

    null

  )

  returning id

  into v_ad_id;


  -- Current display rate.
  v_rate :=

      0.20

    + (
        public.calculate_active_referrals(
          v_user_id
        ) * 0.02
      )

    + (
        v_next_ad_number * 0.10
      );


  v_rate :=
    round(
      least(
        greatest(
          v_rate,
          0.20
        ),
        0.90
      ),
      4
    );


  update public.profiles

  set

    mining_rate =
      v_rate,

    daily_ads_watched =
      v_next_ad_number,

    ad_boost =
      round(
        v_next_ad_number * 0.10,
        4
      ),

    updated_at =
      now()

  where id = v_user_id;


  return jsonb_build_object(

    'success', true,

    'ad_id',
      v_ad_id,

    'ad_number',
      v_next_ad_number,

    'ads_watched',
      v_next_ad_number,

    'reward_rate',
      0.10,

    'ad_boost',
      round(
        v_next_ad_number * 0.10,
        4
      ),

    'mining_rate',
      v_rate,

    'verified',
      false,

    'message',
      'Rewarded ad recorded successfully'

  );

end;
$$;


-- ============================================================
-- 10. VERIFY REWARDED AD
-- ============================================================
--
-- This marks the recorded ad as verified.
--
-- The FAN reward itself is NOT directly credited here.
--
-- Reward is calculated by _calculate_mining_reward().
--
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

  v_ad
    public.ad_rewards%rowtype;

  v_session
    public.mining_sessions%rowtype;

begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  select *
  into v_ad

  from public.ad_rewards

  where id = p_ad_id

    and user_id = v_user_id

  for update;


  if not found then

    raise exception
      'Rewarded ad record not found';

  end if;


  if v_ad.mining_session_id is null then

    select *
    into v_session

    from public.mining_sessions

    where user_id = v_user_id

      and v_ad.watched_at >=
        started_at

      and v_ad.watched_at <
        ends_at

    order by started_at desc

    limit 1;


    if not found then

      raise exception
        'Advertisement is not linked to a valid mining session';

    end if;


    update public.ad_rewards

    set
      mining_session_id =
        v_session.id

    where id = v_ad.id;


  else

    select *
    into v_session

    from public.mining_sessions

    where id =
      v_ad.mining_session_id

      and user_id =
        v_user_id;


    if not found then

      raise exception
        'Mining session for advertisement was not found';

    end if;

  end if;


  -- Idempotent verification.
  update public.ad_rewards

  set

    verified_at =
      coalesce(
        verified_at,
        now()
      )

  where id =
    v_ad.id

  returning *

  into v_ad;


  return jsonb_build_object(

    'success', true,

    'verified', true,

    'ad_id',
      v_ad.id,

    'ad_number',
      v_ad.ad_number,

    'reward_rate',
      v_ad.reward_rate,

    'watched_at',
      v_ad.watched_at,

    'verified_at',
      v_ad.verified_at,

    'session_id',
      v_session.id

  );

end;
$$;


-- ============================================================
-- 11. CLAIM MINING
-- ============================================================

create or replace function public.claim_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare

  v_user_id uuid;

  v_session
    public.mining_sessions%rowtype;

  v_reward numeric(30,8);

  v_old_balance numeric(30,8);

  v_new_balance numeric(30,8);

begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Lock profile correctly.
  select fan_balance

  into v_old_balance

  from public.profiles

  where id = v_user_id

  for update;


  if not found then
    raise exception 'Profile not found';
  end if;


  -- Find latest completed session.
  select *

  into v_session

  from public.mining_sessions

  where user_id = v_user_id

    and status = 'completed'

  order by ends_at desc

  limit 1

  for update;


  -- If an active session has just expired,
  -- complete it using exact accounting.
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

      v_reward :=
        public._calculate_mining_reward(

          v_user_id,

          v_session.id,

          v_session.ends_at

        );


      update public.mining_sessions

      set

        status = 'completed',

        reward = v_reward

      where id =
        v_session.id

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


  -- Recalculate from exact historical events.
  v_reward :=
    public._calculate_mining_reward(

      v_user_id,

      v_session.id,

      v_session.ends_at

    );


  v_reward :=
    greatest(
      coalesce(
        v_reward,
        0
      ),
      0
    );


  v_new_balance :=
    round(
      v_old_balance
      + v_reward,
      8
    );


  -- Credit FAN.
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
      round(
        0.20
        +
        (
          public.calculate_active_referrals(
            v_user_id
          ) * 0.02
        ),
        4
      ),

    updated_at =
      now()

  where id =
    v_user_id;


  -- Claim exactly once.
  update public.mining_sessions

  set

    status =
      'claimed',

    reward =
      v_reward,

    claimed_at =
      now()

  where id =
    v_session.id

    and status =
      'completed';


  if not found then

    raise exception
      'Mining reward could not be claimed safely';

  end if;


  return jsonb_build_object(

    'success', true,

    'session_id',
      v_session.id,

    'reward',
      v_reward,

    'fan_reward',
      v_reward,

    'fan_balance',
      v_new_balance,

    'started_at',
      v_session.started_at,

    'ends_at',
      v_session.ends_at,

    'message',
      'Mining reward claimed successfully'

  );

end;
$$;


-- ============================================================
-- 12. SESSION AD COUNT
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

  from public.ad_rewards ar

  where ar.user_id =
    v_user_id

    and ar.watched_at >=
      p_started_at

    and ar.watched_at <=
      now();


  return least(
    coalesce(
      v_count,
      0
    ),
    7
  );

end;
$$;


-- ============================================================
-- 13. COMPLETE EXPIRED SESSIONS
-- ============================================================
--
-- Trusted backend/cron only.
--
-- This does not credit FAN.
--
-- It only changes:
--
-- active -> completed
--
-- Reward is calculated exactly.
--
-- ============================================================

create or replace function public.complete_expired_mining_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare

  v_session record;

  v_count integer := 0;

  v_reward numeric(30,8);

begin

  for v_session in

    select
      id,
      user_id,
      ends_at

    from public.mining_sessions

    where status = 'active'

      and ends_at <= now()

    for update

  loop

    v_reward :=
      public._calculate_mining_reward(

        v_session.user_id,

        v_session.id,

        v_session.ends_at

      );


    update public.mining_sessions

    set

      status =
        'completed',

      reward =
        v_reward

    where id =
      v_session.id

      and status =
        'active';


    if found then

      v_count :=
        v_count + 1;

    end if;

  end loop;


  -- Synchronize profiles that no longer
  -- have an active mining session.

  update public.profiles p

  set

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

    updated_at =
      now()

  where p.mining_active = true

    and not exists (

      select 1

      from public.mining_sessions ms

      where ms.user_id =
        p.id

        and ms.status =
          'active'

    );


  return v_count;

end;
$$;


-- ============================================================
-- 14. SECURITY
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
on function public.complete_expired_mining_sessions()
from public, anon, authenticated;


revoke all
on function public._calculate_mining_reward(
  uuid,
  uuid,
  timestamptz
)
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


-- complete_expired_mining_sessions()
-- is intentionally NOT granted to authenticated users.
--
-- It is reserved for trusted backend/cron execution.


-- ============================================================
-- 15. RLS
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


-- No direct INSERT/UPDATE/DELETE
-- policies for clients.
--
-- Mining and ad records must go through
-- secure RPC functions.


-- ============================================================
-- 16. FINAL NORMALIZATION
-- ============================================================

update public.profiles

set

  mining_rate =
    greatest(
      coalesce(
        mining_rate,
        0.20
      ),
      0.20
    ),

  active_referrals =
    greatest(
      coalesce(
        active_referrals,
        0
      ),
      0
    ),

  daily_ads_watched =
    least(
      greatest(
        coalesce(
          daily_ads_watched,
          0
        ),
        0
      ),
      7
    ),

  ad_boost =
    least(
      greatest(
        coalesce(
          ad_boost,
          0
        ),
        0
      ),
      0.70
    );


-- ============================================================
-- END OF POWER FAN NETWORK MINING ENGINE
-- ============================================================
