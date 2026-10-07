# Malik Enterprises

Flutter client for the Malik Enterprises catalytic-converter reference catalog.
The home dashboard displays live platinum, palladium, and rhodium prices in
Indian rupees per kilogram and US dollars per troy ounce.

## Run locally

```sh
flutter pub get
flutter run
```

By default the app connects to `http://10.0.2.2:8000`, which is the Android
emulator's host-machine loopback address. Start the API there for local Android
development.

## Market data cache

The dashboard checks on-device storage before calling the API. Live INR and
USD quotes are reused for ten minutes; chart history is reused for thirty
minutes per unit and selected period. Pull down on the dashboard to bypass the
cache and fetch the latest values immediately.

## Build configuration

Release builds must use an HTTPS API endpoint. Supply it through a compile-time
environment value instead of committing a production host to source control:

```sh
flutter build appbundle \
  --dart-define=API_BASE_URL=https://api.example.com
```

Before releasing, run:

```sh
flutter analyze
flutter test
```

### Android signing

The repository deliberately does not use debug signing for release builds.
Before publishing, replace `com.example.malik` in
`android/app/build.gradle.kts` with an application ID registered to your
organization, then create `android/key.properties` (this file is ignored by
Git):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=C:\\path\\to\\upload-keystore.jks
```

Generate a signed Android App Bundle with:

```sh
flutter build appbundle \
  --dart-define=API_BASE_URL=https://api.example.com
```
