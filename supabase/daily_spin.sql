-- ============================================================
-- POWER FAN NETWORK
-- REAL DAILY SPIN SYSTEM
-- ============================================================
--
-- FILE:
--   supabase/daily_spin.sql
--
-- PURPOSE:
--   Server-side Daily Spin system.
--
-- SECURITY:
--   - One spin per user per server calendar day
--   - Reward selection happens on PostgreSQL
--   - FAN balance is changed only by SECURITY DEFINER RPC
--   - Client cannot insert/update spin records directly
--   - Client cannot insert wallet reward records directly
--   - Duplicate/concurrent spin protection
--
-- INSTALL ORDER:
--   schema.sql
--   mining_engine.sql
--   rls.sql
--   schema.plus.sql
--   daily_spin.sql
--
-- IMPORTANT:
--   Flutter must NOT calculate the reward.
--   Flutter only calls spin_daily().
--
-- ============================================================


create extension if not exists pgcrypto;


-- ============================================================
-- 1. DAILY SPIN REWARDS
-- ============================================================
--
-- These are the server-side reward definitions.
--
-- weight values must total 100.
--
-- The reward values match the current
-- power_fan_growth_system.dart definitions.
-- ============================================================

create table if not exists public.daily_spin_rewards (

    id uuid primary key default gen_random_uuid(),

    reward_code text not null unique,

    title text not null,

    reward_type text not null,

    fan_amount numeric(24,8) default 0,

    boost_rate_per_hour numeric(12,4) default 0,

    boost_duration_minutes integer default 0,

    weight integer not null,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    constraint daily_spin_rewards_type_check
    check (
        reward_type in (
            'fan',
            'mining_boost',
            'streak_boost',
            'task_bonus',
            'try_again'
        )
    ),

    constraint daily_spin_rewards_weight_check
    check (weight >= 0),

    constraint daily_spin_rewards_fan_check
    check (fan_amount >= 0),

    constraint daily_spin_rewards_boost_check
    check (boost_rate_per_hour >= 0),

    constraint daily_spin_rewards_duration_check
    check (boost_duration_minutes >= 0)

);


-- ============================================================
-- 2. SEED REAL REWARDS
-- ============================================================

insert into public.daily_spin_rewards (
    reward_code,
    title,
    reward_type,
    fan_amount,
    boost_rate_per_hour,
    boost_duration_minutes,
    weight,
    is_active
)
values
(
    'fan_1',
    '+1 FAN',
    'fan',
    1.0,
    0,
    0,
    24,
    true
),
(
    'fan_2',
    '+2 FAN',
    'fan',
    2.0,
    0,
    0,
    20,
    true
),
(
    'fan_3',
    '+3 FAN',
    'fan',
    3.0,
    0,
    0,
    14,
    true
),
(
    'boost_1h',
    '+0.10 FAN/H',
    'mining_boost',
    0,
    0.10,
    60,
    12,
    true
),
(
    'boost_2h',
    '+0.10 FAN/H',
    'mining_boost',
    0,
    0.10,
    120,
    7,
    true
),
(
    'streak',
    'STREAK BOOST',
    'streak_boost',
    0,
    0,
    60,
    8,
    true
),
(
    'task_bonus',
    'TASK BONUS',
    'task_bonus',
    2.0,
    0,
    0,
    8,
    true
),
(
    'try_again',
    'TRY AGAIN',
    'try_again',
    0,
    0,
    0,
    7,
    true
)
on conflict (reward_code) do update
set
    title =
        excluded.title,

    reward_type =
        excluded.reward_type,

    fan_amount =
        excluded.fan_amount,

    boost_rate_per_hour =
        excluded.boost_rate_per_hour,

    boost_duration_minutes =
        excluded.boost_duration_minutes,

    weight =
        excluded.weight,

    is_active =
        excluded.is_active,

    updated_at =
        now();


