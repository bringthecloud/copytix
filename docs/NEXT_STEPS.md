# Next implementation steps

1. Wait for the Supabase project to reach `ACTIVE_HEALTHY`.
2. Inspect existing public tables and migration history before applying the SQL migration.
3. Apply the initial schema only after confirming there are no conflicting tables or prior migrations.
4. Promote the first trusted owner account to `admin_pemilik` from the SQL editor.
5. Add a secure Admin/Pemilik user-provisioning flow (Edge Function / trusted server-side Admin API); never ship service-role credentials in Flutter.
6. Implement database transaction functions for checkout, payment, stock deduction, order status changes, cancellation/restock, and receipt data. Direct client writes to these tables remain blocked in the initial migration.
7. Add product/service/stock repositories and role-aware CRUD screens.
8. Implement PDF receipts, share sheet, dashboard, reports, activity log, and backup/restore.
9. Run black-box tests for role access, calculations, payment, stock, order status, and backup/restore.
10. Build the release APK only after analysis, tests, and on-device checks pass.
