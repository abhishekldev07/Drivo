-- Drivo v0.6: fixed passenger/driver accounts, richer driver onboarding,
-- payment choices, driver earnings and payment QR support.

DO $$
BEGIN
  CREATE TYPE public.drivo_account_type AS ENUM ('passenger', 'driver');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.ride_payment_method AS ENUM ('cash', 'qr');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE public.ride_payment_status AS ENUM ('pending', 'paid');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_type public.drivo_account_type,
  ADD COLUMN IF NOT EXISTS profile_photo_path text;

-- Preserve the already-approved driver account; all other existing profiles
-- become passenger accounts. New registrations choose explicitly.
UPDATE public.profiles p
SET account_type = CASE
  WHEN EXISTS (
    SELECT 1
    FROM public.driver_applications da
    WHERE da.user_id = p.id
  ) THEN 'driver'::public.drivo_account_type
  ELSE 'passenger'::public.drivo_account_type
END
WHERE account_type IS NULL;

ALTER TABLE public.profiles ALTER COLUMN phone SET NOT NULL;
ALTER TABLE public.profiles ALTER COLUMN account_type SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_unique_idx ON public.profiles(phone);

-- Account type and phone are immutable after registration from the client.
DROP POLICY IF EXISTS "Passengers can create their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Passengers can update their own profile" ON public.profiles;
REVOKE INSERT, UPDATE ON public.profiles FROM authenticated;
GRANT SELECT ON public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.register_passenger_account(
  p_full_name text,
  p_phone text
)
RETURNS TABLE(id uuid, display_name text, phone text, account_type text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_name text := btrim(p_full_name);
  v_phone text := btrim(p_phone);
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id) THEN
    RAISE EXCEPTION 'This Drivo session is already registered';
  END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 60 THEN
    RAISE EXCEPTION 'Enter a valid full name';
  END IF;
  IF v_phone !~ '^[0-9]{10}$' THEN
    RAISE EXCEPTION 'Phone number must be exactly 10 digits';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.phone = v_phone) THEN
    RAISE EXCEPTION 'This phone number is already registered with Drivo';
  END IF;

  INSERT INTO public.profiles(id, display_name, phone, account_type, updated_at)
  VALUES (v_user_id, v_name, v_phone, 'passenger'::public.drivo_account_type, now());

  RETURN QUERY SELECT v_user_id, v_name, v_phone, 'passenger'::text;
