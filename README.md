# RoadRescue

Flutter mobile app for on-demand roadside assistance. Customers request help, providers quote and fulfill jobs, and admins manage the platform. Backend is Supabase (Postgres, Auth, Realtime) with Stripe payments via Edge Functions.

## Prerequisites

- Flutter SDK 3.9+ (Dart 3.9+)
- Supabase project
- Stripe account (test mode for development)

## Quick start

1. Copy the environment template and fill in your keys:

```bash
cp env.example.json env.json
```

2. Run with compile-time defines (never bundle `env.json` as a Flutter asset):

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

Required keys in `env.json`:

| Key | Description |
|-----|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key |

**Security:** `env.json` is gitignored and must NOT be added to `pubspec.yaml` assets. Pass it only via `--dart-define-from-file`. If keys were ever committed, rotate them in the Supabase and Stripe dashboards.

## Supabase setup

1. Link your project (optional, for CLI):

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

2. Apply migrations:

```bash
supabase db push
```

Migrations live in [`supabase/migrations/`](supabase/migrations/). The latest migrations restore `payments` and `provider_subscriptions` and tighten RLS.

3. Deploy Edge Functions and set secrets in the Supabase dashboard (Project Settings → Edge Functions → Secrets):

| Secret | Used by |
|--------|---------|
| `STRIPE_SECRET_KEY` | `create-payment-intent`, `confirm-payment` |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge functions (service role) |
| `SUPABASE_URL` | Edge functions |

```bash
supabase functions deploy create-payment-intent
supabase functions deploy confirm-payment
```

## Release builds

Always pass environment defines for release builds:

```bash
flutter build apk --release --dart-define-from-file=env.json
flutter build ios --release --dart-define-from-file=env.json
```

Android release signing: configure a release keystore in [`android/app/build.gradle.kts`](android/app/build.gradle.kts) before store submission. The default release build uses debug signing for local testing only.

## Project structure

```
lib/
├── main.dart                 # App entry, service init
├── routes/                   # Named routes + auth guards
├── services/                 # Supabase, notifications, theme, i18n
├── presentation/             # Screens (customer, provider, admin)
├── theme/
└── widgets/
supabase/
├── migrations/               # Postgres schema
└── functions/                # Stripe payment Edge Functions
assets/lang/                  # i18n (en, es, fr, pt, de, ar)
```

## Roles

| Role | Home screen |
|------|-------------|
| Customer | Service request |
| Provider | Job requests |
| Admin | Admin dashboard |

Route guards enforce role access; unauthenticated users are redirected to login.

## VS Code / Cursor launch

Use [`.vscode/launch.json`](.vscode/launch.json) or add to your config:

```json
"args": ["--dart-define-from-file", "env.json"]
```

## CI

GitHub Actions runs `flutter analyze` and `flutter test` on push/PR (see [`.github/workflows/flutter.yml`](.github/workflows/flutter.yml)).
