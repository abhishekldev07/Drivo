-- Drivo account identity is fixed after portfolio registration.
revoke execute on function public.update_own_profile_name(text) from authenticated;

-- Marketplace tables are read-only to the mobile client; state changes happen through guarded RPCs.
revoke insert, update, delete on public.rides from authenticated;
grant select on public.rides to authenticated;
revoke insert, update, delete on public.ride_requests from authenticated;
grant select on public.ride_requests to authenticated;
revoke insert, update, delete on public.drivers from authenticated;
grant select on public.drivers to authenticated;
revoke insert, update, delete on public.driver_applications from authenticated;
grant select on public.driver_applications to authenticated;