-- ============================================================
-- 3. DAILY SPIN HISTORY
-- ============================================================
--
-- One row = one completed server-side spin.
--
-- spin_date uses the database server date.
--
-- The unique index below is the final protection
-- against two spins on the same day.
-- ============================================================

create table if not exists public.daily_spins (

    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    spin_date date not null
        default current_date,

    reward_id uuid not null
        references public.daily_spin_rewards(id),

    reward_code text not null,

    reward_type text not null,

    fan_amount numeric(24,8) not null
        default 0,

    boost_rate_per_hour numeric(12,4) not null
        default 0,

    boost_duration_minutes integer not null
        default 0,

    created_at timestamptz default now()

);


-- ============================================================
-- 4. ONE SPIN PER USER PER DAY
-- ============================================================

create unique index if not exists
ux_daily_spins_user_date
on public.daily_spins(
    user_id,
    spin_date
);


create index if not exists
idx_daily_spins_user_created
on public.daily_spins(
    user_id,
    created_at desc
);


create index if not exists
idx_daily_spins_date
on public.daily_spins(
    spin_date
);


-- ============================================================
-- 5. DAILY SPIN REWARD LEDGER
-- ============================================================
--
-- This provides a dedicated immutable audit trail.
-- ============================================================

create table if not exists public.daily_spin_reward_ledger (

    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    spin_id uuid not null
        references public.daily_spins(id)
        on delete cascade,

    reward_type text not null,

    amount numeric(24,8) not null
        default 0,

    coin text not null
        default 'FAN',

    description text not null,

    created_at timestamptz default now()

);


create unique index if not exists
ux_daily_spin_reward_ledger_spin
on public.daily_spin_reward_ledger(spin_id);


create index if not exists
idx_daily_spin_reward_ledger_user
on public.daily_spin_reward_ledger(
    user_id,
    created_at desc
);


-- ============================================================
-- 6. UPDATED_AT
-- ============================================================

create or replace function public.daily_spin_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $function$
begin

    new.updated_at = now();

    return new;

end;
$function$;


drop trigger if exists
trg_daily_spin_rewards_updated_at
on public.daily_spin_rewards;


create trigger
trg_daily_spin_rewards_updated_at
before update
on public.daily_spin_rewards
for each row
execute function public.daily_spin_set_updated_at();


-- ============================================================
-- 7. GET DAILY SPIN STATUS
-- ============================================================
--
-- Client can safely call this function.
--
-- It returns:
--
--   can_spin
--   last_spin_at
--   next_spin_at
--   reward information for today's spin if already used
--
-- No reward is generated here.
-- ============================================================

drop function if exists public.get_daily_spin_status();


create or replace function public.get_daily_spin_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_today date;

    v_spin public.daily_spins%rowtype;

begin

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception
            'Authentication required';

    end if;


    v_today :=
        current_date;


    select *

    into v_spin

    from public.daily_spins

    where user_id = v_user_id

      and spin_date = v_today

    limit 1;


    if not found then

        return jsonb_build_object(

            'success',
                true,

            'can_spin',
                true,

            'spun_today',
                false,

            'spin_date',
                v_today,

            'last_spin_at',
                null,

            'next_spin_at',
                (v_today + 1)::timestamptz

        );

    end if;


    return jsonb_build_object(

        'success',
            true,

        'can_spin',
            false,

        'spun_today',
            true,

        'spin_date',
            v_spin.spin_date,

        'spin_id',
            v_spin.id,

        'reward_code',
            v_spin.reward_code,

        'reward_type',
            v_spin.reward_type,

        'reward_title',
            (
                select r.title
                from public.daily_spin_rewards r
                where r.id = v_spin.reward_id
            ),

        'fan_amount',
            v_spin.fan_amount,

        'boost_rate_per_hour',
            v_spin.boost_rate_per_hour,

        'boost_duration_minutes',
            v_spin.boost_duration_minutes,

        'last_spin_at',
            v_spin.created_at,

        'next_spin_at',
            ((v_spin.spin_date + 1)::timestamptz)

    );

