-- POWER FAN NETWORK
-- AFAM WALLET ADD-ON
-- Wannan sabon SQL ne. Kada a goge tsoffin SQL files.

BEGIN;

-- 1. Teburin AFAM transfers
CREATE TABLE IF NOT EXISTS public.afam_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    sender_user_id UUID NOT NULL
        REFERENCES public.profiles(id) ON DELETE RESTRICT,

    recipient_user_id UUID NOT NULL
        REFERENCES public.profiles(id) ON DELETE RESTRICT,

    sender_username TEXT NOT NULL,
    recipient_username TEXT NOT NULL,

    amount NUMERIC(24,8) NOT NULL CHECK (amount > 0),

    status TEXT NOT NULL DEFAULT 'completed'
        CHECK (status = 'completed'),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT afam_transfers_not_self
        CHECK (sender_user_id <> recipient_user_id)
);

CREATE INDEX IF NOT EXISTS idx_afam_transfers_sender_created
ON public.afam_transfers(sender_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_afam_transfers_recipient_created
ON public.afam_transfers(recipient_user_id, created_at DESC);

ALTER TABLE public.afam_transfers ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.afam_transfers
FROM anon, authenticated;


-- 2. Duba ko user ya cancanci AFAM transfer.
-- Ana bukatar KYC verified da Check-ins 30 da Boosts 30.

CREATE OR REPLACE FUNCTION public.pfn_afam_transfer_eligible(
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        COALESCE(p.kyc_checkin_streak, 0) >= 30
        AND COALESCE(p.kyc_boost_streak, 0) >= 30
        AND EXISTS (
            SELECT 1
            FROM public.kyc_submissions ks
            WHERE ks.user_id = p.id
              AND ks.status = 'verified'
        )
    FROM public.profiles p
    WHERE p.id = p_user_id;
$$;

REVOKE ALL ON FUNCTION
public.pfn_afam_transfer_eligible(UUID)
FROM PUBLIC, anon, authenticated;


-- 3. Aika AFAM zuwa username na wani user.

CREATE OR REPLACE FUNCTION public.send_afam_by_username(
    p_username TEXT,
    p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_sender_id UUID := auth.uid();
    v_recipient_id UUID;
    v_sender_username TEXT;
    v_recipient_username TEXT;
    v_amount NUMERIC(24,8);
    v_sender_balance NUMERIC(24,8);
    v_transfer_id UUID;
BEGIN

    IF v_sender_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Authentication required.'
        );
    END IF;

    IF p_username IS NULL OR length(trim(p_username)) < 3 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Enter a valid recipient username.'
        );
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Amount must be greater than zero.'
        );
    END IF;

    v_amount := round(p_amount, 8);

    IF v_amount <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Amount is too small.'
        );
    END IF;

    IF NOT COALESCE(
        public.pfn_afam_transfer_eligible(v_sender_id),
        false
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message',
            'Verify KYC and complete 30 Daily Check-ins and 30 Daily Boosts to unlock AFAM transfers.'
        );
    END IF;

    SELECT id, username
    INTO v_recipient_id, v_recipient_username
    FROM public.profiles
    WHERE lower(trim(username)) = lower(trim(p_username))
    LIMIT 1;

    IF v_recipient_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Username not found.'
        );
    END IF;

    IF v_recipient_id = v_sender_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'You cannot send AFAM to your own username.'
        );
    END IF;

    -- Kulle profiles kafin a canza balances.
    PERFORM id
    FROM public.profiles
    WHERE id IN (v_sender_id, v_recipient_id)
    ORDER BY id
    FOR UPDATE;

    SELECT username, COALESCE(afam_balance, 0)
    INTO v_sender_username, v_sender_balance
    FROM public.profiles
    WHERE id = v_sender_id;

    IF v_sender_balance < v_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Insufficient AFAM balance.'
        );
    END IF;

    INSERT INTO public.afam_transfers (
        sender_user_id,
        recipient_user_id,
        sender_username,
        recipient_username,
        amount
    )
    VALUES (
        v_sender_id,
        v_recipient_id,
        v_sender_username,
        v_recipient_username,
        v_amount
    )
    RETURNING id INTO v_transfer_id;

    -- Rage AFAM daga wanda ya aika.
    UPDATE public.profiles
    SET afam_balance = COALESCE(afam_balance, 0) - v_amount
    WHERE id = v_sender_id;

    -- Kara AFAM ga wanda ya karba.
    UPDATE public.profiles
    SET afam_balance = COALESCE(afam_balance, 0) + v_amount
    WHERE id = v_recipient_id;

    -- Rubuta transactions na bangarorin biyu.
    INSERT INTO public.wallet_transactions (
        user_id,
        coin,
        transaction_type,
        amount,
        reference_id,
        description
    )
    VALUES
    (
        v_sender_id,
        'AFAM',
        'transfer_sent',
        v_amount,
        v_transfer_id,
        'AFAM sent to @' || v_recipient_username
    ),
    (
        v_recipient_id,
        'AFAM',
        'transfer_received',
        v_amount,
        v_transfer_id,
        'AFAM received from @' || v_sender_username
    );

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'recipient_username', v_recipient_username,
        'amount', v_amount,
        'message', 'AFAM transfer completed successfully.'
    );

