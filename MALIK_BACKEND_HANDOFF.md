# MALIK_BACKEND_HANDOFF

**Audit date:** 2026-10-11  
**Scope:** Flutter frontend and unauthenticated production API evidence only. No backend source or authenticated user session was available.

## Findings and root cause

- **Confirmed frontend defect affecting Brands:** Swagger declares `GET /api/v1/brands` as HTTP Bearer protected, but `BrandService.getConverterBrands()` previously used bare Dio and sent no Firebase ID token. The live unauthenticated request returned `401 {"detail":"Not authenticated"}`. This could prevent the Brands screen and the catalogue's brand filters from loading. **Fixed in this audit:** this request now uses `AuthenticatedApiClient` and the existing Firebase bearer-token flow.
- **Catalogue access for an approved normal user remains undetermined.** `GET /api/v1/converters` and the detail route use `AuthenticatedApiClient`, which retrieves the current Firebase user's ID token and sends it using the Bearer scheme. The Flutter UI does not hide the catalogue based on role; `isAdmin` controls only the catalogue add action. The anonymous live `401` does not establish how the backend treats an authenticated `user` role.
- The frontend's previous `403` copy assumed an admin policy without evidence. It now reports denial neutrally and asks for the account status/access policy to be checked.
- **No backend authorization change is claimed.** Only the Brands request transport and related denial messaging changed.

## Request traces in the frontend

| Flow | Screen/controller → service → API client → parsing/UI |
|---|---|
| Brands | [`BrandsScreen._loadBrands()`](lib/screens/brands_screen.dart) → [`BrandService.getConverterBrands()`](lib/services/brand_service.dart) → [`AuthenticatedApiClient.get()` and `createAuthorizedOptions()`](lib/services/authenticated_api_client.dart) → `_parseBrands()` → `CarBrand.fromJson()` → brand grid. A brand tap is handled by `HomeScreen` and passes its ID to `CatalogScreen`. |
| Catalogue/search | [`CatalogScreen.initState()`, `_loadFirstPage()`, `_loadNextPage()`, `_onSearchChanged()`](lib/screens/catalog_screen.dart) → [`ConverterService.getConverters()`](lib/services/converter_service.dart) → authenticated client → `ConverterCatalogPage.fromJson()` / `ConverterRecord.fromJson()` → catalogue slivers. `SearchScreen.build()` reuses `CatalogScreen`. |
| Converter detail | `CatalogScreen._openDetails()` → `ConverterDetailScreen._loadConverter()` → `ConverterService.getConverter(id)` → authenticated client → `ConverterRecord.fromJson()` → detail UI. The ID comes from a catalogue record; no per-card detail prefetch occurs. |
| Sign-in/session | `main()` awaits `Firebase.initializeApp()`. `LoginScreen._checkExistingSession()` uses `FirebaseAuth.currentUser`; `_login()` signs in; `_checkBackendAccount()` obtains an ID token, calls `/api/v1/auth/me`, and opens Home only for an approved, active account. `AppUser.isAdmin` is used for admin-only controls. |
| Sign-out | `AdminProfileScreen._signOut()` calls `FirebaseAuth.instance.signOut()` and navigates to Login. Pending, rejected, and inactive accounts are also signed out during account verification. There is no app-wide auth-state stream listener; Home receives the verified `AppUser` at navigation time. |

Relevant implementation files:

- API base URL: [`lib/config/api_config.dart`](lib/config/api_config.dart)
- Paths: [`lib/core/constants/constants.dart`](lib/core/constants/constants.dart)
- Firebase startup: [`lib/main.dart`](lib/main.dart)
- Authenticated requests: [`lib/services/authenticated_api_client.dart`](lib/services/authenticated_api_client.dart)
- Login and role/status gate: [`lib/screens/login.dart`](lib/screens/login.dart), [`lib/models/app_user.dart`](lib/models/app_user.dart)
- Brand service/model/screen: [`lib/services/brand_service.dart`](lib/services/brand_service.dart), [`lib/models/car_brand.dart`](lib/models/car_brand.dart), [`lib/screens/brands_screen.dart`](lib/screens/brands_screen.dart)
- Converter service/model/screens: [`lib/services/converter_service.dart`](lib/services/converter_service.dart), [`lib/models/converter_record.dart`](lib/models/converter_record.dart), [`lib/screens/catalog_screen.dart`](lib/screens/catalog_screen.dart), [`lib/screens/converter_detail_screen.dart`](lib/screens/converter_detail_screen.dart)
- Search wrapper: [`lib/screens/search_screen.dart`](lib/screens/search_screen.dart)

## API configuration and authentication

- Base URL in the frontend: `https://malik-backend-xhnr.onrender.com`
- Firebase is initialized before `runApp()`.
- `AuthenticatedApiClient.createAuthorizedOptions()` checks `FirebaseAuth.instance.currentUser`, calls `getIdToken()` for each request, and builds an `Authorization: Bearer <token>` header. The token itself is not included in this report or logged by that client. Firebase Auth handles normal token refresh when `getIdToken()` is called.
- Login and registration also obtain a Firebase ID token and pass a Bearer Authorization header to the backend.
- No Dio interceptors were found in the inspected frontend. There is no interceptor that removes or overwrites the authenticated client's header.
- Other direct Dio usage includes LoginScreen (`/api/v1/auth/me`), SignUpScreen (`/api/v1/auth/register`), `BrandService.getBrands()` (`/api/v1/brands/external`), and unrelated metal-price calls. Swagger declares the external-brands route unauthenticated; it is separate from the converter-brand endpoint used by the Brands screen. None of these Dio instances installs interceptors.
- The Home/catalogue route is reached after successful account verification. `CatalogScreen` does not have a user-role restriction; `HomeScreen` passes `isAdmin` only to control the add-converter action.
- A Dart Tooling Daemon was available for the VS Code IDE, but **no Flutter app was connected**, so the current runtime Firebase user/session could not be inspected.