end;
$function$;


-- ============================================================
-- 8. REAL DAILY SPIN
-- ============================================================
--
-- IMPORTANT:
--
-- The reward is selected on the server.
--
-- Flutter does NOT select the reward.
--
-- The profile row is locked first.
-- This serializes simultaneous requests from
-- the same authenticated user.
--
-- The unique user/date index provides a second
-- protection layer.
-- ============================================================

drop function if exists public.spin_daily();


create or replace function public.spin_daily()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_user_id uuid;

    v_today date;

    v_profile public.profiles%rowtype;

    v_existing_spin public.daily_spins%rowtype;

    v_reward public.daily_spin_rewards%rowtype;

    v_spin_id uuid;

    v_ledger_id uuid;

    v_old_balance numeric(24,8);

    v_new_balance numeric(24,8);

    v_total_weight integer;

    v_random_value numeric;

    v_running_weight integer;

begin

    -- ========================================================
    -- AUTHENTICATION
    -- ========================================================

    v_user_id :=
        auth.uid();


    if v_user_id is null then

        raise exception
            'Authentication required';

    end if;


    v_today :=
        current_date;


    -- ========================================================
    -- LOCK PROFILE
    -- ========================================================
    --
    -- This prevents two simultaneous requests from the
    -- same user from both passing the daily check.
    -- ========================================================

    select *

    into v_profile

    from public.profiles

    where id = v_user_id

    for update;


    if not found then

        raise exception
            'Profile not found';

    end if;


    -- ========================================================
    -- CHECK EXISTING TODAY
    -- ========================================================

    select *

    into v_existing_spin

    from public.daily_spins

    where user_id = v_user_id

      and spin_date = v_today

    limit 1;


    if found then

        return jsonb_build_object(

            'success',
                true,

            'already_spun',
                true,

            'can_spin',
                false,

            'spin_id',
                v_existing_spin.id,

            'spin_date',
                v_existing_spin.spin_date,

            'reward_code',
                v_existing_spin.reward_code,

            'reward_type',
                v_existing_spin.reward_type,

            'reward_title',
                (
                    select title
                    from public.daily_spin_rewards
                    where id = v_existing_spin.reward_id
                ),

            'fan_amount',
                v_existing_spin.fan_amount,

            'boost_rate_per_hour',
                v_existing_spin.boost_rate_per_hour,

            'boost_duration_minutes',
                v_existing_spin.boost_duration_minutes,

            'message',
                'You have already used your Daily Spin today.'

        );

    end if;


    -- ========================================================
    -- FIND ACTIVE REWARDS
    -- ========================================================

    select coalesce(
        sum(weight),
        0
    )::integer

    into v_total_weight

    from public.daily_spin_rewards

    where is_active = true

      and weight > 0;


    if v_total_weight <= 0 then

        raise exception
            'No active Daily Spin rewards are configured';

    end if;


    -- ========================================================
    -- SERVER-SIDE WEIGHTED RANDOM
    -- ========================================================

    v_random_value :=
        random() * v_total_weight;


    v_running_weight :=
        0;


    for v_reward in

        select *

        from public.daily_spin_rewards

        where is_active = true

          and weight > 0

        order by reward_code

    loop

        v_running_weight :=
            v_running_weight
            + v_reward.weight;


        if v_random_value
           < v_running_weight then

            exit;

        end if;

    end loop;


    if v_reward.id is null then

        raise exception
            'Daily Spin reward selection failed';

    end if;


    -- ========================================================
    -- CURRENT BALANCE
    -- ========================================================

    v_old_balance :=
        greatest(
            coalesce(
                v_profile.fan_balance,
                0
            ),
            0
        );


    -- ========================================================
    -- ONLY REAL FAN REWARDS CREDIT BALANCE
    -- ========================================================

    v_new_balance :=
        round(
            v_old_balance
            + greatest(
                coalesce(
                    v_reward.fan_amount,
                    0
                ),
                0
            ),
            8
        );


    -- ========================================================
    -- CREATE SPIN RECORD
    -- ========================================================

    insert into public.daily_spins (

        user_id,

        spin_date,

        reward_id,

        reward_code,

        reward_type,

        fan_amount,

        boost_rate_per_hour,

        boost_duration_minutes

    )

    values (

        v_user_id,

        v_today,

        v_reward.id,

        v_reward.reward_code,

        v_reward.reward_type,

        greatest(
            coalesce(
                v_reward.fan_amount,
                0
            ),
            0
        ),

        greatest(
            coalesce(
                v_reward.boost_rate_per_hour,
                0
            ),
            0
        ),

        greatest(
            coalesce(
                v_reward.boost_duration_minutes,
                0
            ),
            0
        )

    )

    returning id

    into v_spin_id;


    -- ========================================================
    -- UPDATE REAL FAN BALANCE
    -- ========================================================

    if v_reward.fan_amount > 0 then

        update public.profiles

        set

            fan_balance =
                v_new_balance,

            updated_at =
                now()

        where id = v_user_id;


        if not found then

            raise exception
                'FAN balance update failed';

        end if;

    end if;


    -- ========================================================
    -- DAILY SPIN LEDGER
    -- ========================================================

    insert into public.daily_spin_reward_ledger (

        user_id,

        spin_id,

        reward_type,

        amount,

        coin,

        description

    )

    values (

        v_user_id,

        v_spin_id,

        v_reward.reward_type,

        greatest(
            coalesce(
                v_reward.fan_amount,
                0
            ),
            0
        ),

        'FAN',

        case

            when v_reward.reward_type = 'fan'
            then 'Daily Spin FAN reward'

            when v_reward.reward_type = 'task_bonus'
            then 'Daily Spin task bonus'

            when v_reward.reward_type = 'mining_boost'
            then 'Daily Spin mining boost'

            when v_reward.reward_type = 'streak_boost'
            then 'Daily Spin streak boost'

            when v_reward.reward_type = 'try_again'
            then 'Daily Spin try again'

            else
                'Daily Spin reward'

        end

    )

    returning id

    into v_ledger_id;


    -- ========================================================
    -- WALLET TRANSACTION
    -- ========================================================
    --
    -- Only FAN-producing rewards are written as FAN balance
    -- transactions.
    --
    -- Non-FAN rewards remain represented in daily_spins and
    -- daily_spin_reward_ledger until their corresponding
    -- growth/boost engine consumes them.
    -- ========================================================

    if v_reward.fan_amount > 0 then

        insert into public.wallet_transactions (

            user_id,

            coin,

            transaction_type,

            amount,

            reference_id,

            description

        )

        values (

            v_user_id,

            'FAN',

            'daily_spin_reward',

            v_reward.fan_amount,

            v_spin_id,

            'Daily Spin reward: '
                || v_reward.title

        );

    end if;


    -- ========================================================
    -- RESPONSE
    -- ========================================================

    return jsonb_build_object(

        'success',
            true,

        'already_spun',
            false,

        'can_spin',
            false,

        'spin_id',
            v_spin_id,

        'ledger_id',
            v_ledger_id,

        'spin_date',
            v_today,

        'reward_code',
            v_reward.reward_code,

        'reward_title',
            v_reward.title,

        'reward_type',
            v_reward.reward_type,

        'fan_amount',
            v_reward.fan_amount,

        'boost_rate_per_hour',
            v_reward.boost_rate_per_hour,

        'boost_duration_minutes',
            v_reward.boost_duration_minutes,

        'fan_balance',
            v_new_balance,

        'next_spin_at',
            ((v_today + 1)::timestamptz),

        'message',
            'Daily Spin completed successfully'

    );


