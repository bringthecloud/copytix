# Copytix database alignment

## Source of truth

This implementation follows the revised Copytix Project Charter and the supplied ERD/LRS. The project scope is Android + Flutter + Supabase Auth/PostgreSQL with Admin/Pemilik and Kasir roles. The charter excludes full offline mode. SQLite/Drift is therefore treated as an existing local scaffold, not the operational source of truth.

## Cloud entities from the ERD/LRS

| ERD/LRS entity | Purpose | Key relationships |
|---|---|---|
| `pengguna` | Auth-linked app users and roles | One-to-one with `auth.users`; referenced by transactions, payments, stock movements and activity logs |
| `layanan` | Sellable services | Referenced by transaction details and `layanan_barang` |
| `barang` | Inventory items | Referenced by `layanan_barang` and stock movements |
| `layanan_barang` | Inventory recipe/consumption per service unit | Composite key: `id_layanan`, `id_barang` |
| `transaksi` | Transaction header and order status | Has one or more detail lines and payments |
| `detail_transaksi` | Service lines sold in a transaction | References one transaction and one service |
| `pembayaran` | Manual cash/non-cash payment records | References transaction and the user who recorded payment |
| `mutasi_stok` | Stock movement history | References item, user, and optionally transaction/detail |
| `log_aktivitas` | User activity audit trail | References the user responsible for the action |

## Existing Drift scaffold vs cloud ERD/LRS

The current Flutter repository contains seven Drift tables: `SyncQueue`, `Products`, `ServiceTypes`, `Customers`, `Sales`, `SaleItems`, and `InventoryMovements`. They are not a one-to-one match for the nine ERD/LRS entities.

| Existing Drift table | Closest ERD/LRS entity | Notes |
|---|---|---|
| `Products` | `barang` | Field names and types differ; ERD/LRS is authoritative for the cloud schema. |
| `ServiceTypes` | `layanan` | Similar concept, but column names differ. |
| `Sales` | `transaksi` | Existing local table includes fields such as `customerId` not shown in the ERD/LRS. |
| `SaleItems` | `detail_transaksi` | Existing local table can reference either product or service; ERD/LRS detail references a service. |
| `InventoryMovements` | `mutasi_stok` | Related concept; columns differ. |
| `Customers` | No direct entity in the supplied ERD/LRS | Customer is listed as a recipient/stakeholder, not as an application user. Do not add a cloud customer table until the requirements/diagram are revised. |
| `SyncQueue` | No ERD/LRS entity | Not part of the current charter's full-offline scope; do not build offline-first sync around it. |

No existing Drift table is dropped or modified by the initial cloud migration. This avoids destructive changes while the Flutter data layer is being moved to Supabase.

## Important implementation boundary

The initial migration creates the nine tables, role helpers, profile provisioning, RLS, master-data CRUD policies, and activity audit triggers. Transaction, detail, payment, and stock writes are deliberately read-only through direct table access in this first stage. They must be implemented through controlled database functions in the next stage so that checkout, payment, inventory deduction, and cancellation/restock happen atomically and cannot be bypassed by direct client writes.

## Auth provisioning

- Every Auth user receives a row in `public.pengguna` through a database trigger.
- Newly created users are always assigned `kasir`; the trigger ignores user-editable metadata for authorization.
- Create the first owner account in Supabase Auth, then promote that account using the SQL editor:

```sql
update public.pengguna
set role = 'admin_pemilik'
where email = lower('OWNER_EMAIL_YANG_DIPAKAI');
```

- User creation/deletion from the app must use a trusted server-side Edge Function or another server-only Admin API path. Never embed a Supabase service-role/secret key in Flutter.
- Deactivate users using `aktif = false` rather than deleting users with transaction/audit history.

## RLS test checklist

Use two test accounts: one `admin_pemilik`, one `kasir`.

- Unauthenticated/anon requests cannot read any Copytix table.
- Kasir can read their own profile, active services, items, and service-item recipes.
- Kasir cannot read another user's transaction, payment, stock-movement or activity-log records.
- Kasir cannot create/update/delete master data.
- Admin/Pemilik can manage services, inventory items, service-item recipes, and user profiles.
- Only Admin/Pemilik can read activity logs.
- Transaction/payment/stock writes remain blocked until the controlled transaction functions are implemented and tested.

## Deployment status

The Supabase project named `copytix` was discoverable but returned status `INACTIVE` at the time this migration was prepared. Do not apply the migration until the project is restored and its current tables/migrations have been checked. This migration is a reviewed starting point, not proof that it has been applied.
