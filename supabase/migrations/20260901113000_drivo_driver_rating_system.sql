alter table public.drivers
  add column if not exists rating_count integer not null default 0;

alter table public.rides
  add column if not exists driver_rating smallint,
  add column if not exists driver_rating_comment text,
  add column if not exists rated_at timestamptz;

alter table public.rides
  drop constraint if exists rides_driver_rating_check,
  drop constraint if exists rides_driver_rating_comment_check;

alter table public.rides
  add constraint rides_driver_rating_check
    check (driver_rating is null or driver_rating between 1 and 5),
  add constraint rides_driver_rating_comment_check
    check (driver_rating_comment is null or char_length(driver_rating_comment) <= 300);

create index if not exists rides_driver_rating_rollup_idx
  on public.rides(driver_id, driver_rating)
  where driver_rating is not null;

create or replace function private.refresh_driver_rating(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_average numeric;
  v_count integer;
begin
  if p_driver_id is null then return; end if;

  select round(avg(r.driver_rating)::numeric, 2), count(*)::integer
  into v_average, v_count
  from public.rides r
  where r.driver_id = p_driver_id
    and r.status = 'completed'::public.ride_status
    and r.driver_rating is not null;

  update public.drivers d
  set rating = coalesce(v_average, 5.0),
      rating_count = coalesce(v_count, 0)
  where d.id = p_driver_id;
end;
$$;

revoke all on function private.refresh_driver_rating(uuid) from public, anon, authenticated;

create or replace function private.rollup_driver_rating_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform private.refresh_driver_rating(old.driver_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.driver_id is distinct from new.driver_id then
    perform private.refresh_driver_rating(old.driver_id);
  end if;

  perform private.refresh_driver_rating(new.driver_id);
  return new;
end;
$$;

revoke all on function private.rollup_driver_rating_trigger() from public, anon, authenticated;

drop trigger if exists rides_driver_rating_rollup on public.rides;
create trigger rides_driver_rating_rollup
after insert or update or delete on public.rides
for each row execute function private.rollup_driver_rating_trigger();

create or replace function public.submit_driver_rating(
  p_ride_id uuid,
  p_rating integer,
  p_comment text default null
)
returns table(
  submitted_rating integer,
  new_driver_rating numeric,
  new_rating_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_driver_id uuid;
  v_comment text;
  v_driver_rating numeric;
  v_rating_count integer;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = v_user_id
      and p.account_type = 'passenger'::public.drivo_account_type
  ) then
    raise exception 'PASSENGER_ACCOUNT_REQUIRED';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'INVALID_DRIVER_RATING';
  end if;

  v_comment := nullif(btrim(coalesce(p_comment, '')), '');
  if v_comment is not null and char_length(v_comment) > 300 then
    raise exception 'RATING_COMMENT_TOO_LONG';
  end if;

  select r.driver_id
  into v_driver_id
  from public.rides r
  where r.id = p_ride_id
    and r.passenger_id = v_user_id
    and r.status = 'completed'::public.ride_status
    and r.payment_status = 'paid'::public.ride_payment_status
  for update;

  if v_driver_id is null then raise exception 'RIDE_NOT_READY_FOR_RATING'; end if;

  if exists (
    select 1 from public.rides r
    where r.id = p_ride_id and r.driver_rating is not null
  ) then
    raise exception 'RIDE_ALREADY_RATED';
  end if;

  update public.rides
  set driver_rating = p_rating::smallint,
      driver_rating_comment = v_comment,
      rated_at = now()
  where id = p_ride_id;

  select d.rating, d.rating_count
  into v_driver_rating, v_rating_count
  from public.drivers d
  where d.id = v_driver_id;

  return query select p_rating, v_driver_rating, coalesce(v_rating_count, 0);
end;
$$;

revoke execute on function public.submit_driver_rating(uuid, integer, text) from public, anon;
grant execute on function public.submit_driver_rating(uuid, integer, text) to authenticated, service_role;

-- Keep aggregates correct if this migration is replayed over existing rating data.
do $$
declare
  v_driver_id uuid;
begin
  for v_driver_id in
    select distinct r.driver_id
    from public.rides r
    where r.driver_rating is not null
  loop
    perform private.refresh_driver_rating(v_driver_id);
  end loop;
end;
$$;
