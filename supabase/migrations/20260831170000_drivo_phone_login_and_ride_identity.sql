-- Drivo v0.7 portfolio phone login + ride participant identity snapshots.
-- NOTE: phone-only login is intentionally portfolio-only and is not production authentication.

alter table public.ride_requests
  add column if not exists passenger_name text,
  add column if not exists passenger_phone text;

alter table public.rides
  add column if not exists passenger_name text,
  add column if not exists passenger_phone text,
  add column if not exists driver_name text,
  add column if not exists driver_phone text,
  add column if not exists driver_vehicle text;

-- Backfill identity snapshots for existing data where possible.
update public.ride_requests rr
set passenger_name = coalesce(rr.passenger_name, p.display_name),
    passenger_phone = coalesce(rr.passenger_phone, p.phone)
from public.profiles p
where p.id = rr.passenger_id
  and (rr.passenger_name is null or rr.passenger_phone is null);

update public.rides r
set passenger_name = coalesce(r.passenger_name, p.display_name),
    passenger_phone = coalesce(r.passenger_phone, p.phone)
from public.profiles p
where p.id = r.passenger_id
  and (r.passenger_name is null or r.passenger_phone is null);

update public.rides r
set driver_name = coalesce(r.driver_name, d.name),
    driver_phone = coalesce(r.driver_phone, d.phone),
    driver_vehicle = coalesce(
      r.driver_vehicle,
      nullif(btrim(concat_ws(' ', nullif(d.vehicle_make, ''), nullif(d.model, ''))), ''),
      d.model
    )
from public.drivers d
where d.id = r.driver_id
  and (r.driver_name is null or r.driver_phone is null or r.driver_vehicle is null);

