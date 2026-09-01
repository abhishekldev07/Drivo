create index if not exists drivers_location_gix on public.drivers using gist (location);
create index if not exists rides_driver_id_idx on public.rides (driver_id);
create index if not exists rides_passenger_id_idx on public.rides (passenger_id);
