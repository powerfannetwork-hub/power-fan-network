-- ============================================================
-- POWER FAN NETWORK
-- SUPABASE PLUS MIGRATION - FINAL
-- ============================================================
--
-- FILE:
--   supabase/schema.plus.sql
--
-- RUN ORDER:
--   schema.sql
--   mining_engine.sql
--   rls.sql
--   schema.plus.sql
--
-- PURPOSE:
--   Adds the new POWER FAN NETWORK features on top of schema.sql
--   without recreating the existing mining engine.
--
-- FEATURES:
--   - Username
--   - Registration notice
--   - 30-day KYC check-in streak
--   - 30-day daily boost streak
--   - Face verification
--   - AFAM migration
--   - Social post/task system
--   - Device binding
--   - Device security warnings
--   - 30-day account suspension
--   - Security RPCs
--
-- IMPORTANT:
--   Mining calculation/session logic remains in mining_engine.sql.
-- ============================================================


create extension if not exists pgcrypto;


-- ============================================================
-- 1. PROFILE EXTENSIONS
-- ============================================================

alter table public.profiles
    add column if not exists username text;

alter table public.profiles
    add column if not exists kyc_checkin_streak integer default 0;

alter table public.profiles
    add column if not exists kyc_boost_streak integer default 0;

alter table public.profiles
    add column if not exists kyc_last_checkin_date date;

alter table public.profiles
    add column if not exists kyc_last_boost_date date;

alter table public.profiles
    add column if not exists kyc_face_verification_unlocked boolean default false;

alter table public.profiles
    add column if not exists kyc_face_verified boolean default false;

alter table public.profiles
    add column if not exists face_verification_started_at timestamptz;

alter table public.profiles
    add column if not exists migration_available boolean default false;

alter table public.profiles
    add column if not exists migration_completed boolean default false;

alter table public.profiles
    add column if not exists migration_completed_at timestamptz;

alter table public.profiles
    add column if not exists registration_notice_accepted boolean default false;

alter table public.profiles
    add column if not exists registration_notice_accepted_at timestamptz;

alter table public.profiles
    add column if not exists device_warning_count integer default 0;

alter table public.profiles
    add column if not exists last_device_warning_at timestamptz;

alter table public.profiles
    add column if not exists suspended_until timestamptz;

alter table public.profiles
    add column if not exists suspension_reason text;

alter table public.profiles
    add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 2. PROFILE DEFAULTS / BACKFILL
-- ============================================================

update public.profiles
set username = coalesce(
    nullif(trim(username), ''),
    nullif(trim(name), ''),
    'user_' || left(id::text, 8)
)
where username is null
   or trim(username) = '';


update public.profiles
set kyc_checkin_streak = 0
where kyc_checkin_streak is null;


update public.profiles
set kyc_boost_streak = 0
where kyc_boost_streak is null;


update public.profiles
set kyc_face_verification_unlocked = false
where kyc_face_verification_unlocked is null;


update public.profiles
set kyc_face_verified = false
where kyc_face_verified is null;


update public.profiles
set migration_available = false
where migration_available is null;


update public.profiles
set migration_completed = false
where migration_completed is null;


update public.profiles
set registration_notice_accepted = true
where registration_notice_accepted is null
  and created_at < now();


update public.profiles
set device_warning_count = 0
where device_warning_count is null;


-- KYC1 is unlocked after both 30-day streaks.
-- KYC2 is NOT automatically unlocked here.
update public.profiles
set kyc1_eligible =
    coalesce(kyc_checkin_streak, 0) >= 30
    and coalesce(kyc_boost_streak, 0) >= 30
where kyc1_eligible is null;


-- Keep KYC2 closed until its own server-side phase is opened.
update public.profiles
set kyc2_eligible = false
where kyc2_eligible is null;


-- ============================================================
-- 3. USERNAME UNIQUE INDEX
-- ============================================================

create unique index if not exists ux_profiles_username
on public.profiles(lower(username))
where username is not null;


-- ============================================================
-- 4. SOCIAL TASK EXTENSIONS
-- ============================================================

alter table public.social_tasks
    add column if not exists requires_join boolean default false;

alter table public.social_tasks
    add column if not exists requires_subscribe boolean default false;

alter table public.social_tasks
    add column if not exists is_initial_task boolean default false;

alter table public.social_tasks
    add column if not exists task_type text default 'initial';

alter table public.social_tasks
    add column if not exists post_external_id text;

alter table public.social_tasks
    add column if not exists post_published_at timestamptz;

alter table public.social_tasks
    add column if not exists starts_at timestamptz;

alter table public.social_tasks
    add column if not exists ends_at timestamptz;

alter table public.social_tasks
    add column if not exists updated_at timestamptz default now();


alter table public.social_task_claims
    add column if not exists join_verified boolean default false;

alter table public.social_task_claims
    add column if not exists subscribe_verified boolean default false;

alter table public.social_task_claims
    add column if not exists verification_message text;


-- ============================================================
-- 5. USER SOCIAL ACTIONS
-- ============================================================

create table if not exists public.user_social_actions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    task_id uuid
        references public.social_tasks(id)
        on delete cascade,

    platform text not null,

    action_type text not null,

    external_post_id text,

    verified boolean default false,

    verified_at timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);


-- Existing old uniqueness would prevent the same user
-- from completing actions on multiple different posts.
drop index if exists public.ux_user_social_actions;


create unique index if not exists ux_user_social_actions_task
on public.user_social_actions(
    user_id,
    task_id,
    action_type
);


-- ============================================================
-- 6. SOCIAL POSTS
-- ============================================================

create table if not exists public.social_posts (
    id uuid primary key default gen_random_uuid(),

    platform text not null,

    external_post_id text not null,

    title text,

    description text,

    url text not null,

    reward_fan numeric(24,8) default 0,

    published_at timestamptz default now(),

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);


-- ============================================================
-- 7. SOCIAL REWARD LEDGER
-- ============================================================

create table if not exists public.social_reward_ledger (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    task_id uuid
        references public.social_tasks(id)
        on delete cascade,

    reward_amount numeric(24,8) not null,

    reward_type text default 'social',

    reference_id uuid,

    created_at timestamptz default now()
);


-- ============================================================
-- 8. SOCIAL CLAIM UNIQUE INDEX
-- ============================================================

create unique index if not exists ux_social_task_claim_user_task
on public.social_task_claims(user_id, task_id);


-- ============================================================
-- 9. DEVICE BINDINGS
-- ============================================================

create table if not exists public.device_bindings (
    id uuid primary key default gen_random_uuid(),

    device_id text not null unique,

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    platform text,

    app_version text,

    first_seen_at timestamptz default now(),

    last_seen_at timestamptz default now(),

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);


