create or replace function public.set_driver_presence(p_online boolean,p_latitude double precision default null,p_longitude double precision default null)
returns table(is_online boolean,is_available boolean)
language plpgsql security definer set search_path=''
as $$
declare v_driver_id uuid:=auth.uid(); v_available boolean;
begin
  if v_driver_id is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.drivers d
    join public.profiles p on p.id=d.id
    join public.driver_applications da on da.user_id=d.id
    where d.id=v_driver_id and p.account_type='driver'::public.drivo_account_type
      and da.status='approved'::public.driver_application_status
      and d.is_simulated=false and d.is_suspended=false
  ) then raise exception 'Approved driver account required'; end if;
  if p_online and (p_latitude is null or p_longitude is null or p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180) then raise exception 'Valid current location is required to go online'; end if;
  if not p_online and exists(select 1 from public.rides r where r.driver_id=v_driver_id and r.status::text not in('completed','cancelled')) then raise exception 'Complete the active ride before going offline'; end if;
  if not p_online and exists(select 1 from public.ride_requests rr where rr.offered_driver_id=v_driver_id and rr.status='offered'::public.ride_request_status) then raise exception 'Respond to the current ride request before going offline'; end if;
  v_available:=p_online
    and not exists(select 1 from public.rides r where r.driver_id=v_driver_id and r.status::text not in('completed','cancelled'))
    and not exists(select 1 from public.rides r where r.driver_id=v_driver_id and r.status='completed'::public.ride_status and r.payment_status='pending'::public.ride_payment_status)
    and not exists(select 1 from public.ride_requests rr where rr.offered_driver_id=v_driver_id and rr.status='offered'::public.ride_request_status);
  update public.drivers set is_online=p_online,is_available=v_available,location=case when p_online then extensions.st_setsrid(extensions.st_makepoint(p_longitude,p_latitude),4326)::extensions.geography else location end,last_location_at=case when p_online then now() else last_location_at end where id=v_driver_id;
  return query select p_online,v_available;
end;
$$;
revoke all on function public.set_driver_presence(boolean,double precision,double precision) from public, anon;
grant execute on function public.set_driver_presence(boolean,double precision,double precision) to authenticated;

create or replace function public.update_driver_status()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  update public.drivers d
  set is_available=(
    ((new.status='completed'::public.ride_status and new.payment_status='paid'::public.ride_payment_status) or new.status='cancelled'::public.ride_status)
    and d.is_online=true and d.is_suspended=false and d.is_simulated=false
  )
  where d.id=new.driver_id
    and exists(select 1 from public.profiles p where p.id=d.id and p.account_type='driver'::public.drivo_account_type)
    and exists(select 1 from public.driver_applications da where da.user_id=d.id and da.status='approved'::public.driver_application_status);
  return new;
end;
$$;
revoke all on function public.update_driver_status() from public, anon, authenticated;

create or replace function public.passenger_mark_qr_paid(p_ride_id uuid)
returns text
language plpgsql security definer set search_path=''
as $$
declare v_user_id uuid:=auth.uid(); v_driver_id uuid;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.profiles p where p.id=v_user_id and p.account_type='passenger'::public.drivo_account_type) then raise exception 'Passenger account required'; end if;
  update public.rides
  set payment_status='paid'::public.ride_payment_status
  where id=p_ride_id and passenger_id=v_user_id and payment_method='qr'::public.ride_payment_method and status='completed'::public.ride_status
  returning driver_id into v_driver_id;
  if v_driver_id is null then raise exception 'Completed QR ride not found'; end if;
  update public.drivers d
  set is_available=(d.is_online and not d.is_suspended and not d.is_simulated)
  where d.id=v_driver_id
    and exists(select 1 from public.driver_applications da where da.user_id=d.id and da.status='approved'::public.driver_application_status)
    and not exists(select 1 from public.rides r where r.driver_id=d.id and r.status::text not in('completed','cancelled'))
    and not exists(select 1 from public.rides r where r.driver_id=d.id and r.status='completed'::public.ride_status and r.payment_status='pending'::public.ride_payment_status)
    and not exists(select 1 from public.ride_requests rr where rr.offered_driver_id=d.id and rr.status='offered'::public.ride_request_status);
  return 'paid';
end;
$$;
revoke all on function public.passenger_mark_qr_paid(uuid) from public, anon;
grant execute on function public.passenger_mark_qr_paid(uuid) to authenticated;
