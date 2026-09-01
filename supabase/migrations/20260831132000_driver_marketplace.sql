-- Drivo driver marketplace: applications, approval, driver presence, and real ride dispatch.

create type public.driver_application_status as enum ('pending', 'approved', 'rejected');
create type public.ride_request_status as enum ('offered', 'accepted', 'no_driver', 'cancelled');

create table public.driver_applications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references auth.users(id) on delete cascade,
    full_name text not null check (char_length(btrim(full_name)) between 2 and 80),
    phone text not null check (phone ~ '^[0-9]{10}$'),
    category_id uuid not null references public.vehicle_categories(id),
    vehicle_model text not null check (char_length(btrim(vehicle_model)) between 2 and 80),
    vehicle_color text not null check (char_length(btrim(vehicle_color)) between 2 and 40),
    plate_number text not null check (char_length(btrim(plate_number)) between 3 and 30),
    license_number text not null check (char_length(btrim(license_number)) between 3 and 60),
    profile_photo_path text not null,
    license_photo_path text not null,
    registration_photo_path text not null,
    status public.driver_application_status not null default 'pending',
    review_note text,
    submitted_at timestamptz not null default now(),
    reviewed_at timestamptz,
    updated_at timestamptz not null default now()
);

alter table public.driver_applications enable row level security;
revoke all on table public.driver_applications from anon;
revoke all on table public.driver_applications from authenticated;
grant select, insert on table public.driver_applications to authenticated;

create policy "Users can view their driver application"
on public.driver_applications
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users can submit a pending driver application"
on public.driver_applications
for insert
to authenticated
with check (
    user_id = (select auth.uid())
    and status = 'pending'::public.driver_application_status
    and reviewed_at is null
    and review_note is null
);

create index driver_applications_status_idx
    on public.driver_applications (status, submitted_at desc);

-- Driver documents are sensitive: keep them in a private bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'driver-documents',
    'driver-documents',
    false,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Drivers can upload their own application documents"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Drivers can read their own application documents"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Approved driver state lives in public.drivers. Approval is the only normal path that creates it.
alter table public.drivers
    alter column location drop not null,
    add column phone text,
    add column vehicle_color text,
    add column application_id uuid unique references public.driver_applications(id),
    add column is_online boolean not null default false,
    add column is_suspended boolean not null default false,
    add column last_location_at timestamptz;

-- Existing simulator rows are retained for historical rides but can never dispatch again.
update public.drivers
set is_available = false,
    is_online = false
where is_simulated = true;

revoke update (is_available, location) on public.drivers from authenticated;
revoke update (status) on public.rides from authenticated;

-- Tighten self-update policy even though direct update grants are removed.
drop policy if exists "Drivers can update their own location and availability" on public.drivers;
create policy "Approved drivers can update their own operational row"
on public.drivers
for update
to authenticated
using (id = (select auth.uid()) and is_simulated = false and is_suspended = false)
with check (id = (select auth.uid()) and is_simulated = false and is_suspended = false);

create or replace function public.process_driver_application_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    new.updated_at := now();

    if new.status is distinct from old.status then
        if new.status in ('approved'::public.driver_application_status, 'rejected'::public.driver_application_status) then
            new.reviewed_at := coalesce(new.reviewed_at, now());
        end if;
    end if;

    if new.status = 'approved'::public.driver_application_status
       and old.status is distinct from new.status then
        insert into public.drivers (
            id,
            name,
            phone,
            model,
            number,
            vehicle_color,
            is_available,
            is_online,
            is_suspended,
            location,
            category_id,
            is_simulated,
            application_id
        ) values (
            new.user_id,
            btrim(new.full_name),
            new.phone,
            btrim(new.vehicle_model),
            upper(btrim(new.plate_number)),
            btrim(new.vehicle_color),
            false,
            false,
            false,
            null,
            new.category_id,
            false,
            new.id
        )
        on conflict (id) do update set
            name = excluded.name,
            phone = excluded.phone,
            model = excluded.model,
            number = excluded.number,
            vehicle_color = excluded.vehicle_color,
            category_id = excluded.category_id,
            application_id = excluded.application_id,
            is_simulated = false,
            is_suspended = false,
            is_online = false,
            is_available = false;
    elsif new.status = 'rejected'::public.driver_application_status
       and old.status is distinct from new.status then
        update public.drivers
        set is_suspended = true,
            is_online = false,
            is_available = false
        where id = new.user_id
          and is_simulated = false;
    end if;

    return new;
end;
$$;