## Paths, query parameters, and Swagger evidence

Swagger/OpenAPI was retrieved from `https://malik-backend-xhnr.onrender.com/openapi.json`.

| Method/path | Swagger authentication | Frontend request parameters |
|---|---|---|
| `GET /api/v1/brands` | `HTTPBearer` | None |
| `GET /api/v1/converters` | `HTTPBearer` | `page` (integer, default 1), `page_size` (integer, default 20), optional `search`, optional `brand_id` |
| `GET /api/v1/converters/{converter_id}` | `HTTPBearer` | Required integer path parameter `converter_id` |

The deployed Swagger document leaves the successful response schemas for all three GET operations empty (`schema: {}`). It therefore does **not** document the brands or converter list/detail JSON response fields. Its `ConverterCreate` schema is for writes and is not evidence of GET response fields.

Frontend parsing currently expects:

- Brands: a list directly or an object with a `data` list. `CarBrand.fromJson()` reads `id`, `name`, `slug` or `external_id`, `logo` or `logo_url`, and optional `converter_count`.
- Converter list: an object containing one of `items`, `converters`, `results`, `data`, or `records` (including a nested result map); a valid `total`; optional `page`, `page_size`, and `total_pages`. Converter fields are parsed from the keys handled by `ConverterRecord.fromJson()`, including backend-style `code_reference`, `brand_id`, `monolith_weight_g`, `markings`, `images`, and PPM fields, plus its listed aliases.
- Detail: an object containing `converter`, `data`, or the converter record itself.

These shapes reflect frontend parsing and fixtures only; the live successful payloads could not be compared.

## Production HTTP probes

Requests were made without credentials. The backend returned:

| Request | Status | Sanitized response / result |
|---|---:|---|
| `GET /api/v1/brands` | `401` | `{"detail":"Not authenticated"}` |
| `GET /api/v1/converters?page=1&page_size=20` | `401` | `{"detail":"Not authenticated"}` |
| `GET /api/v1/converters/{id}` | Not attempted | No valid converter ID could be obtained from an authenticated list response; no ID was guessed. |

No authenticated production request was made. The audit environment did not have an available signed-in test session. Consequently, it is unknown whether an approved active normal user receives `200`, `401`, or `403` for the read endpoints, and the successful JSON compatibility is not proven.

## Pagination, search, errors, and role behavior

- Catalogue page size is 20. Search is debounced by 350 ms, resets to page 1, and is sent as `search`; the selected brand is sent as `brand_id`. Pagination sends subsequent `page` values and appends unique converter IDs.
- The catalogue cache is keyed by search, brand, page size, and page. Errors are displayed/retried rather than converted into an empty successful response. Brand parsing skips malformed individual brand rows; invalid response structure raises `FormatException`.
- Brand and catalogue screens now distinguish `401` and `403` instead of describing every brand request failure as a connection problem or asserting an unverified admin-only policy.
- Role/status checks are in login/account verification and `AppUser.isAdmin`; they do not gate read-only catalogue navigation. Backend remains responsible for read/write authorization.
- Account role/status is not periodically refreshed while Home remains open. Re-login/session restoration calls `/api/v1/auth/me` again.

## Frontend changes and validation

Changes made in this audit:

- `BrandService` now sends `GET /api/v1/brands` through `AuthenticatedApiClient`, sharing the service's Dio instance instead of adding a separate Dio client.
- Brand, catalogue, and detail `403` states no longer claim that admin-only access is the confirmed backend policy.
- Added a regression test proving converter-brand retrieval uses the authenticated API client.
- Test fakes were adjusted to implement the `BrandService` interface after its constructor was changed to share the client.

Executed:

- `flutter analyze` — **passed**, no issues.
- `flutter test test\catalog_test.dart test\widget_test.dart` — **passed**, all tests.

Not validated: successful requests using a signed-in production customer/admin account, real response parsing against the deployed database, or live detail navigation.

## Questions for the backend developer

1. For a Firebase-authenticated, approved, active account with `role = user`, what exact status should `GET /api/v1/brands`, `GET /api/v1/converters`, and `GET /api/v1/converters/{id}` return?
2. Do all three GET routes validate a Firebase ID token from `Authorization: Bearer <Firebase ID token>`? Are any currently attached to an admin-only dependency?
3. Please provide sanitized successful response examples for brands, a paginated converter list, and converter detail. What are the exact response envelope and record field names?
4. Does catalogue search cover code/reference, model, brand, local lingo, and markings? Are `search` and `brand_id` both supported together, and is `total_pages` always returned?
5. Can the GET response schemas be added to the OpenAPI document so the documented contract can be verified by clients?

## Next action

The frontend Brands authentication omission is fixed and regression-tested. The backend developer should test the read routes with an approved active **normal user** Firebase session and report the statuses and sanitized payloads. If those requests return `403`, the backend authorization policy/dependencies need review; if they return `200`, compare the returned JSON with the parsers documented above. No backend source or authorization settings were changed here.