create unique index if not exists ux_device_bindings_user
on public.device_bindings(user_id);


-- ============================================================
-- 10. DEVICE SECURITY EVENTS
-- ============================================================

create table if not exists public.device_security_events (
    id uuid primary key default gen_random_uuid(),

    device_id text not null,

    user_id uuid
        references public.profiles(id)
        on delete cascade,

    attempted_user_id uuid
        references public.profiles(id)
        on delete cascade,

    event_type text not null,

    warning_number integer default 0,

    reason text,

    created_at timestamptz default now()
);


create index if not exists idx_device_security_events_device
on public.device_security_events(device_id, created_at desc);


create index if not exists idx_device_security_events_user
on public.device_security_events(user_id, created_at desc);


-- ============================================================
-- 11. KYC DAILY ACTIVITY
-- ============================================================

create table if not exists public.kyc_daily_activity (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    activity_date date not null,

    check_in_completed boolean default false,

    boost_completed boolean default false,

    check_in_at timestamptz,

    boost_at timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);


create unique index if not exists ux_kyc_daily_activity_user_date
on public.kyc_daily_activity(user_id, activity_date);


-- ============================================================
-- 12. KYC FACE VERIFICATIONS
-- ============================================================

create table if not exists public.kyc_face_verifications (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    status text default 'pending',

    provider text,

    provider_reference text,

    verification_data jsonb,

    started_at timestamptz default now(),

    verified_at timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);


create index if not exists idx_kyc_face_verifications_user
on public.kyc_face_verifications(user_id, created_at desc);


-- ============================================================
-- 13. KYC MIGRATION SETTINGS
-- ============================================================

create table if not exists public.kyc_migration_settings (
    id integer primary key,

    migration_open boolean default false,

    fan_per_afam numeric(24,8) default 100,

    migration_message text,

    updated_at timestamptz default now()
);


insert into public.kyc_migration_settings(
    id,
    migration_open,
    fan_per_afam,
    migration_message
)
values (
    1,
    false,
    100,
    'Migration is Coming Soon.'
)
on conflict (id) do nothing;


-- ============================================================
-- 14. AFAM MIGRATIONS
-- ============================================================

create table if not exists public.afam_migrations (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    username text,

    fan_amount numeric(24,8) not null,

    afam_amount numeric(24,8) not null,

    conversion_rate numeric(24,8) default 100,

    status text default 'completed',

    created_at timestamptz default now()
);


create unique index if not exists ux_afam_migration_user
on public.afam_migrations(user_id);


-- ============================================================
-- 15. UPDATED_AT FUNCTION
-- ============================================================

create or replace function public.plus_set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;


-- ============================================================
-- 16. UPDATED_AT TRIGGERS
-- ============================================================

drop trigger if exists trg_profiles_plus_updated_at
on public.profiles;

create trigger trg_profiles_plus_updated_at
before update on public.profiles
for each row
execute function public.plus_set_updated_at();


drop trigger if exists trg_device_bindings_updated_at
on public.device_bindings;

create trigger trg_device_bindings_updated_at
before update on public.device_bindings
for each row
execute function public.plus_set_updated_at();


drop trigger if exists trg_kyc_daily_activity_updated_at
on public.kyc_daily_activity;

create trigger trg_kyc_daily_activity_updated_at
before update on public.kyc_daily_activity
for each row
execute function public.plus_set_updated_at();


drop trigger if exists trg_kyc_face_verifications_updated_at
on public.kyc_face_verifications;

create trigger trg_kyc_face_verifications_updated_at
before update on public.kyc_face_verifications
for each row
execute function public.plus_set_updated_at();


drop trigger if exists trg_social_posts_updated_at
on public.social_posts;

create trigger trg_social_posts_updated_at
before update on public.social_posts
for each row
execute function public.plus_set_updated_at();


-- ============================================================
-- 17. REGISTER DEVICE
-- ============================================================

drop function if exists public.register_device(text,text,text);

