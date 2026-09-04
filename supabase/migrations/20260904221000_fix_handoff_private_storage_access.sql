-- Keep private Driver assets readable after Drivo's portfolio phone-account
-- handoff changes the auth UUID. Authorization follows the database path
-- references rather than assuming the current UUID is the original upload
-- folder name.

drop policy if exists "Driver and ride passenger can read payment QR"
on storage.objects;

create policy "Driver and ride passenger can read payment QR"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'driver-payment-assets'
  and (
    exists (
      select 1
      from public.drivers d
      where d.id = (select auth.uid())
        and d.payment_qr_path = storage.objects.name
    )
    or exists (
      select 1
      from public.rides r
      where r.passenger_id = (select auth.uid())
        and r.driver_payment_qr_path = storage.objects.name
    )
  )
);

drop policy if exists "Drivers can read their own application documents"
on storage.objects;

create policy "Drivers can read their own application documents"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'driver-documents'
  and exists (
    select 1
    from public.driver_applications da
    where da.user_id = (select auth.uid())
      and storage.objects.name = any(
        array[
          da.profile_photo_path,
          da.license_photo_path,
          da.license_back_photo_path,
          da.registration_photo_path,
          da.registration_back_photo_path,
          da.insurance_photo_path,
          da.vehicle_front_photo_path,
          da.vehicle_rear_photo_path,
          da.vehicle_side_photo_path
        ]::text[]
      )
  )
);
