alter table public.rides
    add column if not exists origin_latitude double precision generated always as (extensions.st_y(origin::extensions.geometry)) stored,
    add column if not exists origin_longitude double precision generated always as (extensions.st_x(origin::extensions.geometry)) stored,
    add column if not exists destination_latitude double precision generated always as (extensions.st_y(destination::extensions.geometry)) stored,
    add column if not exists destination_longitude double precision generated always as (extensions.st_x(destination::extensions.geometry)) stored;
