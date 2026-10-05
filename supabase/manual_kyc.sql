-- ============================================================
-- POWER FAN NETWORK
-- MANUAL KYC REVIEW SYSTEM
-- ============================================================
--
-- User captures 6 face photos:
-- 1. front
-- 2. left
-- 3. right
-- 4. up
-- 5. down
-- 6. eyes
--
-- Photos are stored in a PRIVATE Supabase Storage bucket.
--
-- Submission status:
-- none
-- in_review
-- verified
-- rejected
--
-- Reviewer changes the status from Supabase Dashboard.
-- ============================================================


-- ============================================================
-- KYC SUBMISSIONS TABLE
-- ============================================================

create table if not exists public.kyc_submissions (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null
        references public.profiles(id)
        on delete cascade,

    status text not null default 'in_review'
        check (
            status in (
                'in_review',
                'verified',
                'rejected'
            )
        ),

    front_path text not null,
    left_path text not null,
    right_path text not null,
    up_path text not null,
    down_path text not null,
    eyes_path text not null,

    submitted_at timestamptz not null
        default now(),

    reviewed_at timestamptz,

    reviewed_by uuid,

    rejection_reason text,

    updated_at timestamptz not null
        default now()
);


-- ============================================================
-- INDEXES
-- ============================================================

create index if not exists
idx_kyc_submissions_user
on public.kyc_submissions (
    user_id,
    submitted_at desc
);


create index if not exists
idx_kyc_submissions_status
on public.kyc_submissions (
    status,
    submitted_at desc
);


-- ============================================================
-- RLS
-- ============================================================

alter table public.kyc_submissions
enable row level security;


revoke all
on public.kyc_submissions
from anon, authenticated;


-- ============================================================
-- PRIVATE STORAGE BUCKET
-- ============================================================

insert into storage.buckets (
    id,
    name,
    public
)
values (
    'kyc-photos',
    'kyc-photos',
    false
)
on conflict (id)
do update
set public = false;


-- ============================================================
-- STORAGE INSERT POLICY
-- USER CAN UPLOAD ONLY INTO THEIR OWN UUID FOLDER
-- ============================================================

drop policy if exists
"kyc photos upload own folder"
on storage.objects;


create policy
"kyc photos upload own folder"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'kyc-photos'
    and
    (storage.foldername(name))[1]
        = auth.uid()::text
);


-- ============================================================
-- STORAGE UPDATE POLICY
-- ============================================================

drop policy if exists
"kyc photos update own folder"
on storage.objects;


create policy
"kyc photos update own folder"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'kyc-photos'
    and
    (storage.foldername(name))[1]
        = auth.uid()::text
)
with check (
    bucket_id = 'kyc-photos'
    and
    (storage.foldername(name))[1]
        = auth.uid()::text
);


-- ============================================================
-- GET CURRENT KYC SUBMISSION STATUS
-- ============================================================

drop function if exists
public.get_kyc_submission_status();


create or replace function
public.get_kyc_submission_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();

    v_status text := 'none';

    v_submitted_at timestamptz;
begin

    if v_user_id is null then

        return jsonb_build_object(
            'success',
            false,

            'message',
            'Authentication required'
        );

    end if;


    select
        status,
        submitted_at

    into
        v_status,
        v_submitted_at

    from public.kyc_submissions

    where user_id = v_user_id

    order by submitted_at desc

    limit 1;


    return jsonb_build_object(

        'success',
        true,

        'status',
        coalesce(
            v_status,
            'none'
        ),

        'submitted_at',
        v_submitted_at

    );

end;
$$;


-- ============================================================
-- SUBMIT MANUAL KYC
-- ============================================================

drop function if exists
public.submit_manual_kyc(
    text,
    text,
    text,
    text,
    text,
    text
);


