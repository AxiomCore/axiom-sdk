# axiom_flutter example

A minimal app with one query (`GET /hello/{name}`) and one mutation
(`POST /todos`). The backend contract is in `backend/main.acore`. The client in
`lib/axiom_generated/` was generated from it by `axiom pull`.

## Run it

You need the `axiom` CLI and Flutter 3.32 or later.

1. Start the backend:

   ```sh
   cd backend
   axiom check main.acore
   axiom build main.acore --out backend.axiom
   axiom server deployment backend.axiom backend.server.json --output deployment.json
   axiom run main.acore --deployment deployment.json --port 8080
   ```

2. In a second terminal, add the platform folders and run the app:

   ```sh
   flutter create --platforms=android,ios,macos,web .
   flutter run
   ```

   On Android add `<uses-permission android:name="android.permission.INTERNET"/>`
   to `android/app/src/main/AndroidManifest.xml` and allow cleartext traffic
   for local HTTP. On macOS add `com.apple.security.network.client` to both
   entitlement files. The app uses `10.0.2.2` on the Android emulator and
   `127.0.0.1` elsewhere.

3. After you change `backend/main.acore`, rebuild `backend.axiom` and
   regenerate the client:

   ```sh
   axiom pull backend/backend.axiom --framework flutter --name todos --out lib/axiom_generated
   ```

The backend allows CORS from `http://localhost:3000` and
`http://127.0.0.1:3000`. For web, run `flutter run -d chrome --web-port 3000`.