create or replace function public.register_device(
    p_device_id text,
    p_platform text,
    p_app_version text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_bound_user uuid;

    v_warning_count integer;

    v_suspended_until timestamptz;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    if p_device_id is null
       or trim(p_device_id) = '' then

        return jsonb_build_object(
            'success', false,
            'message', 'Device ID is required'
        );
    end if;


    select user_id
    into v_bound_user
    from public.device_bindings
    where device_id = p_device_id
    limit 1;


    -- Device has never been bound.
    if v_bound_user is null then

        -- One device per account.
        if exists (
            select 1
            from public.device_bindings
            where user_id = v_user_id
        ) then

            return jsonb_build_object(
                'success', false,
                'warning', true,
                'message',
                'This account is already bound to another device.'
            );

        end if;


        insert into public.device_bindings(
            device_id,
            user_id,
            platform,
            app_version
        )
        values(
            p_device_id,
            v_user_id,
            p_platform,
            p_app_version
        );


        return jsonb_build_object(
            'success', true,
            'bound', true,
            'warning', false
        );

    end if;


    -- Same user / same device.
    if v_bound_user = v_user_id then

        update public.device_bindings
        set platform = p_platform,
            app_version = p_app_version,
            last_seen_at = now()
        where device_id = p_device_id;


        return jsonb_build_object(
            'success', true,
            'bound', true,
            'warning', false
        );

    end if;


    -- Device belongs to another account.
    select
        coalesce(device_warning_count, 0),
        suspended_until
    into
        v_warning_count,
        v_suspended_until
    from public.profiles
    where id = v_bound_user
    for update;


    v_warning_count :=
        coalesce(v_warning_count, 0) + 1;


    -- Third attempt => 30-day suspension.
    if v_warning_count >= 3 then

        v_suspended_until :=
            now() + interval '30 days';


        update public.profiles
        set device_warning_count = v_warning_count,

            last_device_warning_at = now(),

            suspended_until = v_suspended_until,

            suspension_reason =
                'Multiple account attempts detected on the same device.'
        where id = v_bound_user;


        insert into public.device_security_events(
            device_id,
            user_id,
            attempted_user_id,
            event_type,
            warning_number,
            reason
        )
        values(
            p_device_id,
            v_bound_user,
            v_user_id,
            'suspension',
            v_warning_count,
            'Third multiple-account attempt. Account suspended for 30 days.'
        );


        return jsonb_build_object(
            'success', false,
            'suspended', true,
            'warning', true,
            'warning_count', v_warning_count,
            'suspended_until', v_suspended_until,
            'message',
            'This device has been used with another account. After two warnings, this attempt has caused a 30-day suspension.'
        );

    end if;


    update public.profiles
    set device_warning_count = v_warning_count,

        last_device_warning_at = now()
    where id = v_bound_user;


    insert into public.device_security_events(
        device_id,
        user_id,
        attempted_user_id,
        event_type,
        warning_number,
        reason
    )
    values(
        p_device_id,
        v_bound_user,
        v_user_id,
        'warning',
        v_warning_count,
        'Multiple account attempt detected.'
    );


    return jsonb_build_object(
        'success', false,
        'warning', true,
        'warning_count', v_warning_count,
        'message',
        'Warning: this device is already linked to another account. Another attempt after two warnings will cause a 30-day suspension.'
    );

end;
$$;


-- ============================================================
-- 18. INITIAL SOCIAL TASK STATUS
-- ============================================================
--
-- Created before get_daily_social_tasks because that function
-- calls this function.
-- ============================================================

drop function if exists public.are_initial_social_tasks_complete(uuid);

create or replace function public.are_initial_social_tasks_complete(
    p_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
    select not exists(
        select 1
        from public.social_tasks t
        where t.is_active = true
          and t.is_initial_task = true
          and not exists(
              select 1
              from public.social_task_claims c
              where c.user_id = p_user_id
                and c.task_id = t.id
                and c.claimed_at is not null
          )
    );
$$;


-- ============================================================
-- 19. GET KYC PROGRESS
-- ============================================================

drop function if exists public.get_kyc_progress();

create or replace function public.get_kyc_progress()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_checkin integer;

    v_boost integer;

    v_last_checkin date;

    v_last_boost date;

    v_face_unlocked boolean;

    v_face_verified boolean;

    v_migration_open boolean;

    v_migration_completed boolean;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select
        coalesce(kyc_checkin_streak, 0),
        coalesce(kyc_boost_streak, 0),
        kyc_last_checkin_date,
        kyc_last_boost_date,
        coalesce(kyc_face_verification_unlocked, false),
        coalesce(kyc_face_verified, false),
        coalesce(migration_completed, false)
    into
        v_checkin,
        v_boost,
        v_last_checkin,
        v_last_boost,
        v_face_unlocked,
        v_face_verified,
        v_migration_completed
    from public.profiles
    where id = v_user_id
    for update;


    -- Missing a day resets the corresponding streak.
    if v_last_checkin is not null
       and v_last_checkin < current_date - 1 then

        v_checkin := 0;

        update public.profiles
        set kyc_checkin_streak = 0
        where id = v_user_id;

    end if;


    if v_last_boost is not null
       and v_last_boost < current_date - 1 then

        v_boost := 0;

        update public.profiles
        set kyc_boost_streak = 0
        where id = v_user_id;

    end if;


    -- 30 check-in days + 30 boost days unlock KYC1 face verification.
    if v_checkin >= 30
       and v_boost >= 30 then

        update public.profiles
        set kyc1_eligible = true,

            kyc_face_verification_unlocked = true
        where id = v_user_id;


        v_face_unlocked := true;

    end if;


    select migration_open
    into v_migration_open
    from public.kyc_migration_settings
    where id = 1;


    return jsonb_build_object(
        'success', true,

        'kyc_checkin_days', v_checkin,

        'checkin_days', v_checkin,

        'kyc_boost_days', v_boost,

        'boost_days', v_boost,

        'kyc_face_verification_unlocked',
            v_face_unlocked,

        'face_verification_unlocked',
            v_face_unlocked,

        'kyc_face_verified',
            v_face_verified,

        'face_verified',
            v_face_verified,

        'face_verification_started',
            exists(
                select 1
                from public.kyc_face_verifications
                where user_id = v_user_id
                  and status = 'pending'
            ),

        'migration_available',
            v_face_verified
            and coalesce(v_migration_open, false)
            and not v_migration_completed,

        'migration_completed',
            v_migration_completed,

        'coming_soon',
            not coalesce(v_migration_open, false),

        'success_message',
            'KYC progress loaded successfully.'
    );

end;
$$;


-- ============================================================
-- 20. CLAIM DAILY CHECK-IN
-- ============================================================

drop function if exists public.claim_daily_checkin();

create or replace function public.claim_daily_checkin()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_last_date date;

    v_streak integer;

    v_activity_id uuid;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select
        kyc_last_checkin_date,
        coalesce(kyc_checkin_streak, 0)
    into
        v_last_date,
        v_streak
    from public.profiles
    where id = v_user_id
    for update;


    if v_last_date = current_date then

        return jsonb_build_object(
            'success', false,
            'already_checked_in', true,
            'checkin_days', v_streak,
            'message', 'Daily check-in already completed.'
        );

    end if;


    if v_last_date = current_date - 1 then
        v_streak := v_streak + 1;
    else
        v_streak := 1;
    end if;


    insert into public.kyc_daily_activity(
        user_id,
        activity_date,
        check_in_completed,
        check_in_at
    )
    values(
        v_user_id,
        current_date,
        true,
        now()
    )
    on conflict(user_id, activity_date)
    do update set
        check_in_completed = true,
        check_in_at = coalesce(
            public.kyc_daily_activity.check_in_at,
            now()
        )
    returning id into v_activity_id;


    update public.profiles
    set
        kyc_checkin_streak = v_streak,

        kyc_last_checkin_date = current_date,

        consecutive_check_ins = v_streak,

        kyc1_eligible =
            v_streak >= 30
            and coalesce(kyc_boost_streak, 0) >= 30,

        kyc_face_verification_unlocked =
            v_streak >= 30
            and coalesce(kyc_boost_streak, 0) >= 30

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'checkin_days', v_streak,

        'kyc_checkin_days', v_streak,

        'activity_id', v_activity_id,

        'message', 'Daily check-in completed.'
    );

end;
$$;


-- ============================================================
-- 21. RECORD DAILY BOOST
-- ============================================================

drop function if exists public.record_daily_boost();

create or replace function public.record_daily_boost()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_last_date date;

    v_streak integer;

    v_activity_id uuid;

    v_ad_watched boolean;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    -- A boost streak requires a real rewarded ad record.
    select exists(
        select 1
        from public.ad_rewards ar
        where ar.user_id = v_user_id
          and ar.watched_at::date = current_date
    )
    into v_ad_watched;


    if not v_ad_watched then

        return jsonb_build_object(
            'success', false,
            'message',
            'A successful rewarded ad is required before recording today''s boost.'
        );

    end if;


    select
        kyc_last_boost_date,
        coalesce(kyc_boost_streak, 0)
    into
        v_last_date,
        v_streak
    from public.profiles
    where id = v_user_id
    for update;


    if v_last_date = current_date then

        return jsonb_build_object(
            'success', false,
            'already_boosted', true,
            'boost_days', v_streak,
            'message', 'Daily boost already recorded.'
        );

    end if;


    if v_last_date = current_date - 1 then
        v_streak := v_streak + 1;
    else
        v_streak := 1;
    end if;


    insert into public.kyc_daily_activity(
        user_id,
        activity_date,
        boost_completed,
        boost_at
    )
    values(
        v_user_id,
        current_date,
        true,
        now()
    )
    on conflict(user_id, activity_date)
    do update set
        boost_completed = true,
        boost_at = coalesce(
            public.kyc_daily_activity.boost_at,
            now()
        )
    returning id into v_activity_id;


    update public.profiles
    set
        kyc_boost_streak = v_streak,

        kyc_last_boost_date = current_date,

        kyc1_eligible =
            coalesce(kyc_checkin_streak, 0) >= 30
            and v_streak >= 30,

        kyc_face_verification_unlocked =
            coalesce(kyc_checkin_streak, 0) >= 30
            and v_streak >= 30

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'boost_days', v_streak,

        'kyc_boost_days', v_streak,

        'activity_id', v_activity_id,

        'message', 'Daily boost recorded.'
    );

