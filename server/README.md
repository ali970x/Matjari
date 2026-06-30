# Matjari Backend

Offline Node.js + Express API for the Matjari app store. By default it uses a local JSON file under `server/data/database.json`, and it can switch to Supabase for durable production data and file uploads.

## Run locally

```bash
cd server
npm install
cp .env.example .env
npm run dev
```

Default admin login:

```json
{
  "username": "admin",
  "password": "123456"
}
```

Health check:

```bash
GET http://localhost:4000/health
```

Admin upload console:

```bash
GET http://localhost:4000/admin
```

The console supports admin login, app creation, editing existing apps, deleting apps, uploading APK/icon/screenshot files, and publishing version updates.

## Postman flow

1. `POST /api/auth/admin-login` with the default admin body above. Save the returned token as `Bearer {{token}}`.
2. `GET /api/categories` to read seeded Apps, Games, and Books categories.
3. `GET /api/apps?platform=android` to list active Android apps.
4. `POST /api/apps` with the admin token to create an app.
5. `POST /api/uploads/icon`, `POST /api/uploads/app-file`, or `POST /api/uploads/screenshots` as multipart form data with the admin token.
6. Save the returned APK/file URL in the app `file_url` field so Android clients can open the direct download link. After installation, Matjari detects the Android package by `package_name`.
7. `POST /api/apps/:id/update` to publish a new version and set `is_force_update`.
8. `GET /api/apps/:id/check-update?currentBuild=1` to test update availability.
9. `GET /api/apps/package/:packageName/check-update?platform=android&currentBuild=1` to test update checks by Android package name.
10. `POST /api/auth/register`, then `POST /api/downloads`, `POST /api/library/me`, and `POST /api/reviews` with the user token.

## Main endpoints

- `GET /admin`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/admin-login`
- `GET /api/auth/me`
- `GET /api/apps`
- `GET /api/apps/:id`
- `POST /api/apps`
- `PUT /api/apps/:id`
- `DELETE /api/apps/:id`
- `POST /api/uploads/app-file`
- `POST /api/uploads/icon`
- `POST /api/uploads/screenshots`
- `POST /api/downloads`
- `GET /api/downloads/app/:appId`
- `GET /api/downloads/user/:userId`
- `GET /api/library/me`
- `POST /api/library/me`
- `POST /api/library/me/:appId/open`
- `DELETE /api/library/me/:appId`
- `POST /api/reviews`
- `GET /api/reviews/app/:appId`
- `POST /api/apps/:id/update`
- `GET /api/apps/:id/check-update`
- `GET /api/apps/package/:packageName/check-update`
- `GET /api/categories`
- `POST /api/categories`
- `GET /api/subcategories/:categoryId`

## Durable Supabase mode

The server can keep the same API while storing the full app state in Supabase. Create this table in the Supabase SQL editor:

```sql
create table if not exists public.matjari_state (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
```

Then set these Render environment variables:

```text
DATA_BACKEND=supabase
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
SUPABASE_STATE_TABLE=matjari_state
SUPABASE_STATE_ID=default
```

Use the base project URL for `SUPABASE_URL`, without `/rest/v1`.

To store uploaded APKs, icons, and screenshots in Supabase Storage, create a public bucket and add:

```text
UPLOAD_BACKEND=supabase
SUPABASE_STORAGE_BUCKET=matjari-uploads
SUPABASE_STORAGE_PREFIX=uploads
```

Keep `SUPABASE_SERVICE_ROLE_KEY` only on the backend. Do not put it in Flutter or commit it to Git.

## Render

The root `render.yaml` creates a Node web service from the `server` folder:

- Build command: `npm install`
- Start command: `node server.js`
- Health check: `/health`

Set `ADMIN_PASSWORD` in Render before the first deploy. Render storage is ephemeral on free services, so the JSON database is good for demos; production should move `users`, `apps`, `user_apps`, `downloads`, and `reviews` to PostgreSQL/Supabase.

Current deployed API:

```text
https://matjari-api.onrender.com
```
