alter table public.rides
    alter column status set default 'driver_arriving'::public.ride_status;

create or replace function public.update_driver_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.drivers
    set is_available = (new.status::text in ('completed', 'cancelled'))
    where id = new.driver_id;
    return new;
end;
$$;

revoke all on function public.update_driver_status() from public, anon, authenticated;

drop trigger if exists driver_status_update_trigger on public.rides;
create trigger driver_status_update_trigger
after insert or update of status on public.rides
for each row
execute function public.update_driver_status();

create or replace function public.estimate_fares(
    p_distance_meters integer,
    p_duration_seconds integer
)
returns table(
    category_slug text,
    category_name text,
    capacity integer,
    fare integer
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        c.slug,
        c.name,
        c.capacity,
        greatest(
            c.minimum_fare,
            c.base_fare
            + ceil((p_distance_meters::numeric / 1000) * c.per_km)::integer
            + ceil((p_duration_seconds::numeric / 60) * c.per_minute)::integer
        ) as fare
    from public.vehicle_categories as c
    where c.is_active = true
      and p_distance_meters >= 0
      and p_duration_seconds >= 0
    order by c.display_order;
$$;

revoke all on function public.estimate_fares(integer, integer) from public, anon;
grant execute on function public.estimate_fares(integer, integer) to authenticated;

create or replace function public.request_ride(
    p_origin extensions.geography,
    p_destination extensions.geography,
    p_category_slug text,
    p_distance_meters integer,
    p_duration_seconds integer
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
        duration_seconds
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
        p_duration_seconds
    )
    returning id into v_ride_id;

    return query select v_driver_id, v_ride_id, v_fare;
end;
$$;

revoke all on function public.request_ride(extensions.geography, extensions.geography, text, integer, integer) from public, anon;
grant execute on function public.request_ride(extensions.geography, extensions.geography, text, integer, integer) to authenticated;

create schema if not exists private;
revoke all on schema private from public;

create table if not exists private.ride_simulations (
    ride_id uuid primary key references public.rides(id) on delete cascade,
    pickup_start extensions.geography(POINT, 4326) not null,
    pickup_step integer not null default 0,
    trip_step integer not null default 0,
    updated_at timestamptz not null default now()
);

create or replace function public.dev_ensure_nearby_driver(
    p_origin extensions.geography,
    p_category_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_category_id uuid;
    v_driver_id uuid;
    v_model text;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    select c.id
    into v_category_id
    from public.vehicle_categories as c
    where c.slug = p_category_slug
      and c.is_active = true;

    if v_category_id is null then
        raise exception 'Invalid vehicle category';
    end if;

    select d.id
    into v_driver_id
    from public.drivers as d
    where d.is_simulated = true
      and d.is_available = true
      and d.category_id = v_category_id
    order by d.id
    limit 1;

    if v_driver_id is not null then
        update public.drivers
        set location = extensions.st_project(p_origin, 900, 0.7853981633974483)
        where id = v_driver_id;
        return v_driver_id;
    end if;

    v_model := case p_category_slug
        when 'bike' then 'Drivo Demo Bike'
        when 'mini' then 'Drivo Demo Mini'
        when 'xl' then 'Drivo Demo XL'
        else 'Drivo Demo Car'
    end;

    insert into public.drivers (
        name,
        model,
        number,
        is_available,
        location,
        category_id,
        is_simulated,
        rating
    )
    values (
        'Aarav (Demo)',
        v_model,
        'DRIVO-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4)),
        true,
        extensions.st_project(p_origin, 900, 0.7853981633974483),
        v_category_id,
        true,
        4.9
    )
    returning id into v_driver_id;

    return v_driver_id;
end;
$$;

revoke all on function public.dev_ensure_nearby_driver(extensions.geography, text) from public, anon;
grant execute on function public.dev_ensure_nearby_driver(extensions.geography, text) to authenticated;

create or replace function public.dev_simulate_ride_step(p_ride_id uuid)
returns table(ride_status text, simulation_step integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_passenger_id uuid;
    v_driver_id uuid;
    v_origin extensions.geography;
    v_destination extensions.geography;
    v_status text;
    v_pickup_start extensions.geography;
    v_pickup_step integer;
    v_trip_step integer;
    v_fraction double precision;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    select r.passenger_id, r.driver_id, r.origin, r.destination, r.status::text
    into v_passenger_id, v_driver_id, v_origin, v_destination, v_status
    from public.rides as r
    where r.id = p_ride_id;

    if v_passenger_id is null then
        raise exception 'Ride not found';
    end if;

    if v_passenger_id <> auth.uid() then
        raise exception 'Not allowed';
    end if;

    insert into private.ride_simulations (ride_id, pickup_start)
    select p_ride_id, d.location
    from public.drivers as d
    where d.id = v_driver_id
    on conflict (ride_id) do nothing;

    select s.pickup_start, s.pickup_step, s.trip_step
    into v_pickup_start, v_pickup_step, v_trip_step
    from private.ride_simulations as s
    where s.ride_id = p_ride_id;

    if v_status = 'driver_arriving' then
        v_pickup_step := least(v_pickup_step + 1, 6);
        v_fraction := v_pickup_step::double precision / 6.0;

        update private.ride_simulations
        set pickup_step = v_pickup_step, updated_at = now()
        where ride_id = p_ride_id;

        update public.drivers
        set location = extensions.st_lineinterpolatepoint(
            extensions.st_makeline(
                v_pickup_start::extensions.geometry,
                v_origin::extensions.geometry
            ),
            v_fraction
        )::extensions.geography
        where id = v_driver_id;

        if v_pickup_step >= 6 then
            update public.rides
            set status = 'driver_arrived'::public.ride_status
            where id = p_ride_id;
        end if;

    elsif v_status = 'driver_arrived' then
        update public.rides
        set status = 'in_progress'::public.ride_status
        where id = p_ride_id;

        update private.ride_simulations
        set trip_step = 0, updated_at = now()
        where ride_id = p_ride_id;

        update public.drivers
        set location = v_origin
        where id = v_driver_id;

    elsif v_status = 'in_progress' then
        v_trip_step := least(v_trip_step + 1, 10);
        v_fraction := v_trip_step::double precision / 10.0;

        update private.ride_simulations
        set trip_step = v_trip_step, updated_at = now()
        where ride_id = p_ride_id;

        update public.drivers
        set location = extensions.st_lineinterpolatepoint(
            extensions.st_makeline(
                v_origin::extensions.geometry,
                v_destination::extensions.geometry
            ),
            v_fraction
        )::extensions.geography
        where id = v_driver_id;

        if v_trip_step >= 10 then
            update public.rides
            set status = 'completed'::public.ride_status
            where id = p_ride_id;
        end if;
    end if;

    return query
    select r.status::text, greatest(s.pickup_step, s.trip_step)
    from public.rides as r
    join private.ride_simulations as s on s.ride_id = r.id
    where r.id = p_ride_id;
end;
$$;

revoke all on function public.dev_simulate_ride_step(uuid) from public, anon;
grant execute on function public.dev_simulate_ride_step(uuid) to authenticated;