end;
$$;


-- ============================================================
-- 22. START FACE VERIFICATION
-- ============================================================

drop function if exists public.start_face_verification();

create or replace function public.start_face_verification()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_id uuid;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    if not exists(
        select 1
        from public.profiles
        where id = v_user_id

          and coalesce(kyc_checkin_streak, 0) >= 30

          and coalesce(kyc_boost_streak, 0) >= 30
    ) then

        return jsonb_build_object(
            'success', false,
            'message',
            'Complete both 30-day streaks before face verification.'
        );

    end if;


    if exists(
        select 1
        from public.kyc_face_verifications
        where user_id = v_user_id
          and status = 'pending'
    ) then

        select id
        into v_id
        from public.kyc_face_verifications
        where user_id = v_user_id
          and status = 'pending'
        order by created_at desc
        limit 1;

    else

        insert into public.kyc_face_verifications(
            user_id,
            status,
            provider,
            started_at
        )
        values(
            v_user_id,
            'pending',
            'pending_provider',
            now()
        )
        returning id into v_id;

    end if;


    update public.profiles
    set face_verification_started_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'verification_id', v_id,

        'message',
        'Face verification is ready. A real verification provider must verify the face.'
    );

end;
$$;


-- ============================================================
-- 23. COMPLETE FACE VERIFICATION
-- ============================================================

drop function if exists public.complete_face_verification(uuid);

create or replace function public.complete_face_verification(
    p_verification_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_status text;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select status
    into v_status
    from public.kyc_face_verifications
    where id = p_verification_id
      and user_id = v_user_id;


    if not found then
        return jsonb_build_object(
            'success', false,
            'message', 'Verification record not found.'
        );
    end if;


    if v_status <> 'verified' then
        return jsonb_build_object(
            'success', false,
            'message',
            'Face verification has not been verified by the verification provider.'
        );
    end if;


    update public.profiles
    set
        kyc_face_verified = true,

        kyc1_verified = true,

        migration_available =
            exists(
                select 1
                from public.kyc_migration_settings
                where id = 1
                  and migration_open = true
            )

    where id = v_user_id;


    update public.kyc_face_verifications
    set
        verified_at = coalesce(verified_at, now()),

        updated_at = now()

    where id = p_verification_id;


    return jsonb_build_object(
        'success', true,

        'face_verified', true,

        'message', 'Face verification completed.'
    );

end;
$$;


-- ============================================================
-- 24. TRUSTED FACE VERIFICATION
-- ============================================================

drop function if exists public.confirm_face_verification(uuid,text);

create or replace function public.confirm_face_verification(
    p_verification_id uuid,
    p_provider_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
begin

    select user_id
    into v_user_id
    from public.kyc_face_verifications
    where id = p_verification_id
    for update;


    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Verification record not found.'
        );
    end if;


    update public.kyc_face_verifications
    set
        status = 'verified',

        provider = 'trusted_provider',

        provider_reference = p_provider_reference,

        verified_at = now(),

        updated_at = now()

    where id = p_verification_id;


    update public.profiles
    set
        kyc_face_verified = true,

        kyc1_verified = true,

        migration_available =
            exists(
                select 1
                from public.kyc_migration_settings
                where id = 1
                  and migration_open = true
            )

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'user_id', v_user_id,

        'verification_id', p_verification_id
    );

end;
$$;


-- ============================================================
-- 25. MIGRATION STATUS
-- ============================================================

drop function if exists public.get_migration_status();

create or replace function public.get_migration_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_open boolean;

    v_rate numeric(24,8);

    v_face_verified boolean;

    v_completed boolean;

    v_fan numeric(24,8);

    v_afam numeric(24,8);
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select
        migration_open,
        fan_per_afam
    into
        v_open,
        v_rate
    from public.kyc_migration_settings
    where id = 1;


    select
        coalesce(kyc_face_verified, false),

        coalesce(migration_completed, false),

        coalesce(fan_balance, 0),

        coalesce(afam_balance, 0)

    into
        v_face_verified,

        v_completed,

        v_fan,

        v_afam

    from public.profiles

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'migration_open',
            coalesce(v_open, false),

        'migration_available',
            coalesce(v_open, false)
            and v_face_verified
            and not v_completed,

        'face_verified',
            v_face_verified,

        'migration_completed',
            v_completed,

        'fan_balance',
            v_fan,

        'afam_balance',
            v_afam,

        'fan_per_afam',
            coalesce(v_rate, 100),

        'message',
            case

                when not coalesce(v_open, false)
                    then 'Migration is Coming Soon.'

                when not v_face_verified
                    then 'Complete face verification first.'

                when v_completed
                    then 'Migration already completed.'

                else
                    'Migration is available.'

            end
    );

end;
$$;


-- ============================================================
-- 26. MIGRATE FAN TO AFAM
-- ============================================================

drop function if exists public.migrate_fan_to_afam();

