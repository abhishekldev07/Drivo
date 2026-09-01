create or replace function public.get_ride_and_driver(ride_id uuid)
returns table(driver_id uuid, origin json, destination json, driver_location json)
language sql security invoker set search_path = '' as $$
select r.driver_id,
  json_build_object('lat', extensions.st_y(r.origin::extensions.geometry), 'lng', extensions.st_x(r.origin::extensions.geometry)),
  json_build_object('lat', extensions.st_y(r.destination::extensions.geometry), 'lng', extensions.st_x(r.destination::extensions.geometry)),
  json_build_object('lat', extensions.st_y(d.location::extensions.geometry), 'lng', extensions.st_x(d.location::extensions.geometry))
from public.rides r join public.drivers d on d.id=r.driver_id where r.id=$1;
$$;
revoke all on function public.get_ride_and_driver(uuid) from public, anon, authenticated;
grant execute on function public.get_ride_and_driver(uuid) to service_role;
