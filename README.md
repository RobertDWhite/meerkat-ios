# Meerkat iOS

A native SwiftUI client for [Meerkat CRM](https://github.com/fbuchner/meerkat-crm),
the self-hosted personal CRM. Browse and search your contacts, call/text/email them
in a tap, and add notes, activities, reminders and relationships from your phone.

Open source under the MIT license — contributions welcome, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Features

- **Contacts** — alphabetical list with server-side search, circle filter chips,
  pull-to-refresh, pagination, and an archived toggle
- **Contact detail** — photo, job title / organization, circles, quick actions
  (call, message, email, open address in Maps), all typed emails/phones/addresses/URLs,
  "about" fields, custom fields
- **Timeline** — notes (add/edit/delete), activities, reminders (add/complete/delete),
  relationships (optionally linked to another contact)
- **Create & edit contacts** — every field the server accepts, including typed
  phone/email/URL lists, structured addresses, circles and custom fields
- **Photos** — set a contact's profile picture from your photo library
- **Reminders tab** — open reminders across all contacts plus upcoming birthdays;
  swipe to complete
- **Settings** — server URL + API token (stored in the iOS Keychain), connection test
- No third-party dependencies; iOS 17+, iPhone and iPad

## Requirements

- iOS 17 or later
- Xcode 15 or later (built with Xcode 26)
- A reachable Meerkat server. If it is only on a private network (Tailscale /
  Headscale, VPN, LAN), the phone needs to be on that network too.
- A Meerkat API token: Meerkat → Settings → API Tokens → Create. The token is
  shown once; paste it into the app.

## Building

`Meerkat.xcodeproj` is committed, so:

```sh
git clone https://github.com/RobertDWhite/meerkat-ios.git
cd meerkat-ios
open Meerkat.xcodeproj
```

Select your device (or a simulator that can reach your server), set your signing
team under **Signing & Capabilities**, and run. On first launch enter the server
URL and API token.

The project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen); if you change targets or
settings, edit `project.yml` and re-run `xcodegen generate`.

CI builds every push and PR for the iOS Simulator (`.github/workflows/build.yml`).

## How it talks to the server

Everything goes through Meerkat's REST API under `/api/v1` with an
`Authorization: Bearer <token>` header — the same API the web UI uses. The
client (`Meerkat/Networking/APIClient.swift`) mirrors the routes in
`backend/routes/routes.go`; the models mirror `backend/models/*.go`.

Two server behaviours the app works around:

- **PUT is a full replace.** The edit screen always sends every field, built from
  a freshly fetched contact, so nothing gets blanked.
- **SQLite can be busy.** Under concurrent writes Meerkat returns transient 500s
  (and occasionally a 401 "Invalid token" from the token lookup). The client
  retries those a few times with backoff.

## Roadmap / ideas

- Offline cache of the contact list
- Home-screen widget for upcoming reminders and birthdays
- Share-sheet extension to add a note from other apps
- vCard export / Apple Contacts sync
- Relationship graph view

## License

MIT — see [LICENSE](LICENSE). Meerkat CRM itself is also MIT-licensed by
Frederic Buchner.