create or replace function public.migrate_fan_to_afam()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_username text;

    v_fan numeric(24,8);

    v_afam numeric(24,8);

    v_rate numeric(24,8);

    v_new_afam numeric(24,8);

    v_migration_id uuid;

    v_completed boolean;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select fan_per_afam
    into v_rate
    from public.kyc_migration_settings
    where id = 1
      and migration_open = true;


    if v_rate is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Migration is not open.'
        );
    end if;


    select
        username,

        coalesce(fan_balance, 0),

        coalesce(afam_balance, 0),

        coalesce(migration_completed, false)

    into
        v_username,

        v_fan,

        v_afam,

        v_completed

    from public.profiles

    where id = v_user_id

    for update;


    if not coalesce(
        (
            select kyc_face_verified
            from public.profiles
            where id = v_user_id
        ),
        false
    ) then

        return jsonb_build_object(
            'success', false,
            'message', 'Face verification required.'
        );

    end if;


    if v_completed then

        return jsonb_build_object(
            'success', false,
            'message', 'Migration already completed.'
        );

    end if;


    if v_fan <= 0 then

        return jsonb_build_object(
            'success', false,
            'message', 'No FAN balance available for migration.'
        );

    end if;


    v_new_afam := v_fan / v_rate;


    insert into public.afam_migrations(
        user_id,
        username,
        fan_amount,
        afam_amount,
        conversion_rate,
        status
    )
    values(
        v_user_id,
        v_username,
        v_fan,
        v_new_afam,
        v_rate,
        'completed'
    )
    returning id into v_migration_id;


    update public.profiles
    set
        fan_balance = 0,

        afam_balance = v_afam + v_new_afam,

        migration_completed = true,

        migration_completed_at = now(),

        migration_available = false

    where id = v_user_id;


    insert into public.wallet_transactions(
        user_id,
        coin,
        transaction_type,
        amount,
        reference_id,
        description
    )
    values(
        v_user_id,
        'AFAM',
        'migration',
        v_new_afam,
        v_migration_id,
        'FAN to AFAM migration at 100 FAN = 1 AFAM.'
    );


    return jsonb_build_object(
        'success', true,

        'username', v_username,

        'fan_converted', v_fan,

        'afam_received', v_new_afam,

        'migration_id', v_migration_id,

        'message', 'FAN successfully migrated to AFAM.'
    );

end;
$$;


-- ============================================================
-- 27. DAILY SOCIAL TASKS
-- ============================================================

drop function if exists public.get_daily_social_tasks();

create or replace function public.get_daily_social_tasks()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_initial_done boolean;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select public.are_initial_social_tasks_complete(v_user_id)
    into v_initial_done;


    return coalesce(
        (
            select jsonb_agg(
                jsonb_build_object(

                    'id',
                        t.id,

                    'title',
                        t.title,

                    'description',
                        t.description,

                    'platform',
                        t.platform,

                    'url',
                        t.url,

                    'task_url',
                        t.url,

                    'reward_fan',
                        t.reward_fan,

                    'requires_follow',
                        coalesce(t.requires_follow, false),

                    'requires_like',
                        coalesce(t.requires_like, false),

                    'requires_comment',
                        coalesce(t.requires_comment, false),

                    'requires_share',
                        coalesce(t.requires_share, false),

                    'requires_join',
                        coalesce(t.requires_join, false),

                    'requires_subscribe',
                        coalesce(t.requires_subscribe, false),

                    'is_initial_task',
                        coalesce(t.is_initial_task, false),

                    'task_type',
                        t.task_type,

                    'post_external_id',
                        t.post_external_id,

                    'post_published_at',
                        t.post_published_at,

                    'task_date',
                        current_date,

                    'claimed',
                        c.claimed_at is not null,

                    'can_claim',
                        c.claimed_at is null

                        and
                        (
                            not coalesce(t.requires_follow, false)
                            or coalesce(c.follow_verified, false)
                        )

                        and
                        (
                            not coalesce(t.requires_like, false)
                            or coalesce(c.like_verified, false)
                        )

                        and
                        (
                            not coalesce(t.requires_comment, false)
                            or coalesce(c.comment_verified, false)
                        )

                        and
                        (
                            not coalesce(t.requires_share, false)
                            or coalesce(c.share_verified, false)
                        )

                        and
                        (
                            not coalesce(t.requires_join, false)
                            or coalesce(c.join_verified, false)
                        )

                        and
                        (
                            not coalesce(t.requires_subscribe, false)
                            or coalesce(c.subscribe_verified, false)
                        )
                )

                order by t.created_at

            )

            from public.social_tasks t

            left join public.social_task_claims c
                on c.task_id = t.id
               and c.user_id = v_user_id

            where t.is_active = true

              and
              (
                  (
                      not v_initial_done

                      and t.is_initial_task = true
                  )

                  or

                  (
                      v_initial_done

                      and t.is_initial_task = false

                      and t.post_external_id is not null

                      and (
                          t.starts_at is null
                          or now() >= t.starts_at
                      )

                      and (
                          t.ends_at is null
                          or now() <= t.ends_at
                      )
                  )
              )
        ),

        '[]'::jsonb
    );

end;
$$;


-- ============================================================
-- 28. START SOCIAL TASK
-- ============================================================

drop function if exists public.start_social_task(uuid);