create or replace function
public.submit_manual_kyc(
    p_front_path text,
    p_left_path text,
    p_right_path text,
    p_up_path text,
    p_down_path text,
    p_eyes_path text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare

    v_user_id uuid := auth.uid();

    v_submission_id uuid;

begin

    -- --------------------------------------------------------
    -- AUTH CHECK
    -- --------------------------------------------------------

    if v_user_id is null then

        return jsonb_build_object(
            'success',
            false,

            'message',
            'Authentication required'
        );

    end if;


    -- --------------------------------------------------------
    -- REQUIREMENTS CHECK
    -- --------------------------------------------------------

    if not exists (

        select 1

        from public.profiles

        where id = v_user_id

        and coalesce(
            consecutive_check_ins,
            0
        ) >= 30

        and coalesce(
            consecutive_boost_days,
            0
        ) >= 30

    ) then

        return jsonb_build_object(

            'success',
            false,

            'message',
            'Complete the KYC requirements first.'

        );

    end if;


    -- --------------------------------------------------------
    -- PREVENT DUPLICATE ACTIVE SUBMISSION
    -- --------------------------------------------------------

    if exists (

        select 1

        from public.kyc_submissions

        where user_id = v_user_id

        and status = 'in_review'

    ) then

        return jsonb_build_object(

            'success',
            false,

            'message',
            'Your KYC submission is already under review.'

        );

    end if;


    -- --------------------------------------------------------
    -- PHOTO CHECK
    -- --------------------------------------------------------

    if p_front_path is null
       or p_left_path is null
       or p_right_path is null
       or p_up_path is null
       or p_down_path is null
       or p_eyes_path is null then

        return jsonb_build_object(

            'success',
            false,

            'message',
            'All six KYC photos are required.'

        );

    end if;


    -- --------------------------------------------------------
    -- PATH SECURITY CHECK
    -- Every path must start with user's UUID.
    -- --------------------------------------------------------

    if p_front_path not like
           v_user_id::text || '/%'

       or p_left_path not like
           v_user_id::text || '/%'

       or p_right_path not like
           v_user_id::text || '/%'

       or p_up_path not like
           v_user_id::text || '/%'

       or p_down_path not like
           v_user_id::text || '/%'

       or p_eyes_path not like
           v_user_id::text || '/%'

    then

        return jsonb_build_object(

            'success',
            false,

            'message',
            'Invalid KYC photo paths.'

        );

    end if;


    -- --------------------------------------------------------
    -- CREATE SUBMISSION
    -- --------------------------------------------------------

    insert into public.kyc_submissions (

        user_id,

        status,

        front_path,
        left_path,
        right_path,
        up_path,
        down_path,
        eyes_path

    )

    values (

        v_user_id,

        'in_review',

        p_front_path,
        p_left_path,
        p_right_path,
        p_up_path,
        p_down_path,
        p_eyes_path

    )

    returning id
    into v_submission_id;


    return jsonb_build_object(

        'success',
        true,

        'submission_id',
        v_submission_id,

        'status',
        'in_review',

        'message',
        'KYC submitted successfully.'

    );

end;
$$;


-- ============================================================
-- RPC PERMISSIONS
-- ============================================================

grant execute
on function
public.get_kyc_submission_status()
to authenticated;


grant execute
on function
public.submit_manual_kyc(
    text,
    text,
    text,
    text,
    text,
    text
)
to authenticated;


revoke execute
on function
public.get_kyc_submission_status()
from anon;


revoke execute
on function
public.submit_manual_kyc(
    text,
    text,
    text,
    text,
    text,
    text
)
from anon;


-- ============================================================
-- SYNC REVIEW STATUS TO PROFILE
-- ============================================================

create or replace function
public.sync_manual_kyc_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    -- --------------------------------------------------------
    -- VERIFIED
    -- --------------------------------------------------------

    if new.status = 'verified' then

        update public.profiles

        set

            kyc1_eligible = true,

            kyc_face_verification_unlocked =
                true,

            kyc_face_verified =
                true,

            kyc1_verified =
                true,

            updated_at =
                now()

        where id = new.user_id;

    end if;


    -- --------------------------------------------------------
    -- REJECTED
    -- --------------------------------------------------------

    if new.status = 'rejected' then

        update public.profiles

        set

            kyc_face_verified =
                false,

            kyc1_verified =
                false,

            updated_at =
                now()

        where id = new.user_id;

    end if;


    -- --------------------------------------------------------
    -- UPDATE REVIEW TIMESTAMP
    -- --------------------------------------------------------

    new.updated_at :=
        now();


    if new.status in (
        'verified',
        'rejected'
    ) then

        new.reviewed_at :=
            coalesce(
                new.reviewed_at,
                now()
            );

    end if;


    return new;

end;
$$;


-- ============================================================
-- TRIGGER
-- ============================================================

drop trigger if exists
trg_sync_manual_kyc_status
on public.kyc_submissions;


create trigger
trg_sync_manual_kyc_status

before insert or update of status

on public.kyc_submissions

for each row

execute function
public.sync_manual_kyc_status();


-- ============================================================
-- END
-- ============================================================
