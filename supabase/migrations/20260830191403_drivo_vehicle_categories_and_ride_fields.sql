alter type public.ride_status add value if not exists 'driver_arriving';
alter type public.ride_status add value if not exists 'driver_arrived';
alter type public.ride_status add value if not exists 'in_progress';
alter type public.ride_status add value if not exists 'cancelled';

create table if not exists public.vehicle_categories (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique,
    name text not null,
    capacity integer not null check (capacity > 0),
    base_fare integer not null check (base_fare >= 0),
    per_km integer not null check (per_km >= 0),
    per_minute integer not null check (per_minute >= 0),
    minimum_fare integer not null check (minimum_fare >= 0),
    display_order integer not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

alter table public.vehicle_categories enable row level security;
revoke all on table public.vehicle_categories from anon;
grant select on table public.vehicle_categories to authenticated;

create policy "Authenticated users can view active vehicle categories"
on public.vehicle_categories
for select
to authenticated
using (is_active = true);

insert into public.vehicle_categories
    (slug, name, capacity, base_fare, per_km, per_minute, minimum_fare, display_order)
values
    ('bike', 'Drivo Bike', 1, 35, 18, 2, 60, 1),
    ('mini', 'Drivo Mini', 3, 60, 28, 3, 110, 2),
    ('car', 'Drivo Car', 4, 80, 38, 4, 150, 3),
    ('xl', 'Drivo XL', 6, 120, 55, 5, 220, 4)
on conflict (slug) do update set
    name = excluded.name,
    capacity = excluded.capacity,
    base_fare = excluded.base_fare,
    per_km = excluded.per_km,
    per_minute = excluded.per_minute,
    minimum_fare = excluded.minimum_fare,
    display_order = excluded.display_order,
    is_active = true;

alter table public.drivers
    add column if not exists name text not null default 'Drivo Driver',
    add column if not exists rating numeric(2,1) not null default 5.0 check (rating >= 0 and rating <= 5),
    add column if not exists category_id uuid references public.vehicle_categories(id),
    add column if not exists is_simulated boolean not null default false;

alter table public.rides
    add column if not exists category_id uuid references public.vehicle_categories(id),
    add column if not exists distance_meters integer check (distance_meters is null or distance_meters >= 0),
    add column if not exists duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
    add column if not exists created_at timestamptz not null default now();

create index if not exists drivers_available_category_idx
    on public.drivers (category_id, is_available);
create index if not exists rides_category_id_idx
    on public.rides (category_id);
create index if not exists rides_created_at_idx
    on public.rides (created_at desc);