create or replace function public.start_social_task(
    p_task_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_claim_id uuid;

    v_initial_done boolean;

    v_is_initial boolean;

    v_is_active boolean;

    v_post_external_id text;

    v_starts_at timestamptz;

    v_ends_at timestamptz;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select
        coalesce(is_initial_task, false),

        coalesce(is_active, false),

        post_external_id,

        starts_at,

        ends_at

    into
        v_is_initial,

        v_is_active,

        v_post_external_id,

        v_starts_at,

        v_ends_at

    from public.social_tasks

    where id = p_task_id;


    if not found then
        return jsonb_build_object(
            'success', false,
            'message', 'Social task not found.'
        );
    end if;


    if not v_is_active then
        return jsonb_build_object(
            'success', false,
            'message', 'This social task is not active.'
        );
    end if;


    if v_starts_at is not null
       and now() < v_starts_at then

        return jsonb_build_object(
            'success', false,
            'message', 'This social task is not available yet.'
        );

    end if;


    if v_ends_at is not null
       and now() > v_ends_at then

        return jsonb_build_object(
            'success', false,
            'message', 'This social task has expired.'
        );

    end if;


    select public.are_initial_social_tasks_complete(v_user_id)
    into v_initial_done;


    if v_is_initial then

        if v_initial_done then
            return jsonb_build_object(
                'success', false,
                'message',
                'Initial social tasks are already completed.'
            );
        end if;

    else

        if not v_initial_done then
            return jsonb_build_object(
                'success', false,
                'message',
                'Complete the initial social tasks first.'
            );
        end if;


        if v_post_external_id is null then
            return jsonb_build_object(
                'success', false,
                'message',
                'Invalid post task.'
            );
        end if;

    end if;


    insert into public.social_task_claims(
        user_id,
        task_id,
        task_date,
        started_at
    )
    values(
        v_user_id,
        p_task_id,
        current_date,
        now()
    )

    on conflict(user_id, task_id)

    do update set
        started_at = coalesce(
            public.social_task_claims.started_at,
            now()
        )

    returning id into v_claim_id;


    return jsonb_build_object(
        'success', true,

        'claim_id', v_claim_id,

        'message', 'Social task started.'
    );

end;
$$;


-- ============================================================
-- 29. CLAIM DAILY SOCIAL REWARD
-- ============================================================

drop function if exists public.claim_daily_social_reward(uuid);

create or replace function public.claim_daily_social_reward(
    p_task_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_reward numeric(24,8);

    v_claim_id uuid;

    v_follow boolean;

    v_like boolean;

    v_comment boolean;

    v_share boolean;

    v_join boolean;

    v_subscribe boolean;

    v_requires_follow boolean;

    v_requires_like boolean;

    v_requires_comment boolean;

    v_requires_share boolean;

    v_requires_join boolean;

    v_requires_subscribe boolean;

    v_is_initial boolean;

    v_post_external_id text;

    v_starts_at timestamptz;

    v_ends_at timestamptz;

    v_initial_done boolean;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select

        reward_fan,

        coalesce(requires_follow, false),

        coalesce(requires_like, false),

        coalesce(requires_comment, false),

        coalesce(requires_share, false),

        coalesce(requires_join, false),

        coalesce(requires_subscribe, false),

        coalesce(is_initial_task, false),

        post_external_id,

        starts_at,

        ends_at

    into

        v_reward,

        v_requires_follow,

        v_requires_like,

        v_requires_comment,

        v_requires_share,

        v_requires_join,

        v_requires_subscribe,

        v_is_initial,

        v_post_external_id,

        v_starts_at,

        v_ends_at

    from public.social_tasks

    where id = p_task_id

      and is_active = true;


    if not found then
        return jsonb_build_object(
            'success', false,
            'message', 'Social task not found.'
        );
    end if;


    if v_starts_at is not null
       and now() < v_starts_at then

        return jsonb_build_object(
            'success', false,
            'message', 'This social task is not available yet.'
        );

    end if;


    if v_ends_at is not null
       and now() > v_ends_at then

        return jsonb_build_object(
            'success', false,
            'message', 'This social task has expired.'
        );

    end if;


    select public.are_initial_social_tasks_complete(v_user_id)
    into v_initial_done;


    if v_is_initial then

        if v_initial_done then
            return jsonb_build_object(
                'success', false,
                'message',
                'Initial social tasks are already completed.'
            );
        end if;

    else

        if not v_initial_done then
            return jsonb_build_object(
                'success', false,
                'message',
                'Complete the initial social tasks first.'
            );
        end if;


        if v_post_external_id is null then
            return jsonb_build_object(
                'success', false,
                'message',
                'Invalid post task.'
            );
        end if;

    end if;


    select
        id,

        follow_verified,

        like_verified,

        comment_verified,

        share_verified,

        join_verified,

        subscribe_verified

    into
        v_claim_id,

        v_follow,

        v_like,

        v_comment,

        v_share,

        v_join,

        v_subscribe

    from public.social_task_claims

    where user_id = v_user_id

      and task_id = p_task_id

    for update;


    if v_claim_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Start the social task first.'
        );
    end if;


    if (
        v_requires_follow
        and not coalesce(v_follow, false)
    )

    or (
        v_requires_like
        and not coalesce(v_like, false)
    )

    or (
        v_requires_comment
        and not coalesce(v_comment, false)
    )

    or (
        v_requires_share
        and not coalesce(v_share, false)
    )

    or (
        v_requires_join
        and not coalesce(v_join, false)
    )

    or (
        v_requires_subscribe
        and not coalesce(v_subscribe, false)
    ) then

        return jsonb_build_object(
            'success', false,
            'message',
            'Complete all required social actions before claiming.'
        );

    end if;


    if exists(
        select 1
        from public.social_task_claims
        where id = v_claim_id
          and claimed_at is not null
    ) then

        return jsonb_build_object(
            'success', false,
            'message',
            'This social reward has already been claimed.'
        );

    end if;


    update public.social_task_claims
    set
        verified_at = coalesce(
            verified_at,
            now()
        ),

        claimed_at = now(),

        reward_amount = v_reward

    where id = v_claim_id;


    insert into public.social_reward_ledger(
        user_id,
        task_id,
        reward_amount,
        reward_type,
        reference_id
    )
    values(
        v_user_id,
        p_task_id,
        v_reward,
        'social',
        v_claim_id
    );


    update public.profiles
    set
        fan_balance =
            coalesce(fan_balance, 0) + v_reward,

        last_social_claim_date = current_date

    where id = v_user_id;


    insert into public.wallet_transactions(
        user_id,
        coin,
        transaction_type,
        amount,
        reference_id,
        description
    )
    values(
        v_user_id,
        'FAN',
        'social_reward',
        v_reward,
        v_claim_id,
        'Social task reward.'
    );


    return jsonb_build_object(
        'success', true,

        'reward_amount', v_reward,

        'message',
        'Social reward claimed successfully.'
    );

end;
$$;


-- ============================================================
-- 30. SOCIAL POST -> TASK TRIGGER
-- ============================================================

create or replace function public.create_social_task_from_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    -- Do not create another task for the same platform/post.
    if exists(
        select 1
        from public.social_tasks
        where platform = new.platform
          and post_external_id = new.external_post_id
    ) then

        return new;

    end if;


    insert into public.social_tasks(
        title,
        description,
        platform,
        url,
        reward_fan,
        requires_follow,
        requires_like,
        requires_comment,
        requires_share,
        requires_join,
        requires_subscribe,
        is_initial_task,
        task_type,
        post_external_id,
        post_published_at,
        starts_at,
        is_active
    )
    values(
        coalesce(
            new.title,
            'New POWER FAN NETWORK Post'
        ),

        coalesce(
            new.description,
            'Complete Like, Comment and Share to claim your FAN reward.'
        ),

        new.platform,

        new.url,

        new.reward_fan,

        false,

        true,

        true,

        true,

        false,

        false,

        false,

        'post',

        new.external_post_id,

        new.published_at,

        new.published_at,

        new.is_active
    );


    return new;

end;
$$;


drop trigger if exists trg_social_post_creates_task
on public.social_posts;


create trigger trg_social_post_creates_task
after insert on public.social_posts
for each row
execute function public.create_social_task_from_post();


-- ============================================================
-- 31. TRUSTED SOCIAL TASK VERIFICATION
-- ============================================================

drop function if exists public.verify_social_task_action(uuid,uuid,text,boolean);

create or replace function public.verify_social_task_action(
    p_user_id uuid,
    p_task_id uuid,
    p_action text,
    p_verified boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_platform text;

    v_post_external_id text;
begin

    if p_action not in (
        'follow',
        'like',
        'comment',
        'share',
        'join',
        'subscribe'
    ) then

        return jsonb_build_object(
            'success', false,
            'message', 'Invalid social action.'
        );

    end if;


    -- Verify task exists and is active.
    select
        platform,
        post_external_id
    into
        v_platform,
        v_post_external_id
    from public.social_tasks
    where id = p_task_id
      and is_active = true;


    if not found then

        return jsonb_build_object(
            'success', false,
            'message', 'Social task not found or inactive.'
        );

    end if;


    -- Respect task time window.
    if exists(
        select 1
        from public.social_tasks
        where id = p_task_id
          and (
              starts_at is not null
              and now() < starts_at
          )
    ) then

        return jsonb_build_object(
            'success', false,
            'message', 'Social task is not available yet.'
        );

    end if;


    if exists(
        select 1
        from public.social_tasks
        where id = p_task_id
          and (
              ends_at is not null
              and now() > ends_at
          )
    ) then

        return jsonb_build_object(
            'success', false,
            'message', 'Social task has expired.'
        );

    end if;


    insert into public.social_task_claims(
        user_id,
        task_id,
        task_date,
        started_at
    )
    values(
        p_user_id,
        p_task_id,
        current_date,
        now()
    )
    on conflict(user_id, task_id)
    do nothing;


    if p_action = 'follow' then

        update public.social_task_claims
        set
            follow_verified = p_verified,

            verified_at =
                case
                    when p_verified
                        then now()
                    else verified_at
                end

        where user_id = p_user_id
          and task_id = p_task_id;


    elsif p_action = 'like' then

        update public.social_task_claims
        set
            like_verified = p_verified,

            verified_at =
                case
                    when p_verified
                        then now()
                    else verified_at
                end

        where user_id = p_user_id
          and task_id = p_task_id;


    elsif p_action = 'comment' then

        update public.social_task_claims
        set
            comment_verified = p_verified,

            verified_at =
                case
                    when p_verified
                        then now()
                    else verified_at
                end

        where user_id = p_user_id
          and task_id = p_task_id;


    elsif p_action = 'share' then

        update public.social_task_claims
        set
            share_verified = p_verified,

            verified_at =
                case
                    when p_verified
                        then now()
                    else verified_at
                end

        where user_id = p_user_id
          and task_id = p_task_id;


    elsif p_action = 'join' then

        update public.social_task_claims
        set
            join_verified = p_verified,

            verified_at =
                case
                    when p_verified
                        then now()
                    else verified_at
                end

        where user_id = p_user_id
          and task_id = p_task_id;


    elsif p_action = 'subscribe' then

        update public.social_task_claims
        set
            subscribe_verified = p_verified,

            verified_at =
                case
                    when p_verified
                        then now()
                    else verified_at
                end

        where user_id = p_user_id
          and task_id = p_task_id;

    end if;


    insert into public.user_social_actions(
        user_id,
        task_id,
        platform,
        action_type,
        external_post_id,
        verified,
        verified_at
    )
    values(
        p_user_id,
        p_task_id,
        v_platform,
        p_action,
        v_post_external_id,
        p_verified,
        case
            when p_verified then now()
            else null
        end
    )
    on conflict(user_id, task_id, action_type)
    do update set
        verified = excluded.verified,

        verified_at = excluded.verified_at,

        external_post_id =
            excluded.external_post_id,

        updated_at = now();


    return jsonb_build_object(
        'success', true,

        'verified', p_verified,

        'action', p_action
    );

end;
$$;


-- ============================================================
-- 32. REGISTRATION NOTICE
-- ============================================================

drop function if exists public.accept_registration_notice();

create or replace function public.accept_registration_notice()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    update public.profiles
    set
        registration_notice_accepted = true,

        registration_notice_accepted_at = now()

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'message', 'Registration notice accepted.'
    );

end;
$$;


-- ============================================================
-- 33. ACCOUNT SECURITY STATUS
-- ============================================================

drop function if exists public.get_account_security_status();

create or replace function public.get_account_security_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_username text;

    v_warning_count integer;

    v_suspended_until timestamptz;

    v_reason text;

    v_registration_notice boolean;
begin

    if v_user_id is null then
        return jsonb_build_object(
            'success', false,
            'message', 'Authentication required'
        );
    end if;


    select
        username,

        coalesce(device_warning_count, 0),

        suspended_until,

        suspension_reason,

        coalesce(registration_notice_accepted, false)

    into
        v_username,

        v_warning_count,

        v_suspended_until,

        v_reason,

        v_registration_notice

    from public.profiles

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,

        'username',
            v_username,

        'warning_count',
            v_warning_count,

        'suspended',
            v_suspended_until is not null
            and v_suspended_until > now(),

        'suspended_until',
            v_suspended_until,

        'suspension_reason',
            v_reason,

        'registration_notice_accepted',
            v_registration_notice
    );

