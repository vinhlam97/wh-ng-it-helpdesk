-- =====================================================================
-- Schema cho dashboard "Quản lý sửa chữa thiết bị"
-- Chạy 1 lần trong Supabase: SQL Editor -> New query -> dán toàn bộ -> Run
-- =====================================================================

-- 1) Hồ sơ người dùng + phân quyền ------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  role       text not null default 'editor' check (role in ('viewer','editor','admin')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- Lấy quyền của người đang đăng nhập (security definer để không vướng RLS)
create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Tự tạo profile khi có user mới. User ĐẦU TIÊN = admin, các user sau = editor.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, role)
  values (new.id, new.email,
          case when (select count(*) from public.profiles) = 0 then 'admin' else 'editor' end);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select to authenticated
  using (id = auth.uid() or public.my_role() = 'admin');
drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles for update to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

-- 2) Trigger cập nhật thời gian/người sửa -----------------------------
create or replace function public.touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

-- 3) 4 bảng dữ liệu (mỗi dòng = 1 JSON, thêm trường mới không cần sửa DB) --
do $$
declare t text;
begin
  foreach t in array array['groups','stocks','skus','devices'] loop
    execute format($f$
      create table if not exists public.%I (
        id         text primary key,
        data       jsonb not null default '{}'::jsonb,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now(),
        updated_by uuid default auth.uid()
      )$f$, t);
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists "read" on public.%I', t);
    execute format('create policy "read" on public.%I for select to authenticated using (true)', t);

    execute format('drop policy if exists "ins" on public.%I', t);
    execute format($f$create policy "ins" on public.%I for insert to authenticated
      with check (public.my_role() in ('editor','admin'))$f$, t);

    execute format('drop policy if exists "upd" on public.%I', t);
    execute format($f$create policy "upd" on public.%I for update to authenticated
      using (public.my_role() in ('editor','admin'))
      with check (public.my_role() in ('editor','admin'))$f$, t);

    execute format('drop policy if exists "del" on public.%I', t);
    execute format($f$create policy "del" on public.%I for delete to authenticated
      using (public.my_role() in ('editor','admin'))$f$, t);

    execute format('drop trigger if exists touch_%1$s on public.%1$I', t);
    execute format('create trigger touch_%1$s before update on public.%1$I for each row execute function public.touch()', t);
  end loop;
end $$;

-- 4) Quyền truy cập: chỉ người đã đăng nhập, khách (anon) không đọc được gì ----
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.groups, public.stocks, public.skus, public.devices to authenticated;
grant select, update on public.profiles to authenticated;
revoke all on public.groups, public.stocks, public.skus, public.devices, public.profiles from anon;

-- 5) Realtime: mọi người thấy thay đổi của nhau ngay lập tức -------------
do $$
declare t text;
begin
  foreach t in array array['groups','stocks','skus','devices'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- 6) Kho lưu hình ảnh thiết bị (private, chỉ người đăng nhập xem) --------
insert into storage.buckets (id, name, public) values ('device-images', 'device-images', false)
on conflict (id) do nothing;

drop policy if exists "img_read" on storage.objects;
create policy "img_read" on storage.objects for select to authenticated
  using (bucket_id = 'device-images');
drop policy if exists "img_insert" on storage.objects;
create policy "img_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'device-images' and public.my_role() in ('editor','admin'));
drop policy if exists "img_delete" on storage.objects;
create policy "img_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'device-images' and public.my_role() in ('editor','admin'));
