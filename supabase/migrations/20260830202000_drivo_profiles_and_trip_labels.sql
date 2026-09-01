create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null check (char_length(btrim(display_name)) between 2 and 60),
    email text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_email_length check (email is null or char_length(email) <= 160)
);

alter table public.profiles enable row level security;
revoke all on table public.profiles from anon;
grant select, insert, update on table public.profiles to authenticated;

create policy "Passengers can view their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Passengers can create their own profile"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

create policy "Passengers can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

alter table public.rides
    add column if not exists pickup_label text,
    add column if not exists destination_label text;

create or replace function public.request_ride_v2(
    p_origin extensions.geography,
    p_destination extensions.geography,
    p_category_slug text,
    p_distance_meters integer,
    p_duration_seconds integer,
    p_pickup_label text default null,
    p_destination_label text default null
)
returns table(driver_id uuid, ride_id uuid, fare_amount integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_passenger_id uuid := auth.uid();
    v_category public.vehicle_categories%rowtype;
    v_driver_id uuid;
    v_ride_id uuid;
    v_fare integer;
begin
    if v_passenger_id is null then
        raise exception 'Authentication required';
    end if;

    if p_distance_meters is null or p_distance_meters < 0
       or p_duration_seconds is null or p_duration_seconds < 0 then
        raise exception 'Invalid route metrics';
    end if;

    select c.*
    into v_category
    from public.vehicle_categories as c
    where c.slug = p_category_slug
      and c.is_active = true;

    if not found then
        raise exception 'Invalid vehicle category';
    end if;

    v_fare := greatest(
        v_category.minimum_fare,
        v_category.base_fare
        + ceil((p_distance_meters::numeric / 1000) * v_category.per_km)::integer
        + ceil((p_duration_seconds::numeric / 60) * v_category.per_minute)::integer
    );

    select d.id
    into v_driver_id
    from public.drivers as d
    where d.is_available = true
      and d.category_id = v_category.id
      and extensions.st_dwithin(p_origin, d.location, 5000)
    order by extensions.st_distance(d.location, p_origin)
    for update skip locked
    limit 1;

    if v_driver_id is null then
        return;
    end if;

    update public.drivers
    set is_available = false
    where id = v_driver_id;

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
    )
    values (
        v_driver_id,
        v_passenger_id,
        p_origin,
        p_destination,
        v_fare,
        'driver_arriving'::public.ride_status,
        v_category.id,
        p_distance_meters,
        p_duration_seconds,
        nullif(left(btrim(p_pickup_label), 160), ''),
        nullif(left(btrim(p_destination_label), 200), '')
    )
    returning id into v_ride_id;

    return query select v_driver_id, v_ride_id, v_fare;
end;
$$;

revoke all on function public.request_ride_v2(extensions.geography, extensions.geography, text, integer, integer, text, text) from public, anon;
grant execute on function public.request_ride_v2(extensions.geography, extensions.geography, text, integer, integer, text, text) to authenticated;
