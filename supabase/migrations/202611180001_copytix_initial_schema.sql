-- Copytix initial cloud schema
-- Source of truth: Project Charter + Diagram Copytix (ERD/LRS).
-- Target: Supabase PostgreSQL. This migration is intentionally separate from
-- the existing Drift scaffold; it does not drop or alter local SQLite tables.

begin;

-- Private helper functions are kept outside the schemas exposed by Supabase's
-- Data API. Do not add `private` to the exposed schemas list in Supabase.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------------
-- 1. Tables (matching the ERD/LRS entities and attributes)
-- ---------------------------------------------------------------------------

create table public.pengguna (
  id_pengguna uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  nama text not null,
  role text not null default 'kasir'
    check (role in ('admin_pemilik', 'kasir')),
  aktif boolean not null default true,
  constraint pengguna_nama_not_blank check (length(btrim(nama)) > 0)
);

create unique index pengguna_email_lower_uidx
  on public.pengguna (lower(email));

create table public.layanan (
  id_layanan uuid primary key default gen_random_uuid(),
  nama_layanan text not null,
  satuan text not null,
  harga numeric(14, 2) not null default 0 check (harga >= 0),
  aktif boolean not null default true,
  constraint layanan_nama_not_blank check (length(btrim(nama_layanan)) > 0),
  constraint layanan_satuan_not_blank check (length(btrim(satuan)) > 0)
);

create table public.barang (
  id_barang uuid primary key default gen_random_uuid(),
  nama_barang text not null,
  satuan text not null,
  stok integer not null default 0 check (stok >= 0),
  stok_minimum integer not null default 0 check (stok_minimum >= 0),
  constraint barang_nama_not_blank check (length(btrim(nama_barang)) > 0),
  constraint barang_satuan_not_blank check (length(btrim(satuan)) > 0)
);

create table public.layanan_barang (
  id_layanan uuid not null references public.layanan (id_layanan) on delete restrict,
  id_barang uuid not null references public.barang (id_barang) on delete restrict,
  jumlah_per_layanan numeric(14, 3) not null check (jumlah_per_layanan > 0),
  primary key (id_layanan, id_barang)
);

create table public.transaksi (
  id_transaksi uuid primary key default gen_random_uuid(),
  kode_transaksi text not null unique,
  id_pengguna uuid not null references public.pengguna (id_pengguna) on delete restrict,
  tanggal timestamptz not null default now(),
  total numeric(14, 2) not null default 0 check (total >= 0),
  status_pesanan text not null default 'diproses'
    check (status_pesanan in ('diproses', 'selesai', 'diambil', 'dibatalkan')),
  catatan text,
  constraint transaksi_kode_not_blank check (length(btrim(kode_transaksi)) > 0)
);

create table public.detail_transaksi (
  id_detail uuid primary key default gen_random_uuid(),
  id_transaksi uuid not null references public.transaksi (id_transaksi) on delete restrict,
  id_layanan uuid not null references public.layanan (id_layanan) on delete restrict,
  jumlah integer not null check (jumlah > 0),
  harga_satuan numeric(14, 2) not null check (harga_satuan >= 0),
  subtotal numeric(14, 2) not null check (subtotal >= 0)
);

create table public.pembayaran (
  id_pembayaran uuid primary key default gen_random_uuid(),
  id_transaksi uuid not null references public.transaksi (id_transaksi) on delete restrict,
  id_pengguna uuid not null references public.pengguna (id_pengguna) on delete restrict,
  tanggal timestamptz not null default now(),
  metode text not null check (metode in ('tunai', 'non_tunai')),
  nominal numeric(14, 2) not null check (nominal > 0),
  uang_diterima numeric(14, 2) not null default 0 check (uang_diterima >= 0),
  kembalian numeric(14, 2) not null default 0 check (kembalian >= 0),
  constraint pembayaran_tunai_cukup check (
    metode <> 'tunai' or uang_diterima >= nominal
  ),
  constraint pembayaran_kembalian_tunai check (
    metode <> 'tunai' or kembalian = uang_diterima - nominal
  ),
  constraint pembayaran_non_tunai_tanpa_kembalian check (
    metode <> 'non_tunai' or kembalian = 0
  )
);

create table public.mutasi_stok (
  id_mutasi uuid primary key default gen_random_uuid(),
  id_barang uuid not null references public.barang (id_barang) on delete restrict,
  id_transaksi uuid references public.transaksi (id_transaksi) on delete restrict,
  id_detail uuid references public.detail_transaksi (id_detail) on delete restrict,
  id_pengguna uuid not null references public.pengguna (id_pengguna) on delete restrict,
  tanggal timestamptz not null default now(),
  jenis text not null
    check (jenis in ('masuk', 'keluar', 'penyesuaian', 'pembatalan')),
  jumlah integer not null check (jumlah > 0),
  keterangan text
);

create table public.log_aktivitas (
  id_log uuid primary key default gen_random_uuid(),
  id_pengguna uuid not null references public.pengguna (id_pengguna) on delete restrict,
  waktu timestamptz not null default now(),
  aksi text not null,
  nama_tabel text not null,
  id_data uuid,
  detail jsonb not null default '{}'::jsonb
);

