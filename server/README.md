# Matjari Backend

Offline Node.js + Express API for the Matjari app store. The current backend uses a local JSON file under `server/data/database.json` so it can run before Supabase credentials are available.

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

## Postman flow

1. `POST /api/auth/admin-login` with the default admin body above. Save the returned token as `Bearer {{token}}`.
2. `GET /api/categories` to read seeded Apps, Games, and Books categories.
3. `GET /api/apps?platform=android` to list active Android apps.
4. `POST /api/apps` with the admin token to create an app.
5. `POST /api/uploads/icon`, `POST /api/uploads/app-file`, or `POST /api/uploads/screenshots` as multipart form data with the admin token.
6. `POST /api/apps/:id/update` to publish a new version and set `is_force_update`.
7. `GET /api/apps/:id/check-update?currentBuild=1` to test update availability.
8. `GET /api/apps/package/:packageName/check-update?platform=android&currentBuild=1` to test update checks by Android package name.
9. `POST /api/auth/register`, then `POST /api/downloads`, `POST /api/library/me`, and `POST /api/reviews` with the user token.

## Main endpoints

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

## Supabase later

When the offline server is approved, replace the JSON store in `src/services/store.js` with Supabase PostgreSQL queries and point upload responses at Supabase Storage buckets.

## Render

The root `render.yaml` creates a Node web service from the `server` folder:

- Build command: `npm install`
- Start command: `node server.js`
- Health check: `/health`

Set `ADMIN_PASSWORD` in Render before the first deploy. Render storage is ephemeral on free services, so the JSON database is good for demos; production should move `users`, `apps`, `user_apps`, `downloads`, and `reviews` to PostgreSQL/Supabase.
