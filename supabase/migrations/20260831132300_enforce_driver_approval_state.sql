create or replace function public.process_driver_application_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    new.updated_at := now();
    if new.status is distinct from old.status
       and new.status in ('approved'::public.driver_application_status, 'rejected'::public.driver_application_status) then
        new.reviewed_at := coalesce(new.reviewed_at, now());
    end if;

    if new.status = 'approved'::public.driver_application_status
       and old.status is distinct from new.status then
        insert into public.drivers (
            id, name, phone, model, number, vehicle_color, is_available,
            is_online, is_suspended, location, category_id, is_simulated, application_id
        ) values (
            new.user_id, btrim(new.full_name), new.phone, btrim(new.vehicle_model),
            upper(btrim(new.plate_number)), btrim(new.vehicle_color), false,
            false, false, null, new.category_id, false, new.id
        )
        on conflict (id) do update set
            name = excluded.name,
            phone = excluded.phone,
            model = excluded.model,
            number = excluded.number,
            vehicle_color = excluded.vehicle_color,
            category_id = excluded.category_id,
            application_id = excluded.application_id,
            is_simulated = false,
            is_suspended = false,
            is_online = false,
            is_available = false;
    elsif new.status <> 'approved'::public.driver_application_status
       and old.status is distinct from new.status then
        update public.drivers
        set is_suspended = true,
            is_online = false,
            is_available = false
        where id = new.user_id and is_simulated = false;
    end if;
    return new;
end;
$$;
revoke all on function public.process_driver_application_review() from public, anon, authenticated;

create or replace function public.set_driver_presence(
    p_online boolean,
    p_latitude double precision default null,
    p_longitude double precision default null
)
returns table(is_online boolean, is_available boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_driver_id uuid := auth.uid();
    v_available boolean;
begin
    if v_driver_id is null then raise exception 'Authentication required'; end if;
    if not exists (
        select 1
        from public.drivers d
        join public.driver_applications a on a.id = d.application_id
        where d.id = v_driver_id
          and d.is_simulated = false
          and d.is_suspended = false
          and a.status = 'approved'::public.driver_application_status
    ) then raise exception 'Approved driver account required'; end if;

    if p_online and (p_latitude is null or p_longitude is null
       or p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180) then
        raise exception 'Valid current location is required to go online';
    end if;

    if not p_online and exists (
        select 1 from public.rides r
        where r.driver_id = v_driver_id and r.status::text not in ('completed', 'cancelled')
    ) then raise exception 'Complete the active ride before going offline'; end if;

    if not p_online and exists (
        select 1 from public.ride_requests rr
        where rr.offered_driver_id = v_driver_id and rr.status = 'offered'::public.ride_request_status
    ) then raise exception 'Respond to the current ride request before going offline'; end if;

    v_available := p_online
        and not exists (
            select 1 from public.rides r
            where r.driver_id = v_driver_id and r.status::text not in ('completed', 'cancelled')
        )
        and not exists (
            select 1 from public.ride_requests rr
            where rr.offered_driver_id = v_driver_id and rr.status = 'offered'::public.ride_request_status
        );

    update public.drivers
    set is_online = p_online,
        is_available = v_available,
        location = case when p_online then extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography else location end,
        last_location_at = case when p_online then now() else last_location_at end
    where id = v_driver_id;

    return query select p_online, v_available;
end;
$$;
revoke all on function public.set_driver_presence(boolean, double precision, double precision) from public, anon;
grant execute on function public.set_driver_presence(boolean, double precision, double precision) to authenticated;

create or replace function public.update_driver_location(
    p_latitude double precision,
    p_longitude double precision
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_driver_id uuid := auth.uid();
begin
    if v_driver_id is null then raise exception 'Authentication required'; end if;
    if p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180 then
        raise exception 'Invalid location';
    end if;

    update public.drivers d
    set location = extensions.st_setsrid(extensions.st_makepoint(p_longitude, p_latitude), 4326)::extensions.geography,
        last_location_at = now()
    where d.id = v_driver_id
      and d.is_simulated = false
      and d.is_suspended = false
      and d.is_online = true
      and exists (
          select 1 from public.driver_applications a
          where a.id = d.application_id
            and a.status = 'approved'::public.driver_application_status
      );
    return found;
end;
$$;
revoke all on function public.update_driver_location(double precision, double precision) from public, anon;
grant execute on function public.update_driver_location(double precision, double precision) to authenticated;
