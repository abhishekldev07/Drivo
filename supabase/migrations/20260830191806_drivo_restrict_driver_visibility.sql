drop policy if exists "Authenticated users can view drivers" on public.drivers;

create policy "Users can view drivers for active rides"
on public.drivers
for select
to authenticated
using (
    id = (select auth.uid())
    or exists (
        select 1
        from public.rides as r
        where r.driver_id = drivers.id
          and (r.passenger_id = (select auth.uid()) or r.driver_id = (select auth.uid()))
          and r.status::text not in ('completed', 'cancelled')
    )
);
