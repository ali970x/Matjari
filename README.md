# Matjari

Matjari is an English Flutter app store experience with a local Express backend.

The Flutter app uses English UI copy and launcher metadata. The current backend is offline-first and stores data in a local JSON file until Supabase credentials are added later.

## Flutter

```bash
flutter pub get
flutter run
```

For Chrome on the same computer:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

The app defaults to the deployed Render API when no `API_BASE_URL` is passed:

```text
https://matjari-api.onrender.com
```

For an Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

For a real Android phone on the same Wi-Fi, replace `YOUR_PC_IP` with the computer IP:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:4000
```

Build a release APK for direct testing:

```bash
flutter build apk --release
```

For Google Play, create a private `android/key.properties` from `android/key.properties.example` and keep the matching `.jks` file local. The project falls back to debug signing when the private release key is not present, so local demo builds still work.

## Backend

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

Admin features currently available in the Flutter app:

- Login as admin
- Add and edit apps
- Save icon URL, APK/file URL, and screenshot URLs
- Release app updates with optional force update
- Delete apps
- View downloads analytics

User features currently available:

- Register and login
- Download, update, open, and uninstall apps
- Sync installed apps to the backend user library
- Submit and read app reviews

## Render deploy

The repo includes `render.yaml` for the backend service. After pushing to GitHub:

1. Create a Render Blueprint from the repo.
2. Set `ADMIN_PASSWORD` in Render environment variables.
3. Deploy the `matjari-api` service.
4. Use the Render service URL as `API_BASE_URL` when building Flutter.

Current deployed API:

```text
https://matjari-api.onrender.com
```