end;
$$;


-- ============================================================
-- 34. SET MIGRATION STATUS
-- ============================================================

drop function if exists public.set_migration_status(boolean);

create or replace function public.set_migration_status(
    p_open boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin

    update public.kyc_migration_settings
    set
        migration_open = p_open,

        updated_at = now()

    where id = 1;


    update public.profiles
    set
        migration_available =
            coalesce(kyc_face_verified, false)

            and p_open

            and not coalesce(migration_completed, false);


    return jsonb_build_object(
        'success', true,

        'migration_open', p_open
    );

end;
$$;


-- ============================================================
-- 35. INDEXES
-- ============================================================

create index if not exists idx_profiles_username
on public.profiles(lower(username));


create index if not exists idx_profiles_kyc_streaks
on public.profiles(
    kyc_checkin_streak,
    kyc_boost_streak
);


create index if not exists idx_profiles_suspension
on public.profiles(suspended_until);


create index if not exists idx_social_posts_active
on public.social_posts(
    is_active,
    published_at desc
);


create index if not exists idx_social_posts_external
on public.social_posts(
    platform,
    external_post_id
);


create index if not exists idx_social_tasks_post
on public.social_tasks(
    platform,
    post_external_id
);


create index if not exists idx_user_social_actions_user
on public.user_social_actions(
    user_id,
    created_at desc
);


create index if not exists idx_user_social_actions_task
on public.user_social_actions(
    task_id,
    action_type
);


create index if not exists idx_social_reward_ledger_user
on public.social_reward_ledger(
    user_id,
    created_at desc
);


create index if not exists idx_device_bindings_user
on public.device_bindings(user_id);


create index if not exists idx_kyc_daily_activity_user
on public.kyc_daily_activity(
    user_id,
    activity_date desc
);


create index if not exists idx_afam_migrations_user
on public.afam_migrations(user_id);


-- ============================================================
-- 36. RLS - NEW TABLES
-- ============================================================

alter table public.user_social_actions
enable row level security;


alter table public.social_posts
enable row level security;


alter table public.social_reward_ledger
enable row level security;


alter table public.device_bindings
enable row level security;


alter table public.device_security_events
enable row level security;


alter table public.kyc_daily_activity
enable row level security;


alter table public.kyc_face_verifications
enable row level security;


alter table public.kyc_migration_settings
enable row level security;


alter table public.afam_migrations
enable row level security;


-- ============================================================
-- 37. REMOVE DIRECT ACCESS TO SECURITY TABLES
-- ============================================================

revoke all on public.user_social_actions
from anon, authenticated;


revoke all on public.social_reward_ledger
from anon, authenticated;


revoke all on public.device_bindings
from anon, authenticated;


revoke all on public.device_security_events
from anon, authenticated;


revoke all on public.kyc_daily_activity
from anon, authenticated;


revoke all on public.kyc_face_verifications
from anon, authenticated;


revoke all on public.afam_migrations
from anon, authenticated;


-- No direct client SELECT.
-- App reads through SECURITY DEFINER RPCs.
revoke all on public.social_posts
from anon, authenticated;


revoke all on public.kyc_migration_settings
from anon, authenticated;


-- ============================================================
-- 38. CLIENT RPC GRANTS
-- ============================================================

revoke execute
on function public.register_device(text,text,text)
from public, anon, authenticated;


grant execute
on function public.register_device(text,text,text)
to authenticated;


revoke execute
on function public.get_kyc_progress()
from public, anon, authenticated;


grant execute
on function public.get_kyc_progress()
to authenticated;


revoke execute
on function public.claim_daily_checkin()
from public, anon, authenticated;


grant execute
on function public.claim_daily_checkin()
to authenticated;


revoke execute
on function public.record_daily_boost()
from public, anon, authenticated;


grant execute
on function public.record_daily_boost()
to authenticated;


revoke execute
on function public.start_face_verification()
from public, anon, authenticated;


grant execute
on function public.start_face_verification()
to authenticated;


revoke execute
on function public.complete_face_verification(uuid)
from public, anon, authenticated;


grant execute
on function public.complete_face_verification(uuid)
to authenticated;


revoke execute
on function public.get_migration_status()
from public, anon, authenticated;


grant execute
on function public.get_migration_status()
to authenticated;


revoke execute
on function public.migrate_fan_to_afam()
from public, anon, authenticated;


grant execute
on function public.migrate_fan_to_afam()
to authenticated;


revoke execute
on function public.get_daily_social_tasks()
from public, anon, authenticated;


grant execute
on function public.get_daily_social_tasks()
to authenticated;


revoke execute
on function public.start_social_task(uuid)
from public, anon, authenticated;


grant execute
on function public.start_social_task(uuid)
to authenticated;


revoke execute
on function public.claim_daily_social_reward(uuid)
from public, anon, authenticated;


grant execute
on function public.claim_daily_social_reward(uuid)
to authenticated;


revoke execute
on function public.are_initial_social_tasks_complete(uuid)
from public, anon, authenticated;


grant execute
on function public.are_initial_social_tasks_complete(uuid)
to authenticated;


revoke execute
on function public.accept_registration_notice()
from public, anon, authenticated;


grant execute
on function public.accept_registration_notice()
to authenticated;


revoke execute
on function public.get_account_security_status()
from public, anon, authenticated;


grant execute
on function public.get_account_security_status()
to authenticated;


-- ============================================================
-- 39. TRUSTED BACKEND RPC SECURITY
-- ============================================================

revoke execute
on function public.confirm_face_verification(uuid,text)
from public, anon, authenticated;


revoke execute
on function public.verify_social_task_action(uuid,uuid,text,boolean)
from public, anon, authenticated;


revoke execute
on function public.set_migration_status(boolean)
from public, anon, authenticated;


-- Trusted backend / service_role access.
grant execute
on function public.confirm_face_verification(uuid,text)
to service_role;


grant execute
on function public.verify_social_task_action(uuid,uuid,text,boolean)
to service_role;


grant execute
on function public.set_migration_status(boolean)
to service_role;


-- ============================================================
-- 40. PROTECT SENSITIVE PROFILE UPDATES
-- ============================================================
--
-- These values must be changed only by SECURITY DEFINER
-- functions / trusted backend / mining engine.
-- ============================================================

revoke update (
    username,

    fan_balance,

    afam_balance,

    mining_rate,

    active_referrals,

    daily_ads_watched,

    ad_boost,

    mining_active,

    mining_started_at,

    mining_ends_at,

    last_mining_at,

    inactivity_penalty_at,

    consecutive_check_ins,

    kyc1_eligible,

    kyc1_verified,

    kyc2_eligible,

    kyc2_verified,

    kyc3_verified,

    kyc_checkin_streak,

    kyc_boost_streak,

    kyc_last_checkin_date,

    kyc_last_boost_date,

    kyc_face_verification_unlocked,

    kyc_face_verified,

    face_verification_started_at,

    migration_available,

    migration_completed,

    migration_completed_at,

    registration_notice_accepted,

    registration_notice_accepted_at,

    device_warning_count,

    last_device_warning_at,

    suspended_until,

    suspension_reason

)
on public.profiles
from authenticated;


-- ============================================================
-- 41. PROFILE DEFAULTS
-- ============================================================

alter table public.profiles
    alter column kyc_checkin_streak
    set default 0;


alter table public.profiles
    alter column kyc_boost_streak
    set default 0;


alter table public.profiles
    alter column kyc_face_verification_unlocked
    set default false;


alter table public.profiles
    alter column kyc_face_verified
    set default false;


alter table public.profiles
    alter column migration_available
    set default false;


alter table public.profiles
    alter column migration_completed
    set default false;


alter table public.profiles
    alter column registration_notice_accepted
    set default false;


alter table public.profiles
    alter column device_warning_count
    set default 0;


-- ============================================================
-- 42. FINAL MIGRATION DEFAULT
-- ============================================================

update public.kyc_migration_settings
set fan_per_afam = 100
where fan_per_afam is null
   or fan_per_afam = 0;


-- ============================================================
-- END OF schema.plus.sql
-- ============================================================