revoke all on function public.process_driver_application_review() from public, anon, authenticated;

drop trigger if exists driver_application_review_trigger on public.driver_applications;
create trigger driver_application_review_trigger
before update on public.driver_applications
for each row
execute function public.process_driver_application_review();

-- Realtime-visible offer row. A ride is created only after a driver accepts.
create table public.ride_requests (
    id uuid primary key default gen_random_uuid(),
    passenger_id uuid not null references auth.users(id) on delete cascade,
    offered_driver_id uuid references public.drivers(id),
    category_id uuid not null references public.vehicle_categories(id),
    origin extensions.geography(POINT, 4326) not null,
    destination extensions.geography(POINT, 4326) not null,
    origin_latitude double precision generated always as (extensions.st_y(origin::extensions.geometry)) stored,
    origin_longitude double precision generated always as (extensions.st_x(origin::extensions.geometry)) stored,
    destination_latitude double precision generated always as (extensions.st_y(destination::extensions.geometry)) stored,
    destination_longitude double precision generated always as (extensions.st_x(destination::extensions.geometry)) stored,
    pickup_label text,
    destination_label text,
    distance_meters integer not null check (distance_meters >= 0),
    duration_seconds integer not null check (duration_seconds >= 0),
    fare integer not null check (fare >= 0),
    status public.ride_request_status not null,
    declined_driver_ids uuid[] not null default '{}'::uuid[],
    ride_id uuid references public.rides(id),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.ride_requests enable row level security;
revoke all on table public.ride_requests from anon;
revoke all on table public.ride_requests from authenticated;
grant select on table public.ride_requests to authenticated;

create policy "Passengers and offered drivers can view ride requests"
on public.ride_requests
for select
to authenticated
using (
    passenger_id = (select auth.uid())
    or offered_driver_id = (select auth.uid())
);

create index ride_requests_passenger_status_idx
    on public.ride_requests (passenger_id, status, created_at desc);
create index ride_requests_driver_status_idx
    on public.ride_requests (offered_driver_id, status, created_at desc);

create or replace function public.request_ride_v3(
    p_origin extensions.geography,
    p_destination extensions.geography,
    p_category_slug text,
    p_distance_meters integer,
    p_duration_seconds integer,
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
    v_category public.vehicle_categories%rowtype;
    v_driver_id uuid;
    v_request_id uuid;
    v_fare integer;
begin
    if v_passenger_id is null then
        raise exception 'Authentication required';
    end if;

    if p_distance_meters is null or p_distance_meters < 0
       or p_duration_seconds is null or p_duration_seconds < 0 then
        raise exception 'Invalid route metrics';
    end if;

    if exists (
        select 1 from public.rides r
        where r.passenger_id = v_passenger_id
          and r.status::text not in ('completed', 'cancelled')
    ) then
        raise exception 'You already have an active ride';
    end if;

    if exists (
        select 1 from public.ride_requests rr
        where rr.passenger_id = v_passenger_id
          and rr.status = 'offered'::public.ride_request_status
    ) then
        raise exception 'You already have a pending ride request';
    end if;

    select c.* into v_category
    from public.vehicle_categories c
    where c.slug = p_category_slug and c.is_active = true;

    if not found then
        raise exception 'Invalid vehicle category';
    end if;

    v_fare := greatest(
        v_category.minimum_fare,
        v_category.base_fare
        + ceil((p_distance_meters::numeric / 1000) * v_category.per_km)::integer
        + ceil((p_duration_seconds::numeric / 60) * v_category.per_minute)::integer
    );

    select d.id into v_driver_id
    from public.drivers d
    where d.is_simulated = false
      and d.is_suspended = false
      and d.is_online = true
      and d.is_available = true
      and d.category_id = v_category.id
      and d.location is not null
      and d.id <> v_passenger_id
      and (d.last_location_at is null or d.last_location_at > now() - interval '10 minutes')
      and extensions.st_dwithin(p_origin, d.location, 5000)
    order by extensions.st_distance(d.location, p_origin)
    for update skip locked
    limit 1;

    if v_driver_id is not null then
        update public.drivers
        set is_available = false
        where id = v_driver_id;
    end if;

    insert into public.ride_requests (
        passenger_id,
        offered_driver_id,
        category_id,
        origin,
        destination,
        pickup_label,
        destination_label,
        distance_meters,
        duration_seconds,
        fare,
        status
    ) values (
        v_passenger_id,
        v_driver_id,
        v_category.id,
        p_origin,
        p_destination,
        nullif(left(btrim(p_pickup_label), 160), ''),
        nullif(left(btrim(p_destination_label), 200), ''),
        p_distance_meters,
        p_duration_seconds,
        v_fare,
        case when v_driver_id is null
            then 'no_driver'::public.ride_request_status
            else 'offered'::public.ride_request_status
        end
    ) returning id into v_request_id;

    return query
    select
        v_request_id,
        case when v_driver_id is null then 'no_driver' else 'offered' end,
        v_driver_id,
        v_fare;
end;
$$;

revoke all on function public.request_ride_v3(extensions.geography, extensions.geography, text, integer, integer, text, text) from public, anon;
grant execute on function public.request_ride_v3(extensions.geography, extensions.geography, text, integer, integer, text, text) to authenticated;

create or replace function public.respond_to_ride_request(
    p_request_id uuid,
    p_accept boolean
)
returns table(action text, ride_id uuid, next_driver_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_driver_id uuid := auth.uid();
    v_request public.ride_requests%rowtype;
    v_next_driver_id uuid;
    v_ride_id uuid;
begin
    if v_driver_id is null then raise exception 'Authentication required'; end if;

    select * into v_request
    from public.ride_requests
    where id = p_request_id
    for update;

    if not found or v_request.status <> 'offered'::public.ride_request_status then
        raise exception 'Ride request is no longer available';
    end if;

    if v_request.offered_driver_id <> v_driver_id then
        raise exception 'This ride request is not assigned to you';
    end if;

    if not exists (
        select 1 from public.drivers d
        where d.id = v_driver_id
          and d.is_simulated = false
          and d.is_suspended = false
          and d.is_online = true
    ) then
        raise exception 'Driver is not approved and online';
    end if;

    if p_accept then
        insert into public.rides (
            driver_id,
            passenger_id,
            origin,
            destination,
            fare,
            status,
            category_id,
            distance_meters,
            duration_seconds,
            pickup_label,
            destination_label
        ) values (
            v_driver_id,
            v_request.passenger_id,
            v_request.origin,
            v_request.destination,
            v_request.fare,
            'driver_arriving'::public.ride_status,
            v_request.category_id,
            v_request.distance_meters,
            v_request.duration_seconds,
            v_request.pickup_label,
            v_request.destination_label
        ) returning id into v_ride_id;

        update public.ride_requests
        set status = 'accepted'::public.ride_request_status,
            ride_id = v_ride_id,
            updated_at = now()
        where id = p_request_id;

        return query select 'accepted'::text, v_ride_id, null::uuid;
        return;
    end if;

    update public.drivers
    set is_available = is_online and not is_suspended
    where id = v_driver_id;

    update public.ride_requests
    set declined_driver_ids = array_append(declined_driver_ids, v_driver_id),
        updated_at = now()
    where id = p_request_id;

    select d.id into v_next_driver_id
    from public.drivers d
    where d.is_simulated = false
      and d.is_suspended = false
      and d.is_online = true
      and d.is_available = true
      and d.category_id = v_request.category_id
      and d.location is not null
      and d.id <> v_request.passenger_id
      and not (d.id = any(array_append(v_request.declined_driver_ids, v_driver_id)))
      and (d.last_location_at is null or d.last_location_at > now() - interval '10 minutes')
      and extensions.st_dwithin(v_request.origin, d.location, 5000)
    order by extensions.st_distance(d.location, v_request.origin)
    for update skip locked
    limit 1;

    if v_next_driver_id is null then
        update public.ride_requests
        set offered_driver_id = null,
            status = 'no_driver'::public.ride_request_status,
            updated_at = now()
        where id = p_request_id;
        return query select 'no_driver'::text, null::uuid, null::uuid;
    else
        update public.drivers set is_available = false where id = v_next_driver_id;
        update public.ride_requests
        set offered_driver_id = v_next_driver_id,
            status = 'offered'::public.ride_request_status,
            updated_at = now()
        where id = p_request_id;
        return query select 'reassigned'::text, null::uuid, v_next_driver_id;
    end if;
end;
$$;

revoke all on function public.respond_to_ride_request(uuid, boolean) from public, anon;
grant execute on function public.respond_to_ride_request(uuid, boolean) to authenticated;

create or replace function public.set_driver_presence(
    p_online boolean,
    p_latitude double precision default null,
    p_longitude double precision default null
)
returns table(is_online boolean, is_available boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_driver_id uuid := auth.uid();
    v_available boolean;
begin
    if v_driver_id is null then raise exception 'Authentication required'; end if;
    if not exists (
        select 1 from public.drivers d
        where d.id = v_driver_id and d.is_simulated = false and d.is_suspended = false
    ) then raise exception 'Approved driver account required'; end if;

    if p_online and (p_latitude is null or p_longitude is null
       or p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180) then
        raise exception 'Valid current location is required to go online';
    end if;

    if not p_online and exists (
        select 1 from public.rides r
        where r.driver_id = v_driver_id and r.status::text not in ('completed', 'cancelled')
    ) then raise exception 'Complete the active ride before going offline'; end if;

    if not p_online and exists (
        select 1 from public.ride_requests rr
        where rr.offered_driver_id = v_driver_id
          and rr.status = 'offered'::public.ride_request_status
    ) then raise exception 'Respond to the current ride request before going offline'; end if;

    v_available := p_online
        and not exists (
            select 1 from public.rides r
            where r.driver_id = v_driver_id and r.status::text not in ('completed', 'cancelled')
        )
        and not exists (
            select 1 from public.ride_requests rr
            where rr.offered_driver_id = v_driver_id and rr.status = 'offered'::public.ride_request_status
        );

    update public.drivers
    set is_online = p_online,
        is_available = v_available,
        location = case when p_online then extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography else location end,
        last_location_at = case when p_online then now() else last_location_at end
    where id = v_driver_id;

    return query select p_online, v_available;
end;
$$;

revoke all on function public.set_driver_presence(boolean, double precision, double precision) from public, anon;
grant execute on function public.set_driver_presence(boolean, double precision, double precision) to authenticated;

create or replace function public.update_driver_location(
    p_latitude double precision,
    p_longitude double precision
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_driver_id uuid := auth.uid();
begin
    if v_driver_id is null then raise exception 'Authentication required'; end if;
    if p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180 then
        raise exception 'Invalid location';
    end if;

    update public.drivers
    set location = extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography,
        last_location_at = now()
    where id = v_driver_id
      and is_simulated = false
      and is_suspended = false
      and is_online = true;

    return found;
end;
$$;

revoke all on function public.update_driver_location(double precision, double precision) from public, anon;
grant execute on function public.update_driver_location(double precision, double precision) to authenticated;

create or replace function public.driver_update_ride_status(
    p_ride_id uuid,
    p_status text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_driver_id uuid := auth.uid();
    v_current text;
begin
    if v_driver_id is null then raise exception 'Authentication required'; end if;

    select r.status::text into v_current
    from public.rides r
    where r.id = p_ride_id and r.driver_id = v_driver_id
    for update;

    if v_current is null then raise exception 'Ride not found'; end if;

    if not (
        (v_current = 'driver_arriving' and p_status = 'driver_arrived')
        or (v_current = 'driver_arrived' and p_status = 'in_progress')
        or (v_current = 'in_progress' and p_status = 'completed')
    ) then raise exception 'Invalid ride status transition'; end if;

    update public.rides
    set status = p_status::public.ride_status
    where id = p_ride_id;

    return p_status;
end;
$$;

revoke all on function public.driver_update_ride_status(uuid, text) from public, anon;
grant execute on function public.driver_update_ride_status(uuid, text) to authenticated;

-- Completion only makes a driver available when they are still online and approved.
create or replace function public.update_driver_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.drivers
    set is_available = (
        new.status::text in ('completed', 'cancelled')
        and is_online = true
        and is_suspended = false
        and is_simulated = false
    )
    where id = new.driver_id;
    return new;
end;
$$;
revoke all on function public.update_driver_status() from public, anon, authenticated;

-- Old simulator/immediate-dispatch APIs are no longer part of the client contract.
revoke execute on function public.find_driver(extensions.geography, extensions.geography, integer) from authenticated;
revoke execute on function public.request_ride(extensions.geography, extensions.geography, text, integer, integer) from authenticated;
revoke execute on function public.request_ride_v2(extensions.geography, extensions.geography, text, integer, integer, text, text) from authenticated;
revoke execute on function public.dev_ensure_nearby_driver(extensions.geography, text) from authenticated;
revoke execute on function public.dev_simulate_ride_step(uuid) from authenticated;

-- Realtime subscriptions for approval and dispatch.
do $$
begin
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'driver_applications'
    ) then
        alter publication supabase_realtime add table public.driver_applications;
    end if;
    if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ride_requests'
    ) then
        alter publication supabase_realtime add table public.ride_requests;
    end if;
end $$;