-- Indexes for common joins and report filters.
create index transaksi_pengguna_tanggal_idx
  on public.transaksi (id_pengguna, tanggal desc);
create index transaksi_tanggal_idx
  on public.transaksi (tanggal desc);
create index transaksi_status_idx
  on public.transaksi (status_pesanan);
create index detail_transaksi_transaksi_idx
  on public.detail_transaksi (id_transaksi);
create index detail_transaksi_layanan_idx
  on public.detail_transaksi (id_layanan);
create index pembayaran_transaksi_idx
  on public.pembayaran (id_transaksi);
create index mutasi_stok_barang_tanggal_idx
  on public.mutasi_stok (id_barang, tanggal desc);
create index mutasi_stok_transaksi_idx
  on public.mutasi_stok (id_transaksi);
create index log_aktivitas_pengguna_waktu_idx
  on public.log_aktivitas (id_pengguna, waktu desc);

-- ---------------------------------------------------------------------------
-- 2. Auth profile creation
-- New Auth users are always provisioned as `kasir`. The role supplied through
-- user-editable metadata is deliberately ignored. Promote the first owner
-- manually in the Supabase SQL editor after creating their Auth account.
-- ---------------------------------------------------------------------------

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := nullif(btrim(new.raw_user_meta_data ->> 'nama'), '');
  if v_name is null then
    v_name := nullif(split_part(coalesce(new.email, ''), '@', 1), '');
  end if;

  if new.email is null or length(btrim(new.email)) = 0 then
    raise exception 'Copytix requires an email address for every user';
  end if;

  insert into public.pengguna (id_pengguna, email, nama, role, aktif)
  values (
    new.id,
    lower(btrim(new.email)),
    coalesce(v_name, 'Pengguna'),
    'kasir',
    true
  )
  on conflict (id_pengguna) do update
    set email = excluded.email;

  return new;
end;
$$;

revoke all on function private.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_copytix on auth.users;
create trigger on_auth_user_created_copytix
after insert or update of email on auth.users
for each row execute function private.handle_new_auth_user();

-- ---------------------------------------------------------------------------
-- 3. Narrow authorization helpers for RLS
-- These SECURITY DEFINER helpers live in the non-exposed `private` schema,
-- use a fixed empty search_path, and derive authorization from public.pengguna
-- (not from user-editable Auth metadata).
-- ---------------------------------------------------------------------------

create or replace function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.pengguna p
    where p.id_pengguna = (select auth.uid())
      and p.aktif = true
  );
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.pengguna p
    where p.id_pengguna = (select auth.uid())
      and p.aktif = true
      and p.role = 'admin_pemilik'
  );
$$;

create or replace function private.can_access_transaction(p_transaction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_active_user()) and exists (
    select 1
    from public.transaksi t
    where t.id_transaksi = p_transaction_id
      and (
        t.id_pengguna = (select auth.uid())
        or (select private.is_admin())
      )
  );
$$;

create or replace function private.can_edit_transaction(p_transaction_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.is_active_user()) and exists (
    select 1
    from public.transaksi t
    where t.id_transaksi = p_transaction_id
      and t.status_pesanan = 'diproses'
      and (
        t.id_pengguna = (select auth.uid())
        or (select private.is_admin())
      )
  );
$$;

revoke all on function private.is_active_user() from public, anon;
revoke all on function private.is_admin() from public, anon;
revoke all on function private.can_access_transaction(uuid) from public, anon;
revoke all on function private.can_edit_transaction(uuid) from public, anon;
grant execute on function private.is_active_user() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.can_access_transaction(uuid) to authenticated;
grant execute on function private.can_edit_transaction(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Activity audit trigger
-- Authenticated row changes are recorded for the entities represented in the
-- LRS. System-level operations without an Auth user are not attributed to a
-- fabricated user and therefore are not inserted into log_aktivitas.
-- ---------------------------------------------------------------------------

create or replace function private.write_activity_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_row jsonb;
  v_detail jsonb;
  v_primary_key text;
  v_data_id uuid;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    if tg_op = 'DELETE' then return old; else return new; end if;
  end if;

  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
    v_detail := jsonb_build_object('old', to_jsonb(old));
  elsif tg_op = 'UPDATE' then
    v_row := to_jsonb(new);
    v_detail := jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new));
  else
    v_row := to_jsonb(new);
    v_detail := jsonb_build_object('new', to_jsonb(new));
  end if;

  v_primary_key := case tg_table_name
    when 'pengguna' then 'id_pengguna'
    when 'layanan' then 'id_layanan'
    when 'barang' then 'id_barang'
    when 'transaksi' then 'id_transaksi'
    when 'detail_transaksi' then 'id_detail'
    when 'pembayaran' then 'id_pembayaran'
    when 'mutasi_stok' then 'id_mutasi'
    else null
  end;

  if v_primary_key is not null then
    v_data_id := nullif(v_row ->> v_primary_key, '')::uuid;
  else
    v_data_id := null;
  end if;

  insert into public.log_aktivitas (
    id_pengguna, waktu, aksi, nama_tabel, id_data, detail
  ) values (
    v_user_id, now(), tg_op, tg_table_name, v_data_id, v_detail
  );

  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