create or replace function public.portfolio_phone_login(p_phone text)
returns table(
  account_exists boolean,
  id uuid,
  display_name text,
  phone text,
  account_type text,
  profile_photo_path text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_id uuid := auth.uid();
  v_target_id uuid;
  v_phone text := btrim(p_phone);
  v_name text;
  v_account_type public.drivo_account_type;
  v_profile_photo_path text;
  v_driver public.drivers%rowtype;
  v_application_id uuid;
begin
  if v_current_id is null then
    raise exception 'Authentication required';
  end if;
  if v_phone !~ '^[0-9]{10}$' then
    raise exception 'Phone number must be exactly 10 digits';
  end if;

  select p.id, p.display_name, p.account_type, p.profile_photo_path
    into v_target_id, v_name, v_account_type, v_profile_photo_path
  from public.profiles p
  where p.phone = v_phone
  limit 1;

  if v_target_id is null then
    return query select false, null::uuid, null::text, v_phone, null::text, null::text;
    return;
  end if;

  if v_target_id = v_current_id then
    return query
      select true, v_current_id, v_name, v_phone, v_account_type::text, v_profile_photo_path;
    return;
  end if;

  -- The app will create a fresh anonymous session before switching accounts.
  if exists (select 1 from public.profiles p where p.id = v_current_id) then
    raise exception 'CURRENT_SESSION_REGISTERED_TO_ANOTHER_ACCOUNT';
  end if;

  -- Do not re-home an account in the middle of a live marketplace operation.
  if exists (
      select 1 from public.rides r
      where (r.passenger_id = v_target_id or r.driver_id = v_target_id)
        and r.status::text not in ('completed', 'cancelled')
    ) or exists (
      select 1 from public.ride_requests rr
      where (rr.passenger_id = v_target_id or rr.offered_driver_id = v_target_id)
        and rr.status = 'offered'::public.ride_request_status
    ) then
    raise exception 'This Drivo account has an active ride or request. Finish it on the current device first.';
  end if;

  -- Move passenger-owned marketplace history to the new anonymous auth session.
  update public.rides set passenger_id = v_current_id where passenger_id = v_target_id;
  update public.ride_requests set passenger_id = v_current_id where passenger_id = v_target_id;

  -- Move Driver identity/history if this is a Driver account.
  select d.* into v_driver
  from public.drivers d
  where d.id = v_target_id
  for update;

  if found then
    v_application_id := v_driver.application_id;

    -- Free the unique application link before inserting the replacement Driver row.
    update public.drivers set application_id = null where id = v_target_id;

    insert into public.drivers(
      id, model, number, is_available, location, name, rating, category_id,
      is_simulated, phone, vehicle_color, application_id, is_online,
      is_suspended, last_location_at, vehicle_make, vehicle_year, payment_qr_path
    ) values (
      v_current_id, v_driver.model, v_driver.number, false, v_driver.location,
      v_driver.name, v_driver.rating, v_driver.category_id, false, v_driver.phone,
      v_driver.vehicle_color, v_application_id, false, v_driver.is_suspended,
      v_driver.last_location_at, v_driver.vehicle_make, v_driver.vehicle_year,
      v_driver.payment_qr_path
    );

    update public.rides set driver_id = v_current_id where driver_id = v_target_id;
    update public.ride_requests set offered_driver_id = v_current_id where offered_driver_id = v_target_id;
    update public.ride_requests
      set declined_driver_ids = array_replace(declined_driver_ids, v_target_id, v_current_id)
      where v_target_id = any(declined_driver_ids);

    delete from public.drivers where id = v_target_id;
  end if;

  update public.driver_applications
  set user_id = v_current_id
  where user_id = v_target_id;

  -- Phone uniqueness means the old profile row must be removed before inserting
  -- the same account under the new auth user id. Transaction rollback protects it.
  delete from public.profiles where id = v_target_id;
  insert into public.profiles(id, display_name, phone, account_type, profile_photo_path, created_at, updated_at)
  values(v_current_id, v_name, v_phone, v_account_type, v_profile_photo_path, now(), now());

  return query
    select true, v_current_id, v_name, v_phone, v_account_type::text, v_profile_photo_path;
end;
$$;

revoke all on function public.portfolio_phone_login(text) from public, anon;
grant execute on function public.portfolio_phone_login(text) to authenticated;

create or replace function public.request_ride_v4(
  p_origin extensions.geography,
  p_destination extensions.geography,
  p_category_slug text,
  p_distance_meters integer,
  p_duration_seconds integer,
  p_payment_method text,
  p_pickup_label text default null,
  p_destination_label text default null
)
returns table(request_id uuid, request_status text, offered_driver_id uuid, fare_amount integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_passenger_id uuid := auth.uid();
  v_passenger_name text;
  v_passenger_phone text;
  v_category public.vehicle_categories%rowtype;
  v_driver_id uuid;
  v_request_id uuid;
  v_fare integer;
  v_payment public.ride_payment_method;
begin
  if v_passenger_id is null then raise exception 'Authentication required'; end if;

  select p.display_name, p.phone
    into v_passenger_name, v_passenger_phone
  from public.profiles p
  where p.id = v_passenger_id
    and p.account_type = 'passenger'::public.drivo_account_type;
  if not found then raise exception 'Passenger account required'; end if;

  if p_distance_meters is null or p_distance_meters < 0 or p_duration_seconds is null or p_duration_seconds < 0 then
    raise exception 'Invalid route metrics';
  end if;
  begin
    v_payment := p_payment_method::public.ride_payment_method;
  exception when invalid_text_representation then
    raise exception 'Invalid payment method';
  end;

  if v_payment = 'qr'::public.ride_payment_method and not exists (
    select 1 from public.drivers d
    join public.driver_applications da on da.user_id=d.id and da.status='approved'::public.driver_application_status
    where d.is_simulated=false and d.is_suspended=false and d.is_online=true and d.is_available=true
      and d.category_id=(select id from public.vehicle_categories where slug=p_category_slug limit 1)
      and d.payment_qr_path is not null
      and d.location is not null and extensions.st_dwithin(p_origin,d.location,5000)
  ) then
    raise exception 'No nearby driver with QR payment is available for this category';
  end if;

  if exists(select 1 from public.rides r where r.passenger_id=v_passenger_id and r.status::text not in('completed','cancelled')) then
    raise exception 'You already have an active ride';
  end if;
  if exists(select 1 from public.ride_requests rr where rr.passenger_id=v_passenger_id and rr.status='offered'::public.ride_request_status) then
    raise exception 'You already have a pending ride request';
  end if;

  select c.* into v_category from public.vehicle_categories c where c.slug=p_category_slug and c.is_active=true;
  if not found then raise exception 'Invalid vehicle category'; end if;

  v_fare:=greatest(
    v_category.minimum_fare,
    v_category.base_fare
      + ceil((p_distance_meters::numeric/1000)*v_category.per_km)::integer
      + ceil((p_duration_seconds::numeric/60)*v_category.per_minute)::integer
  );

  select d.id into v_driver_id
  from public.drivers d
  join public.profiles p on p.id=d.id
  join public.driver_applications da on da.user_id=d.id and da.status='approved'::public.driver_application_status
  where p.account_type='driver'::public.drivo_account_type
    and d.is_simulated=false and d.is_suspended=false and d.is_online=true and d.is_available=true
    and d.category_id=v_category.id and d.location is not null and d.id<>v_passenger_id
    and (v_payment='cash'::public.ride_payment_method or d.payment_qr_path is not null)
    and (d.last_location_at is null or d.last_location_at>now()-interval '10 minutes')
    and extensions.st_dwithin(p_origin,d.location,5000)
  order by extensions.st_distance(d.location,p_origin)
  for update skip locked limit 1;

  if v_driver_id is not null then
    update public.drivers set is_available=false where id=v_driver_id;
  end if;

  insert into public.ride_requests(
    passenger_id, passenger_name, passenger_phone, offered_driver_id, category_id,
    origin, destination, pickup_label, destination_label, distance_meters,
    duration_seconds, fare, status, payment_method
  ) values (
    v_passenger_id, v_passenger_name, v_passenger_phone, v_driver_id, v_category.id,
    p_origin, p_destination, nullif(left(btrim(p_pickup_label),160),''),
    nullif(left(btrim(p_destination_label),200),''), p_distance_meters,
    p_duration_seconds, v_fare,
    case when v_driver_id is null then 'no_driver'::public.ride_request_status else 'offered'::public.ride_request_status end,
    v_payment
  ) returning id into v_request_id;

  return query select v_request_id,
    case when v_driver_id is null then 'no_driver' else 'offered' end,
    v_driver_id, v_fare;
end;
$$;

create or replace function public.respond_to_ride_request_v2(p_request_id uuid, p_accept boolean)
returns table(action text, ride_id uuid, next_driver_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid:=auth.uid();
  v_request public.ride_requests%rowtype;
  v_next_driver_id uuid;
  v_ride_id uuid;
  v_fee integer;
  v_earning integer;
  v_qr_path text;
  v_driver_name text;
  v_driver_phone text;
  v_driver_vehicle text;
begin
  if v_driver_id is null then raise exception 'Authentication required'; end if;
  if not exists (select 1 from public.profiles p where p.id=v_driver_id and p.account_type='driver'::public.drivo_account_type) then
    raise exception 'Driver account required';
  end if;

  select * into v_request from public.ride_requests where id=p_request_id for update;
  if not found or v_request.status<>'offered'::public.ride_request_status then raise exception 'Ride request is no longer available'; end if;
  if v_request.offered_driver_id<>v_driver_id then raise exception 'This ride request is not assigned to you'; end if;

  select d.payment_qr_path, d.name, d.phone,
         coalesce(nullif(btrim(concat_ws(' ', nullif(d.vehicle_make,''), nullif(d.model,''))),''), d.model)
    into v_qr_path, v_driver_name, v_driver_phone, v_driver_vehicle
  from public.drivers d
  join public.driver_applications da on da.user_id=d.id and da.status='approved'::public.driver_application_status
  where d.id=v_driver_id and d.is_simulated=false and d.is_suspended=false and d.is_online=true;
  if not found then raise exception 'Driver is not approved and online'; end if;
  if v_request.payment_method='qr'::public.ride_payment_method and v_qr_path is null then
    raise exception 'Add your payment QR before accepting QR rides';
  end if;

  if p_accept then
    v_fee := round(v_request.fare * 0.10)::integer;
    v_earning := v_request.fare - v_fee;
    insert into public.rides(
      driver_id, passenger_id, passenger_name, passenger_phone,
      driver_name, driver_phone, driver_vehicle,
      origin, destination, fare, status, category_id, distance_meters,
      duration_seconds, pickup_label, destination_label, payment_method,
      payment_status, platform_fee, driver_earning, driver_payment_qr_path
    ) values (
      v_driver_id, v_request.passenger_id, v_request.passenger_name, v_request.passenger_phone,
      v_driver_name, v_driver_phone, v_driver_vehicle,
      v_request.origin, v_request.destination, v_request.fare,
      'driver_arriving'::public.ride_status, v_request.category_id,
      v_request.distance_meters, v_request.duration_seconds, v_request.pickup_label,
      v_request.destination_label, v_request.payment_method,
      'pending'::public.ride_payment_status, v_fee, v_earning, v_qr_path
    ) returning id into v_ride_id;

    update public.ride_requests
    set status='accepted'::public.ride_request_status, ride_id=v_ride_id, updated_at=now()
    where id=p_request_id;
    return query select 'accepted'::text,v_ride_id,null::uuid;
    return;
  end if;

  update public.drivers set is_available=is_online and not is_suspended where id=v_driver_id;
  update public.ride_requests
    set declined_driver_ids=array_append(declined_driver_ids,v_driver_id),updated_at=now()
    where id=p_request_id;

  select d.id into v_next_driver_id
  from public.drivers d
  join public.profiles p on p.id=d.id
  join public.driver_applications da on da.user_id=d.id and da.status='approved'::public.driver_application_status
  where p.account_type='driver'::public.drivo_account_type
    and d.is_simulated=false and d.is_suspended=false and d.is_online=true and d.is_available=true
    and d.category_id=v_request.category_id and d.location is not null and d.id<>v_request.passenger_id
    and (v_request.payment_method='cash'::public.ride_payment_method or d.payment_qr_path is not null)
    and not(d.id=any(array_append(v_request.declined_driver_ids,v_driver_id)))
    and (d.last_location_at is null or d.last_location_at>now()-interval '10 minutes')
    and extensions.st_dwithin(v_request.origin,d.location,5000)
  order by extensions.st_distance(d.location,v_request.origin)
  for update skip locked limit 1;

  if v_next_driver_id is null then
    update public.ride_requests set offered_driver_id=null,status='no_driver'::public.ride_request_status,updated_at=now() where id=p_request_id;
    return query select 'no_driver'::text,null::uuid,null::uuid;
  else
    update public.drivers set is_available=false where id=v_next_driver_id;
    update public.ride_requests set offered_driver_id=v_next_driver_id,status='offered'::public.ride_request_status,updated_at=now() where id=p_request_id;
    return query select 'reassigned'::text,null::uuid,v_next_driver_id;
  end if;
end;
$$;

-- A re-homed Driver account can still read previously uploaded documents whose
-- object paths retain the older anonymous auth uid folder.
drop policy if exists "Drivers can read their own application documents" on storage.objects;
create policy "Drivers can read their own application documents"
on storage.objects for select to authenticated
using (
  bucket_id = 'driver-documents'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.driver_applications da
      where da.user_id = (select auth.uid())
        and name in (
          da.profile_photo_path,
          da.license_photo_path,
          da.license_back_photo_path,
          da.registration_photo_path,
          da.registration_back_photo_path,
          da.insurance_photo_path,
          da.vehicle_front_photo_path,
          da.vehicle_rear_photo_path,
          da.vehicle_side_photo_path
        )
    )
  )
);

drop policy if exists "Driver and ride passenger can read payment QR" on storage.objects;
create policy "Driver and ride passenger can read payment QR"
on storage.objects for select to authenticated
using (
  bucket_id = 'driver-payment-assets'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.drivers d
      where d.id = (select auth.uid()) and d.payment_qr_path = name
    )
    or exists (
      select 1 from public.rides r
      where r.passenger_id = (select auth.uid()) and r.driver_payment_qr_path = name
    )
  )
);
