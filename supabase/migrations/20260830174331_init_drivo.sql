create extension if not exists postgis with schema extensions;

create table if not exists public.drivers (
    id uuid primary key default gen_random_uuid(),
    model text not null,
    number text not null,
    is_available boolean not null default false,
    location extensions.geography(POINT, 4326) not null,
    latitude double precision generated always as (extensions.st_y(location::extensions.geometry)) stored,
    longitude double precision generated always as (extensions.st_x(location::extensions.geometry)) stored
);
comment on table public.drivers is 'Holds the list of drivers and their locations.';

create type public.ride_status as enum ('picking_up', 'riding', 'completed');

create table if not exists public.rides (
    id uuid primary key default gen_random_uuid(),
    driver_id uuid not null references public.drivers(id),
    passenger_id uuid not null references auth.users(id),
    origin extensions.geography(POINT, 4326) not null,
    destination extensions.geography(POINT, 4326) not null,
    fare integer not null check (fare >= 0),
    status public.ride_status not null default 'picking_up'
);
comment on table public.rides is 'A ride created when an authenticated passenger requests a nearby driver.';

alter table public.drivers enable row level security;
alter table public.rides enable row level security;
revoke all on table public.drivers from anon;
revoke all on table public.rides from anon;
grant select on table public.drivers to authenticated;
grant update (is_available, location) on table public.drivers to authenticated;
grant select on table public.rides to authenticated;
grant update (status) on table public.rides to authenticated;

create policy "Authenticated users can view drivers" on public.drivers for select to authenticated using (true);
create policy "Drivers can update their own location and availability" on public.drivers for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "Ride participants can view their ride" on public.rides for select to authenticated using (driver_id = (select auth.uid()) or passenger_id = (select auth.uid()));
create policy "Drivers can update their ride status" on public.rides for update to authenticated using (driver_id = (select auth.uid())) with check (driver_id = (select auth.uid()));

create or replace function public.update_driver_status()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.drivers set is_available = (new.status = 'completed'::public.ride_status) where id = new.driver_id;
  return new;
end;
$$;
revoke all on function public.update_driver_status() from public, anon, authenticated;
drop trigger if exists driver_status_update_trigger on public.rides;
create trigger driver_status_update_trigger after insert or update of status on public.rides for each row execute function public.update_driver_status();

create or replace function public.find_driver(origin extensions.geography, destination extensions.geography, fare integer)
returns table(driver_id uuid, ride_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  v_driver_id uuid;
  v_ride_id uuid;
  v_passenger_id uuid := auth.uid();
begin
  if v_passenger_id is null then raise exception 'Authentication required'; end if;
  if fare is null or fare < 0 then raise exception 'Invalid fare'; end if;

  select d.id into v_driver_id
  from public.drivers d
  where d.is_available = true and extensions.st_dwithin(origin, d.location, 3000)
  order by extensions.st_distance(d.location, origin)
  for update skip locked
  limit 1;

  if v_driver_id is null then return; end if;
  update public.drivers set is_available = false where id = v_driver_id;
  insert into public.rides (driver_id, passenger_id, origin, destination, fare)
  values (v_driver_id, v_passenger_id, origin, destination, fare)
  returning id into v_ride_id;
  return query select v_driver_id, v_ride_id;
end;
$$;
revoke all on function public.find_driver(extensions.geography, extensions.geography, integer) from public, anon;
grant execute on function public.find_driver(extensions.geography, extensions.geography, integer) to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='drivers') then
    alter publication supabase_realtime add table public.drivers;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rides') then
    alter publication supabase_realtime add table public.rides;
  end if;
end $$;
