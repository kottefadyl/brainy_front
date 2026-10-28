# Brainy client

Flutter client for Brainy's collections and entries on Android, iOS, Windows, macOS, and Linux. The browser client is the Next.js app in `../brainy_web_app/`.
The interface is available in English and French. Each collection can have
multiple named data formats, each with its own fields and required pale color.
The first sign-in opens profile setup for name, profession, job, studies,
interests, and hobbies; the profile can be edited later. Number
fields support common units and a custom unit.

Run `flutter pub get`, then `flutter run -d windows` or select a mobile or other desktop device. For a remote API, set
`--dart-define=API_URL=https://your-host/graphql`.

See [the project README](../README.md) for API setup, authentication, and checks.

The flat Brainy mark in `assets/branding/brainy_mark.png` is used in the app and
for platform launch icons. After replacing it, run
`dart run tool/generate_brand_icons.dart` to refresh Android, iOS, macOS,
and Windows icons. The Next.js web app has its own logo in `../brainy_web_app/public/`.
