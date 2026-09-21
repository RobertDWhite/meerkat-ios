# Contributing

Thanks for helping build the Meerkat iOS app. It is a small, dependency-free
SwiftUI project, so the bar to contribute is low.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. `xcodegen generate` (the `.xcodeproj` is also committed, so this is optional
   unless you change `project.yml`)
3. `open Meerkat.xcodeproj`, pick your signing team, run on a device or simulator.

## Layout

```
Meerkat/
  MeerkatApp.swift          entry point
  AppState.swift            credentials + "something changed" signal
  Models/                   Codable mirrors of the Go models (backend/models/*.go)
  Networking/APIClient.swift  one actor wrapping the REST API; Keychain.swift
  Views/                    SwiftUI screens, grouped by tab
```

## Conventions

- Model field names follow the server JSON (snake_case keys → camelCase properties
  via `CodingKeys`). If you add a field, add it to both `Contact` and `ContactInput`
  (PUT is a full replace).
- Talk to the server only through `APIClient`; views never build URLs.
- After any mutation call `state.contactsChanged()` so lists refresh.
- Keep the app free of third-party dependencies.
- Prefer small PRs. Screenshots in the PR description are appreciated for UI changes.

## Testing a change against a real server

Point the app at any Meerkat instance and an API token (Meerkat → Settings →
API Tokens). The Models + APIClient compile as plain Foundation code, so you can
also drive them from a `main.swift` command-line harness on macOS:

```sh
swiftc -o /tmp/harness Meerkat/Models/*.swift Meerkat/Networking/APIClient.swift main.swift
```

## Reporting server-side gaps

If a feature needs an API the server doesn't have, open the issue on
[fbuchner/meerkat-crm](https://github.com/fbuchner/meerkat-crm) and link it here.