END;
$$;


-- 4. Karanta tarihin AFAM transactions na user.

CREATE OR REPLACE FUNCTION public.get_afam_wallet_transactions(
    p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_limit INTEGER :=
        greatest(1, least(COALESCE(p_limit, 50), 100));
    v_items JSONB;
BEGIN

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Authentication required.'
        );
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', t.id,
                'coin', t.coin,
                'transaction_type', t.transaction_type,
                'amount', t.amount,
                'reference_id', t.reference_id,
                'description', t.description,
                'created_at', t.created_at
            )
            ORDER BY t.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_items
    FROM (
        SELECT
            id,
            coin,
            transaction_type,
            amount,
            reference_id,
            description,
            created_at
        FROM public.wallet_transactions
        WHERE user_id = v_user_id
          AND upper(COALESCE(coin, '')) = 'AFAM'
        ORDER BY created_at DESC
        LIMIT v_limit
    ) t;

    RETURN jsonb_build_object(
        'success', true,
        'transactions', v_items
    );

END;
$$;


-- 5. Sabuwar hanyar Migration.
-- Ba a canza tsohuwar migrate_fan_to_afam() ba.
-- Ana amfani da manual KYC da streaks guda biyu.

CREATE OR REPLACE FUNCTION
public.migrate_fan_to_afam_after_manual_kyc()
RETURNS JSONB
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_username TEXT;
    v_fan NUMERIC(24,8);
    v_afam NUMERIC(24,8);
    v_rate NUMERIC(24,8);
    v_new_afam NUMERIC(24,8);
    v_migration_id UUID;
    v_completed BOOLEAN;
BEGIN

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Authentication required.'
        );
    END IF;

    IF NOT COALESCE(
        public.pfn_afam_transfer_eligible(v_user_id),
        false
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message',
            'Verify KYC and complete 30 Daily Check-ins and 30 Daily Boosts before migration.'
        );
    END IF;

    SELECT fan_per_afam
    INTO v_rate
    FROM public.kyc_migration_settings
    WHERE id = 1
      AND migration_open = true;

    IF v_rate IS NULL OR v_rate <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Migration is not open yet.'
        );
    END IF;

    SELECT
        username,
        COALESCE(fan_balance, 0),
        COALESCE(afam_balance, 0),
        COALESCE(migration_completed, false)
    INTO
        v_username,
        v_fan,
        v_afam,
        v_completed
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    IF v_completed OR EXISTS (
        SELECT 1
        FROM public.afam_migrations
        WHERE user_id = v_user_id
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Migration already completed.'
        );
    END IF;

    IF v_fan <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No FAN balance available for migration.'
        );
    END IF;

    -- Misali: 100 FAN = 1 AFAM idan fan_per_afam = 100.
    v_new_afam := round(v_fan / v_rate, 8);

    INSERT INTO public.afam_migrations (
        user_id,
        username,
        fan_amount,
        afam_amount,
        conversion_rate,
        status
    )
    VALUES (
        v_user_id,
        v_username,
        v_fan,
        v_new_afam,
        v_rate,
        'completed'
    )
    RETURNING id INTO v_migration_id;

    UPDATE public.profiles
    SET
        fan_balance = 0,
        afam_balance = v_afam + v_new_afam,
        migration_completed = true,
        migration_completed_at = now(),
        migration_available = false
    WHERE id = v_user_id;

    INSERT INTO public.wallet_transactions (
        user_id,
        coin,
        transaction_type,
        amount,
        reference_id,
        description
    )
    VALUES (
        v_user_id,
        'AFAM',
        'migration',
        v_new_afam,
        v_migration_id,
        'FAN to AFAM migration at '
            || v_rate || ' FAN = 1 AFAM.'
    );

    RETURN jsonb_build_object(
        'success', true,
        'username', v_username,
        'fan_converted', v_fan,
        'afam_received', v_new_afam,
        'migration_id', v_migration_id,
        'message', 'FAN successfully migrated to AFAM.'
    );

END;
$$;


-- 6. Izinin kiran RPC functions ga authenticated users.

REVOKE ALL ON FUNCTION
public.send_afam_by_username(TEXT, NUMERIC)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
public.send_afam_by_username(TEXT, NUMERIC)
TO authenticated;

REVOKE ALL ON FUNCTION
public.get_afam_wallet_transactions(INTEGER)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
public.get_afam_wallet_transactions(INTEGER)
TO authenticated;

REVOKE ALL ON FUNCTION
public.migrate_fan_to_afam_after_manual_kyc()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
public.migrate_fan_to_afam_after_manual_kyc()
TO authenticated;

COMMIT;