exception

    when unique_violation then

        -- Another request already created today's spin.
        select *

        into v_existing_spin

        from public.daily_spins

        where user_id = v_user_id

          and spin_date = v_today

        limit 1;


        if found then

            return jsonb_build_object(

                'success',
                    true,

                'already_spun',
                    true,

                'can_spin',
                    false,

                'spin_id',
                    v_existing_spin.id,

                'spin_date',
                    v_existing_spin.spin_date,

                'reward_code',
                    v_existing_spin.reward_code,

                'reward_type',
                    v_existing_spin.reward_type,

                'reward_title',
                    (
                        select title
                        from public.daily_spin_rewards
                        where id =
                            v_existing_spin.reward_id
                    ),

                'fan_amount',
                    v_existing_spin.fan_amount,

                'boost_rate_per_hour',
                    v_existing_spin.boost_rate_per_hour,

                'boost_duration_minutes',
                    v_existing_spin.boost_duration_minutes,

                'message',
                    'You have already used your Daily Spin today.'

            );

        end if;


        raise;

end;
$function$;


-- ============================================================
-- 9. RLS
-- ============================================================

alter table public.daily_spin_rewards
enable row level security;


alter table public.daily_spins
enable row level security;


alter table public.daily_spin_reward_ledger
enable row level security;


