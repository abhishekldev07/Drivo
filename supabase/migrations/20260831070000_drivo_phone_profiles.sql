alter table public.profiles
    add column if not exists phone text;

alter table public.profiles
    drop constraint if exists profiles_phone_required,
    drop constraint if exists profiles_phone_10_digits;

alter table public.profiles
    add constraint profiles_phone_required
        check (phone is not null) not valid,
    add constraint profiles_phone_10_digits
        check (phone ~ '^[0-9]{10}$') not valid;

alter table public.profiles
    drop column if exists email;