revoke all on function private.write_activity_log() from public, anon, authenticated;

create trigger audit_pengguna
after insert or update or delete on public.pengguna
for each row execute function private.write_activity_log();
create trigger audit_layanan
after insert or update or delete on public.layanan
for each row execute function private.write_activity_log();
create trigger audit_barang
after insert or update or delete on public.barang
for each row execute function private.write_activity_log();
create trigger audit_layanan_barang
after insert or update or delete on public.layanan_barang
for each row execute function private.write_activity_log();
create trigger audit_transaksi
after insert or update or delete on public.transaksi
for each row execute function private.write_activity_log();
create trigger audit_detail_transaksi
after insert or update or delete on public.detail_transaksi
for each row execute function private.write_activity_log();
create trigger audit_pembayaran
after insert or update or delete on public.pembayaran
for each row execute function private.write_activity_log();
create trigger audit_mutasi_stok
after insert or update or delete on public.mutasi_stok
for each row execute function private.write_activity_log();

-- ---------------------------------------------------------------------------
-- 5. Row Level Security and least-privilege grants
-- ---------------------------------------------------------------------------

alter table public.pengguna enable row level security;
alter table public.layanan enable row level security;
alter table public.barang enable row level security;
alter table public.layanan_barang enable row level security;
alter table public.transaksi enable row level security;
alter table public.detail_transaksi enable row level security;
alter table public.pembayaran enable row level security;
alter table public.mutasi_stok enable row level security;
alter table public.log_aktivitas enable row level security;

-- No access is granted to unauthenticated clients.
revoke all on table
  public.pengguna,
  public.layanan,
  public.barang,
  public.layanan_barang,
  public.transaksi,
  public.detail_transaksi,
  public.pembayaran,
  public.mutasi_stok,
  public.log_aktivitas
from anon;

grant usage on schema public to authenticated;
grant select, update on public.pengguna to authenticated;
grant select, insert, update, delete on public.layanan to authenticated;
grant select, insert, update, delete on public.barang to authenticated;
grant select, insert, update, delete on public.layanan_barang to authenticated;
grant select on public.transaksi to authenticated;
grant select on public.detail_transaksi to authenticated;
grant select on public.pembayaran to authenticated;
grant select on public.mutasi_stok to authenticated;
grant select on public.log_aktivitas to authenticated;

-- User profile: users can read themselves; only Admin/Pemilik can manage profiles.
create policy pengguna_read_self_or_admin
on public.pengguna for select to authenticated
using (
  id_pengguna = (select auth.uid())
  or (select private.is_admin())
);

create policy pengguna_update_admin
on public.pengguna for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Master data: active users can read; only Admin/Pemilik can write.
create policy layanan_read_active
on public.layanan for select to authenticated
using (
  (select private.is_active_user())
  and (aktif = true or (select private.is_admin()))
);
create policy layanan_manage_admin
on public.layanan for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy barang_read_active
on public.barang for select to authenticated
using ((select private.is_active_user()));
create policy barang_manage_admin
on public.barang for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy layanan_barang_read_active
on public.layanan_barang for select to authenticated
using ((select private.is_active_user()));
create policy layanan_barang_manage_admin
on public.layanan_barang for all to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

-- Operational records are read-only through direct table access at this stage.
-- The transaction/payment/stock write path will be added as controlled database
-- functions so checkout, payment, stock deduction and cancellation stay atomic.
create policy transaksi_read_owner_or_admin
on public.transaksi for select to authenticated
using (
  (select private.is_active_user())
  and (
    id_pengguna = (select auth.uid())
    or (select private.is_admin())
  )
);

create policy detail_transaksi_read_owner_or_admin
on public.detail_transaksi for select to authenticated
using ((select private.can_access_transaction(id_transaksi)));

create policy pembayaran_read_owner_or_admin
on public.pembayaran for select to authenticated
using ((select private.can_access_transaction(id_transaksi)));

create policy mutasi_stok_read_owner_or_admin
on public.mutasi_stok for select to authenticated
using (
  (select private.is_active_user())
  and (
    id_pengguna = (select auth.uid())
    or (select private.is_admin())
  )
);

create policy log_aktivitas_read_admin
on public.log_aktivitas for select to authenticated
using ((select private.is_admin()));

comment on schema private is
  'Internal Copytix helper functions; keep this schema out of Supabase Data API exposed schemas.';
comment on table public.pengguna is
  'Copytix app users linked one-to-one with auth.users. New users default to kasir.';
comment on table public.layanan_barang is
  'Bill of materials: inventory quantity consumed per service unit.';
comment on table public.log_aktivitas is
  'Audit trail for authenticated changes to Copytix business entities.';

commit;
