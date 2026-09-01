create index if not exists driver_applications_category_id_idx on public.driver_applications(category_id);
create index if not exists ride_requests_category_id_idx on public.ride_requests(category_id);
create index if not exists ride_requests_ride_id_idx on public.ride_requests(ride_id) where ride_id is not null;