END;
$$;
REVOKE ALL ON FUNCTION public.register_passenger_account(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_passenger_account(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_own_profile_name(p_full_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_name text := btrim(p_full_name);
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 60 THEN
    RAISE EXCEPTION 'Enter a valid full name';
  END IF;
  UPDATE public.profiles
  SET display_name = v_name, updated_at = now()
  WHERE id = v_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Drivo account not found'; END IF;
  RETURN v_name;
END;
$$;
REVOKE ALL ON FUNCTION public.update_own_profile_name(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_own_profile_name(text) TO authenticated;

-- Rich driver application data. Existing application rows remain valid;
-- new driver registrations are required to supply all fields through RPC.
ALTER TABLE public.driver_applications
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS license_issue_date date,
  ADD COLUMN IF NOT EXISTS license_expiry_date date,
  ADD COLUMN IF NOT EXISTS license_back_photo_path text,
  ADD COLUMN IF NOT EXISTS vehicle_make text,
  ADD COLUMN IF NOT EXISTS vehicle_year integer,
  ADD COLUMN IF NOT EXISTS registration_back_photo_path text,
  ADD COLUMN IF NOT EXISTS insurance_photo_path text,
  ADD COLUMN IF NOT EXISTS insurance_expiry_date date,
  ADD COLUMN IF NOT EXISTS vehicle_front_photo_path text,
  ADD COLUMN IF NOT EXISTS vehicle_rear_photo_path text,
  ADD COLUMN IF NOT EXISTS vehicle_side_photo_path text;

ALTER TABLE public.driver_applications
  DROP CONSTRAINT IF EXISTS driver_applications_vehicle_year_check;
ALTER TABLE public.driver_applications
  ADD CONSTRAINT driver_applications_vehicle_year_check
  CHECK (vehicle_year IS NULL OR vehicle_year BETWEEN 1990 AND 2100);

-- Registration now goes through a single atomic RPC instead of table INSERT.
REVOKE INSERT ON public.driver_applications FROM authenticated;
DROP POLICY IF EXISTS "Users can submit a pending driver application" ON public.driver_applications;

CREATE OR REPLACE FUNCTION public.register_driver_account(
  p_full_name text,
  p_phone text,
  p_date_of_birth date,
  p_address text,
  p_license_number text,
  p_license_issue_date date,
  p_license_expiry_date date,
  p_category_id uuid,
  p_vehicle_make text,
  p_vehicle_model text,
  p_vehicle_year integer,
  p_vehicle_color text,
  p_plate_number text,
  p_profile_photo_path text,
  p_license_front_photo_path text,
  p_license_back_photo_path text,
  p_registration_front_photo_path text,
  p_registration_back_photo_path text,
  p_insurance_photo_path text,
  p_insurance_expiry_date date,
  p_vehicle_front_photo_path text,
  p_vehicle_rear_photo_path text,
  p_vehicle_side_photo_path text
)
RETURNS TABLE(application_id uuid, application_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_name text := btrim(p_full_name);
  v_phone text := btrim(p_phone);
  v_application_id uuid;
  v_prefix text;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id) THEN
    RAISE EXCEPTION 'This Drivo session is already registered';
  END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 80 THEN RAISE EXCEPTION 'Enter a valid full name'; END IF;
  IF v_phone !~ '^[0-9]{10}$' THEN RAISE EXCEPTION 'Phone number must be exactly 10 digits'; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.phone = v_phone) THEN
    RAISE EXCEPTION 'This phone number is already registered with Drivo';
  END IF;
  IF p_date_of_birth IS NULL OR p_date_of_birth > current_date - interval '18 years' THEN
    RAISE EXCEPTION 'Driver must be at least 18 years old';
  END IF;
  IF char_length(btrim(p_address)) < 5 THEN RAISE EXCEPTION 'Enter a valid address'; END IF;
  IF char_length(btrim(p_license_number)) < 3 THEN RAISE EXCEPTION 'Enter a valid license number'; END IF;
  IF p_license_issue_date IS NULL OR p_license_expiry_date IS NULL OR p_license_expiry_date <= p_license_issue_date THEN
    RAISE EXCEPTION 'Enter valid license dates';
  END IF;
  IF p_insurance_expiry_date IS NULL THEN RAISE EXCEPTION 'Insurance expiry date is required'; END IF;
  IF p_vehicle_year IS NULL OR p_vehicle_year < 1990 OR p_vehicle_year > extract(year from current_date)::integer + 1 THEN
    RAISE EXCEPTION 'Enter a valid vehicle year';
  END IF;
  IF char_length(btrim(p_vehicle_make)) < 2 OR char_length(btrim(p_vehicle_model)) < 2 OR
     char_length(btrim(p_vehicle_color)) < 2 OR char_length(btrim(p_plate_number)) < 3 THEN
    RAISE EXCEPTION 'Complete all vehicle details';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.vehicle_categories c WHERE c.id = p_category_id AND c.is_active = true) THEN
    RAISE EXCEPTION 'Choose a valid Drivo vehicle category';
  END IF;

  v_prefix := v_user_id::text || '/';
  IF p_profile_photo_path NOT LIKE v_prefix || '%' OR
     p_license_front_photo_path NOT LIKE v_prefix || '%' OR
     p_license_back_photo_path NOT LIKE v_prefix || '%' OR
     p_registration_front_photo_path NOT LIKE v_prefix || '%' OR
     p_registration_back_photo_path NOT LIKE v_prefix || '%' OR
     p_insurance_photo_path NOT LIKE v_prefix || '%' OR
     p_vehicle_front_photo_path NOT LIKE v_prefix || '%' OR
     p_vehicle_rear_photo_path NOT LIKE v_prefix || '%' OR
     p_vehicle_side_photo_path NOT LIKE v_prefix || '%' THEN
    RAISE EXCEPTION 'Invalid driver document path';
  END IF;

  INSERT INTO public.profiles(id, display_name, phone, account_type, profile_photo_path, updated_at)
  VALUES (v_user_id, v_name, v_phone, 'driver'::public.drivo_account_type, p_profile_photo_path, now());

  INSERT INTO public.driver_applications(
    user_id, full_name, phone, date_of_birth, address,
    category_id, vehicle_make, vehicle_model, vehicle_year, vehicle_color, plate_number,
    license_number, license_issue_date, license_expiry_date,
    profile_photo_path, license_photo_path, license_back_photo_path,
    registration_photo_path, registration_back_photo_path,
    insurance_photo_path, insurance_expiry_date,
    vehicle_front_photo_path, vehicle_rear_photo_path, vehicle_side_photo_path,
    status
  ) VALUES (
    v_user_id, v_name, v_phone, p_date_of_birth, btrim(p_address),
    p_category_id, btrim(p_vehicle_make), btrim(p_vehicle_model), p_vehicle_year, btrim(p_vehicle_color), upper(btrim(p_plate_number)),
    btrim(p_license_number), p_license_issue_date, p_license_expiry_date,
    p_profile_photo_path, p_license_front_photo_path, p_license_back_photo_path,
    p_registration_front_photo_path, p_registration_back_photo_path,
    p_insurance_photo_path, p_insurance_expiry_date,
    p_vehicle_front_photo_path, p_vehicle_rear_photo_path, p_vehicle_side_photo_path,
    'pending'::public.driver_application_status
  ) RETURNING id INTO v_application_id;

  RETURN QUERY SELECT v_application_id, 'pending'::text;
END;
$$;
REVOKE ALL ON FUNCTION public.register_driver_account(text,text,date,text,text,date,date,uuid,text,text,integer,text,text,text,text,text,text,text,text,date,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_driver_account(text,text,date,text,text,date,date,uuid,text,text,integer,text,text,text,text,text,text,text,text,date,text,text,text) TO authenticated;

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS vehicle_make text,
  ADD COLUMN IF NOT EXISTS vehicle_year integer,
  ADD COLUMN IF NOT EXISTS payment_qr_path text;

-- Keep approved driver operational details synced from the application.
CREATE OR REPLACE FUNCTION public.process_driver_application_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IN ('approved'::public.driver_application_status, 'rejected'::public.driver_application_status) THEN
    NEW.reviewed_at := coalesce(NEW.reviewed_at, now());
  END IF;

  IF NEW.status = 'approved'::public.driver_application_status AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.drivers(
      id, name, phone, model, vehicle_make, vehicle_year, number, vehicle_color,
      is_available, is_online, is_suspended, location, category_id, is_simulated, application_id
    ) VALUES (
      NEW.user_id, btrim(NEW.full_name), NEW.phone, btrim(NEW.vehicle_model), btrim(NEW.vehicle_make), NEW.vehicle_year,
      upper(btrim(NEW.plate_number)), btrim(NEW.vehicle_color), false, false, false, null,
      NEW.category_id, false, NEW.id
    )
    ON CONFLICT (id) DO UPDATE SET
      name=excluded.name, phone=excluded.phone, model=excluded.model,
      vehicle_make=excluded.vehicle_make, vehicle_year=excluded.vehicle_year,
      number=excluded.number, vehicle_color=excluded.vehicle_color,
      category_id=excluded.category_id, application_id=excluded.application_id,
      is_simulated=false, is_suspended=false, is_online=false, is_available=false;
  ELSIF NEW.status <> 'approved'::public.driver_application_status AND OLD.status IS DISTINCT FROM NEW.status THEN
    UPDATE public.drivers
    SET is_suspended=true, is_online=false, is_available=false
    WHERE id=NEW.user_id AND is_simulated=false;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.process_driver_application_review() FROM PUBLIC, anon, authenticated;

-- Payment QR is intentionally separate from private compliance documents.
INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES ('driver-payment-assets', 'driver-payment-assets', false, 5242880, ARRAY['image/jpeg','image/png','image/webp']::text[])
ON CONFLICT (id) DO UPDATE SET public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

DROP POLICY IF EXISTS "Drivers can upload their payment QR" ON storage.objects;
CREATE POLICY "Drivers can upload their payment QR"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='driver-payment-assets'
  AND (storage.foldername(name))[1]=(SELECT auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.drivers d
    JOIN public.profiles p ON p.id=d.id
    WHERE d.id=(SELECT auth.uid()) AND p.account_type='driver'::public.drivo_account_type
      AND d.is_simulated=false AND d.is_suspended=false
  )
);

DROP POLICY IF EXISTS "Driver and ride passenger can read payment QR" ON storage.objects;
CREATE POLICY "Driver and ride passenger can read payment QR"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id='driver-payment-assets'
  AND (
    (storage.foldername(name))[1]=(SELECT auth.uid())::text
    OR EXISTS (
      SELECT 1 FROM public.rides r
      WHERE r.passenger_id=(SELECT auth.uid())
        AND r.driver_id::text=(storage.foldername(name))[1]
    )
  )
);

CREATE OR REPLACE FUNCTION public.set_driver_payment_qr(p_path text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_path IS NULL OR p_path NOT LIKE v_user_id::text || '/%' THEN RAISE EXCEPTION 'Invalid QR path'; END IF;
  UPDATE public.drivers d SET payment_qr_path=p_path
  WHERE d.id=v_user_id AND d.is_simulated=false AND d.is_suspended=false
    AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_user_id AND p.account_type='driver'::public.drivo_account_type);
  IF NOT FOUND THEN RAISE EXCEPTION 'Approved driver account required'; END IF;
  RETURN p_path;
END;
$$;
REVOKE ALL ON FUNCTION public.set_driver_payment_qr(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_payment_qr(text) TO authenticated;

ALTER TABLE public.ride_requests
  ADD COLUMN IF NOT EXISTS payment_method public.ride_payment_method NOT NULL DEFAULT 'cash';

ALTER TABLE public.rides
  ADD COLUMN IF NOT EXISTS payment_method public.ride_payment_method NOT NULL DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_status public.ride_payment_status NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS platform_fee integer,
  ADD COLUMN IF NOT EXISTS driver_earning integer,
  ADD COLUMN IF NOT EXISTS driver_payment_qr_path text,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

ALTER TABLE public.rides DROP CONSTRAINT IF EXISTS rides_platform_fee_check;
ALTER TABLE public.rides ADD CONSTRAINT rides_platform_fee_check CHECK (platform_fee IS NULL OR platform_fee >= 0);
ALTER TABLE public.rides DROP CONSTRAINT IF EXISTS rides_driver_earning_check;
ALTER TABLE public.rides ADD CONSTRAINT rides_driver_earning_check CHECK (driver_earning IS NULL OR driver_earning >= 0);

CREATE OR REPLACE FUNCTION public.request_ride_v4(
  p_origin extensions.geography,
  p_destination extensions.geography,
  p_category_slug text,
  p_distance_meters integer,
  p_duration_seconds integer,
  p_payment_method text,
  p_pickup_label text DEFAULT NULL,
  p_destination_label text DEFAULT NULL
)
RETURNS TABLE(request_id uuid, request_status text, offered_driver_id uuid, fare_amount integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_passenger_id uuid := auth.uid();
  v_category public.vehicle_categories%rowtype;
  v_driver_id uuid;
  v_request_id uuid;
  v_fare integer;
  v_payment public.ride_payment_method;
BEGIN
  IF v_passenger_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_passenger_id AND p.account_type='passenger'::public.drivo_account_type) THEN
    RAISE EXCEPTION 'Passenger account required';
  END IF;
  IF p_distance_meters IS NULL OR p_distance_meters<0 OR p_duration_seconds IS NULL OR p_duration_seconds<0 THEN RAISE EXCEPTION 'Invalid route metrics'; END IF;
  BEGIN v_payment := p_payment_method::public.ride_payment_method;
  EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Invalid payment method'; END;
  IF v_payment='qr'::public.ride_payment_method AND NOT EXISTS (
    SELECT 1 FROM public.drivers d
    WHERE d.is_simulated=false AND d.is_suspended=false AND d.is_online=true AND d.is_available=true
      AND d.category_id=(SELECT id FROM public.vehicle_categories WHERE slug=p_category_slug LIMIT 1)
      AND d.payment_qr_path IS NOT NULL
      AND d.location IS NOT NULL AND extensions.st_dwithin(p_origin,d.location,5000)
  ) THEN
    RAISE EXCEPTION 'No nearby driver with QR payment is available for this category';
  END IF;
  IF EXISTS(SELECT 1 FROM public.rides r WHERE r.passenger_id=v_passenger_id AND r.status::text NOT IN('completed','cancelled')) THEN RAISE EXCEPTION 'You already have an active ride'; END IF;
  IF EXISTS(SELECT 1 FROM public.ride_requests rr WHERE rr.passenger_id=v_passenger_id AND rr.status='offered'::public.ride_request_status) THEN RAISE EXCEPTION 'You already have a pending ride request'; END IF;
  SELECT c.* INTO v_category FROM public.vehicle_categories c WHERE c.slug=p_category_slug AND c.is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invalid vehicle category'; END IF;
  v_fare:=greatest(v_category.minimum_fare,v_category.base_fare+ceil((p_distance_meters::numeric/1000)*v_category.per_km)::integer+ceil((p_duration_seconds::numeric/60)*v_category.per_minute)::integer);
  SELECT d.id INTO v_driver_id FROM public.drivers d
  JOIN public.profiles p ON p.id=d.id
  JOIN public.driver_applications da ON da.user_id=d.id AND da.status='approved'::public.driver_application_status
  WHERE p.account_type='driver'::public.drivo_account_type
    AND d.is_simulated=false AND d.is_suspended=false AND d.is_online=true AND d.is_available=true
    AND d.category_id=v_category.id AND d.location IS NOT NULL AND d.id<>v_passenger_id
    AND (v_payment='cash'::public.ride_payment_method OR d.payment_qr_path IS NOT NULL)
    AND (d.last_location_at IS NULL OR d.last_location_at>now()-interval '10 minutes')
    AND extensions.st_dwithin(p_origin,d.location,5000)
  ORDER BY extensions.st_distance(d.location,p_origin) FOR UPDATE SKIP LOCKED LIMIT 1;
  IF v_driver_id IS NOT NULL THEN UPDATE public.drivers SET is_available=false WHERE id=v_driver_id; END IF;
  INSERT INTO public.ride_requests(passenger_id,offered_driver_id,category_id,origin,destination,pickup_label,destination_label,distance_meters,duration_seconds,fare,status,payment_method)
  VALUES(v_passenger_id,v_driver_id,v_category.id,p_origin,p_destination,nullif(left(btrim(p_pickup_label),160),''),nullif(left(btrim(p_destination_label),200),''),p_distance_meters,p_duration_seconds,v_fare,CASE WHEN v_driver_id IS NULL THEN 'no_driver'::public.ride_request_status ELSE 'offered'::public.ride_request_status END,v_payment)
  RETURNING id INTO v_request_id;
  RETURN QUERY SELECT v_request_id,CASE WHEN v_driver_id IS NULL THEN 'no_driver' ELSE 'offered' END,v_driver_id,v_fare;
END;
$$;
REVOKE ALL ON FUNCTION public.request_ride_v4(extensions.geography,extensions.geography,text,integer,integer,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_ride_v4(extensions.geography,extensions.geography,text,integer,integer,text,text,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.request_ride_v3(extensions.geography,extensions.geography,text,integer,integer,text,text) FROM authenticated;

CREATE OR REPLACE FUNCTION public.respond_to_ride_request_v2(p_request_id uuid, p_accept boolean)
RETURNS TABLE(action text, ride_id uuid, next_driver_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_driver_id uuid:=auth.uid();
  v_request public.ride_requests%rowtype;
  v_next_driver_id uuid;
  v_ride_id uuid;
  v_fee integer;
  v_earning integer;
  v_qr_path text;
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_driver_id AND p.account_type='driver'::public.drivo_account_type) THEN RAISE EXCEPTION 'Driver account required'; END IF;
  SELECT * INTO v_request FROM public.ride_requests WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.status<>'offered'::public.ride_request_status THEN RAISE EXCEPTION 'Ride request is no longer available'; END IF;
  IF v_request.offered_driver_id<>v_driver_id THEN RAISE EXCEPTION 'This ride request is not assigned to you'; END IF;
  SELECT d.payment_qr_path INTO v_qr_path FROM public.drivers d
  JOIN public.driver_applications da ON da.user_id=d.id AND da.status='approved'::public.driver_application_status
  WHERE d.id=v_driver_id AND d.is_simulated=false AND d.is_suspended=false AND d.is_online=true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Driver is not approved and online'; END IF;
  IF v_request.payment_method='qr'::public.ride_payment_method AND v_qr_path IS NULL THEN RAISE EXCEPTION 'Add your payment QR before accepting QR rides'; END IF;
  IF p_accept THEN
    v_fee := round(v_request.fare * 0.10)::integer;
    v_earning := v_request.fare - v_fee;
    INSERT INTO public.rides(driver_id,passenger_id,origin,destination,fare,status,category_id,distance_meters,duration_seconds,pickup_label,destination_label,payment_method,payment_status,platform_fee,driver_earning,driver_payment_qr_path)
    VALUES(v_driver_id,v_request.passenger_id,v_request.origin,v_request.destination,v_request.fare,'driver_arriving'::public.ride_status,v_request.category_id,v_request.distance_meters,v_request.duration_seconds,v_request.pickup_label,v_request.destination_label,v_request.payment_method,'pending'::public.ride_payment_status,v_fee,v_earning,v_qr_path)
    RETURNING id INTO v_ride_id;
    UPDATE public.ride_requests SET status='accepted'::public.ride_request_status,ride_id=v_ride_id,updated_at=now() WHERE id=p_request_id;
    RETURN QUERY SELECT 'accepted'::text,v_ride_id,null::uuid; RETURN;
  END IF;
  UPDATE public.drivers SET is_available=is_online AND NOT is_suspended WHERE id=v_driver_id;
  UPDATE public.ride_requests SET declined_driver_ids=array_append(declined_driver_ids,v_driver_id),updated_at=now() WHERE id=p_request_id;
  SELECT d.id INTO v_next_driver_id FROM public.drivers d
  JOIN public.profiles p ON p.id=d.id
  JOIN public.driver_applications da ON da.user_id=d.id AND da.status='approved'::public.driver_application_status
  WHERE p.account_type='driver'::public.drivo_account_type
    AND d.is_simulated=false AND d.is_suspended=false AND d.is_online=true AND d.is_available=true
    AND d.category_id=v_request.category_id AND d.location IS NOT NULL AND d.id<>v_request.passenger_id
    AND (v_request.payment_method='cash'::public.ride_payment_method OR d.payment_qr_path IS NOT NULL)
    AND NOT(d.id=ANY(array_append(v_request.declined_driver_ids,v_driver_id)))
    AND (d.last_location_at IS NULL OR d.last_location_at>now()-interval '10 minutes')
    AND extensions.st_dwithin(v_request.origin,d.location,5000)
  ORDER BY extensions.st_distance(d.location,v_request.origin) FOR UPDATE SKIP LOCKED LIMIT 1;
  IF v_next_driver_id IS NULL THEN
    UPDATE public.ride_requests SET offered_driver_id=null,status='no_driver'::public.ride_request_status,updated_at=now() WHERE id=p_request_id;
    RETURN QUERY SELECT 'no_driver'::text,null::uuid,null::uuid;
  ELSE
    UPDATE public.drivers SET is_available=false WHERE id=v_next_driver_id;
    UPDATE public.ride_requests SET offered_driver_id=v_next_driver_id,status='offered'::public.ride_request_status,updated_at=now() WHERE id=p_request_id;
    RETURN QUERY SELECT 'reassigned'::text,null::uuid,v_next_driver_id;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.respond_to_ride_request_v2(uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_to_ride_request_v2(uuid,boolean) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.respond_to_ride_request(uuid,boolean) FROM authenticated;

CREATE OR REPLACE FUNCTION public.set_driver_presence(p_online boolean,p_latitude double precision DEFAULT NULL,p_longitude double precision DEFAULT NULL)
RETURNS TABLE(is_online boolean,is_available boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_driver_id uuid:=auth.uid(); v_available boolean;
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.drivers d
    JOIN public.profiles p ON p.id=d.id
    JOIN public.driver_applications da ON da.user_id=d.id
    WHERE d.id=v_driver_id AND p.account_type='driver'::public.drivo_account_type
      AND da.status='approved'::public.driver_application_status
      AND d.is_simulated=false AND d.is_suspended=false
  ) THEN RAISE EXCEPTION 'Approved driver account required'; END IF;
  IF p_online AND (p_latitude IS NULL OR p_longitude IS NULL OR p_latitude < -90 OR p_latitude > 90 OR p_longitude < -180 OR p_longitude > 180) THEN RAISE EXCEPTION 'Valid current location is required to go online'; END IF;
  IF NOT p_online AND EXISTS(SELECT 1 FROM public.rides r WHERE r.driver_id=v_driver_id AND r.status::text NOT IN('completed','cancelled')) THEN RAISE EXCEPTION 'Complete the active ride before going offline'; END IF;
  IF NOT p_online AND EXISTS(SELECT 1 FROM public.ride_requests rr WHERE rr.offered_driver_id=v_driver_id AND rr.status='offered'::public.ride_request_status) THEN RAISE EXCEPTION 'Respond to the current ride request before going offline'; END IF;
  v_available:=p_online AND NOT EXISTS(SELECT 1 FROM public.rides r WHERE r.driver_id=v_driver_id AND r.status::text NOT IN('completed','cancelled')) AND NOT EXISTS(SELECT 1 FROM public.ride_requests rr WHERE rr.offered_driver_id=v_driver_id AND rr.status='offered'::public.ride_request_status);
  UPDATE public.drivers SET is_online=p_online,is_available=v_available,location=CASE WHEN p_online THEN extensions.st_setsrid(extensions.st_makepoint(p_longitude,p_latitude),4326)::extensions.geography ELSE location END,last_location_at=CASE WHEN p_online THEN now() ELSE last_location_at END WHERE id=v_driver_id;
  RETURN QUERY SELECT p_online,v_available;
END;
$$;
REVOKE ALL ON FUNCTION public.set_driver_presence(boolean,double precision,double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_driver_presence(boolean,double precision,double precision) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_driver_location(p_latitude double precision,p_longitude double precision)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_driver_id uuid:=auth.uid();
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_latitude < -90 OR p_latitude > 90 OR p_longitude < -180 OR p_longitude > 180 THEN RAISE EXCEPTION 'Invalid location'; END IF;
  UPDATE public.drivers d SET location=extensions.st_setsrid(extensions.st_makepoint(p_longitude,p_latitude),4326)::extensions.geography,last_location_at=now()
  WHERE d.id=v_driver_id AND d.is_simulated=false AND d.is_suspended=false AND d.is_online=true
    AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=v_driver_id AND p.account_type='driver'::public.drivo_account_type)
    AND EXISTS(SELECT 1 FROM public.driver_applications da WHERE da.user_id=v_driver_id AND da.status='approved'::public.driver_application_status);
  RETURN found;
END;
$$;
REVOKE ALL ON FUNCTION public.update_driver_location(double precision,double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_driver_location(double precision,double precision) TO authenticated;

CREATE OR REPLACE FUNCTION public.driver_update_ride_status_v2(p_ride_id uuid,p_status text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_driver_id uuid:=auth.uid(); v_current text; v_method public.ride_payment_method;
BEGIN
  IF v_driver_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=v_driver_id AND p.account_type='driver'::public.drivo_account_type) THEN RAISE EXCEPTION 'Driver account required'; END IF;
  SELECT r.status::text,r.payment_method INTO v_current,v_method FROM public.rides r WHERE r.id=p_ride_id AND r.driver_id=v_driver_id FOR UPDATE;
  IF v_current IS NULL THEN RAISE EXCEPTION 'Ride not found'; END IF;
  IF NOT((v_current='driver_arriving' AND p_status='driver_arrived') OR (v_current='driver_arrived' AND p_status='in_progress') OR (v_current='in_progress' AND p_status='completed')) THEN RAISE EXCEPTION 'Invalid ride status transition'; END IF;
  UPDATE public.rides SET status=p_status::public.ride_status,
    completed_at=CASE WHEN p_status='completed' THEN now() ELSE completed_at END,
    payment_status=CASE WHEN p_status='completed' AND v_method='cash'::public.ride_payment_method THEN 'paid'::public.ride_payment_status ELSE payment_status END
  WHERE id=p_ride_id;
  RETURN p_status;
END;
$$;
REVOKE ALL ON FUNCTION public.driver_update_ride_status_v2(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.driver_update_ride_status_v2(uuid,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.driver_update_ride_status(uuid,text) FROM authenticated;

CREATE OR REPLACE FUNCTION public.passenger_mark_qr_paid(p_ride_id uuid)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_user_id uuid:=auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=v_user_id AND p.account_type='passenger'::public.drivo_account_type) THEN RAISE EXCEPTION 'Passenger account required'; END IF;
  UPDATE public.rides SET payment_status='paid'::public.ride_payment_status
  WHERE id=p_ride_id AND passenger_id=v_user_id AND payment_method='qr'::public.ride_payment_method AND status='completed'::public.ride_status;
  IF NOT FOUND THEN RAISE EXCEPTION 'Completed QR ride not found'; END IF;
  RETURN 'paid';
END;
$$;
REVOKE ALL ON FUNCTION public.passenger_mark_qr_paid(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.passenger_mark_qr_paid(uuid) TO authenticated;

-- Keep ride completion from re-enabling non-driver accounts.
CREATE OR REPLACE FUNCTION public.update_driver_status()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
BEGIN
  UPDATE public.drivers d
  SET is_available=(NEW.status::text IN ('completed','cancelled') AND d.is_online=true AND d.is_suspended=false AND d.is_simulated=false)
  WHERE d.id=NEW.driver_id
    AND EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=d.id AND p.account_type='driver'::public.drivo_account_type)
    AND EXISTS(SELECT 1 FROM public.driver_applications da WHERE da.user_id=d.id AND da.status='approved'::public.driver_application_status);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.update_driver_status() FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS rides_driver_completed_at_idx ON public.rides(driver_id, completed_at DESC) WHERE status='completed'::public.ride_status;
CREATE INDEX IF NOT EXISTS rides_passenger_created_at_v06_idx ON public.rides(passenger_id, created_at DESC);

-- Realtime already includes rides/drivers; profile role is read at app start.
