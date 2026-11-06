# Blooted — Flutter Bluetooth Package

Android-first Flutter BLE plugin with Kotlin Platform Channels and a consuming Flutter example app.

## Separate device information package

- `packages/device_identity/` is a separate Flutter Android package and example app requested by the user; do not merge its API or permissions into Blooted.
- Shows Android public device information and IMEI only when the OS permits it.
- **Why:** Ordinary Android 10+ apps cannot read IMEI using a normal runtime phone permission. Report the restriction explicitly; never substitute Android ID / serial / a generated ID for IMEI.
- No automatic IMEI reads, logs, persistence or uploads. The example reads IMEI only after an explicit user action.
- The user explicitly approved a labelled browser simulation instead of a real emulator. Keep its entry and fake transport separate from Android builds, with persistent simulation labels and nonnumeric DEMO identifiers.
- **Why:** Preview data must never be mistaken for actual device information or a validated hardware IMEI result.
- The user requested Dart for the device identity web UI. Keep its scenario controls and device view in Flutter/Dart, not a React/TypeScript wrapper; retain Kotlin only for actual Android platform access.
- **Why:** The user explicitly selected moving the web preview to Dart, not changing to a dark theme.

## Flutter package (primary product)

- Package and Turkish documentation: `packages/blooted/`
- Example consuming app: `packages/blooted/example/`
- Static checks: `cd packages/blooted && flutter analyze`
- Dart tests: `cd packages/blooted && flutter test`
- Run on a physical Android device with Android SDK: `cd packages/blooted/example && flutter run -d <device-id>`
- Flutter is installed through the Nix system dependency.
- This product is Flutter, not Expo or a web app; do not replace it with a browser demo.

## Product decisions

- The user asked for a Flutter Bluetooth package using Platform Channels, with the consuming application managing the package.
- First version is Android BLE central / GATT client only, as communicated to the user. No iOS, classic Bluetooth SPP, auto-reconnect or background service.
- **Why:** Keep the transport independent of application policy. The app chooses permission prompts, scans, device selection, connection lifecycle and data protocol; the package only executes explicit commands.
- One connection per engine; await GATT calls sequentially. Writes deliberately use at most 20 bytes without implicit fragmentation.
- Native APK compilation and actual BLE behavior require an Android SDK and physical device; Dart tests do not establish hardware compatibility.

The pnpm API and canvas below are the original template, not dependencies of the Flutter product.

## Browser UI preview

- `artifacts/blooted-preview` hosts the actual compiled Flutter example via iframe, not a React recreation.
- `pnpm --filter @workspace/blooted-preview run dev` builds the Flutter web output before Vite starts.
- Browser preview deliberately disables native controls and shows no mock BLE devices.
- **Why:** The user wants to view the app here when local Flutter setup is unavailable. Keep this distinction explicit: previewing the UI does not test the Android BLE package.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

_Populate as you build — short repo map plus pointers to the source-of-truth file for DB schema, API contracts, theme files, etc._

## Architecture decisions

_Populate as you build — non-obvious choices a reader couldn't infer from the code (3-5 bullets)._

## Product

_Describe the high-level user-facing capabilities of this app once they exist._

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

_Populate as you build — sharp edges, "always run X before Y" rules._

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