-- ============================================================
-- 10. REMOVE DIRECT CLIENT ACCESS
-- ============================================================

revoke all
on public.daily_spin_rewards
from anon, authenticated;


revoke all
on public.daily_spins
from anon, authenticated;


revoke all
on public.daily_spin_reward_ledger
from anon, authenticated;


-- Wallet transactions must not be directly writable by clients.
-- Existing trusted SECURITY DEFINER functions continue to
-- create wallet records.
-- ============================================================

revoke insert
on public.wallet_transactions
from authenticated;


revoke update
on public.wallet_transactions
from authenticated;


revoke delete
on public.wallet_transactions
from authenticated;


-- ============================================================
-- 11. SAFE CLIENT READ FOR WALLET TRANSACTIONS
-- ============================================================
--
-- Existing wallet screen can still read the user's own
-- transaction history.
-- ============================================================

drop policy if exists
"Users can view own wallet transactions"
on public.wallet_transactions;


create policy
"Users can view own wallet transactions"
on public.wallet_transactions

for select

to authenticated

using (
    auth.uid() = user_id
);


grant select
on public.wallet_transactions
to authenticated;


-- ============================================================
-- 12. RPC SECURITY
-- ============================================================

revoke execute
on function public.get_daily_spin_status()
from public, anon, authenticated;


grant execute
on function public.get_daily_spin_status()
to authenticated;


revoke execute
on function public.spin_daily()
from public, anon, authenticated;


grant execute
on function public.spin_daily()
to authenticated;


-- ============================================================
-- 13. SERVER-ONLY REWARD CONFIGURATION
-- ============================================================

revoke insert
on public.daily_spin_rewards
from public, anon, authenticated;


revoke update
on public.daily_spin_rewards
from public, anon, authenticated;


revoke delete
on public.daily_spin_rewards
from public, anon, authenticated;


-- ============================================================
-- 14. SERVER-ONLY SPIN HISTORY
-- ============================================================

revoke insert
on public.daily_spins
from public, anon, authenticated;


revoke update
on public.daily_spins
from public, anon, authenticated;


revoke delete
on public.daily_spins
from public, anon, authenticated;


-- ============================================================
-- 15. SERVER-ONLY SPIN LEDGER
-- ============================================================

revoke insert
on public.daily_spin_reward_ledger
from public, anon, authenticated;


revoke update
on public.daily_spin_reward_ledger
from public, anon, authenticated;


revoke delete
on public.daily_spin_reward_ledger
from public, anon, authenticated;


-- ============================================================
-- END OF REAL DAILY SPIN SYSTEM
-- ============================================================
