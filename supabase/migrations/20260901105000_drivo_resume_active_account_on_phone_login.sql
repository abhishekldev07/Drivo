create or replace function public.portfolio_phone_login(p_phone text)
returns table(account_exists boolean, id uuid, display_name text, phone text, account_type text, profile_photo_path text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_current_id uuid := auth.uid();
  v_target_id uuid;
  v_phone text := btrim(p_phone);
  v_name text;
  v_account_type public.drivo_account_type;
  v_profile_photo_path text;
  v_driver public.drivers%rowtype;
  v_application_id uuid;
  v_driver_has_active_work boolean := false;
begin
  if v_current_id is null then raise exception 'Authentication required'; end if;
  if v_phone !~ '^[0-9]{10}$' then raise exception 'Phone number must be exactly 10 digits'; end if;

  select p.id, p.display_name, p.account_type, p.profile_photo_path
  into v_target_id, v_name, v_account_type, v_profile_photo_path
  from public.profiles p
  where p.phone = v_phone
  limit 1;

  if v_target_id is null then
    return query select false, null::uuid, null::text, v_phone, null::text, null::text;
    return;
  end if;

  if v_target_id = v_current_id then
    return query select true, v_current_id, v_name, v_phone, v_account_type::text, v_profile_photo_path;
    return;
  end if;

  if exists (select 1 from public.profiles p where p.id = v_current_id) then
    raise exception 'CURRENT_SESSION_REGISTERED_TO_ANOTHER_ACCOUNT';
  end if;

  update public.rides set passenger_id = v_current_id where passenger_id = v_target_id;
  update public.ride_requests set passenger_id = v_current_id where passenger_id = v_target_id;

  select d.* into v_driver from public.drivers d where d.id = v_target_id for update;
  if found then
    v_application_id := v_driver.application_id;
    select
      exists(select 1 from public.rides r where r.driver_id = v_target_id and r.status::text not in ('completed','cancelled'))
      or exists(select 1 from public.ride_requests rr where rr.offered_driver_id = v_target_id and rr.status = 'offered'::public.ride_request_status)
    into v_driver_has_active_work;

    update public.drivers set application_id = null where id = v_target_id;

    insert into public.drivers(
      id, model, number, is_available, location, name, rating, category_id,
      is_simulated, phone, vehicle_color, application_id, is_online,
      is_suspended, last_location_at, vehicle_make, vehicle_year, payment_qr_path
    ) values (
      v_current_id, v_driver.model, v_driver.number, false, v_driver.location,
      v_driver.name, v_driver.rating, v_driver.category_id, false, v_driver.phone,
      v_driver.vehicle_color, v_application_id,
      case when v_driver_has_active_work then v_driver.is_online else false end,
      v_driver.is_suspended, v_driver.last_location_at, v_driver.vehicle_make,
      v_driver.vehicle_year, v_driver.payment_qr_path
    );

    update public.rides set driver_id = v_current_id where driver_id = v_target_id;
    update public.ride_requests set offered_driver_id = v_current_id where offered_driver_id = v_target_id;
    update public.ride_requests
      set declined_driver_ids = array_replace(declined_driver_ids, v_target_id, v_current_id)
      where v_target_id = any(declined_driver_ids);
    delete from public.drivers where id = v_target_id;
  end if;

  update public.driver_applications set user_id = v_current_id where user_id = v_target_id;
  delete from public.profiles where id = v_target_id;

  insert into public.profiles(id, display_name, phone, account_type, profile_photo_path, created_at, updated_at)
  values(v_current_id, v_name, v_phone, v_account_type, v_profile_photo_path, now(), now());

  return query select true, v_current_id, v_name, v_phone, v_account_type::text, v_profile_photo_path;
end;
$function$;

revoke all on function public.portfolio_phone_login(text) from public, anon;
grant execute on function public.portfolio_phone_login(text) to authenticated, service_role;
