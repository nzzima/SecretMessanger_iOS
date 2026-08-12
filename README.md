# SecretMessanger

An iOS messenger built on Firebase, with messages encrypted on the device before they
ever reach the database.

UIKit, MVP, no SwiftUI. Around 8 000 lines of Swift and 64 unit tests.

*[Читать по-русски](README.ru.md)*

| Chats | Conversation | Contacts | Profile |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/chats.png" width="200"> | <img src="docs/screenshots/conversation.png" width="200"> | <img src="docs/screenshots/contacts.png" width="200"> | <img src="docs/screenshots/profile.png" width="200"> |

<sub>Simulator, test accounts. A one-to-one row shows the other person's avatar; a group
shows a glyph, because picking one member's face out of several would simply be untrue.</sub>

---

## What works

| | |
|---|---|
| **Sign in** | Email and password, plus a Face ID / Touch ID lock on launch |
| **Registration** | Unique logins, held by a registry rather than by a client-side check |
| **Conversations** | One-to-one and groups, with members added, removed, and left |
| **Encryption** | Sealed on the device; the key is rotated when someone is removed |
| **Attachments** | Voice notes, photos and a point on a map — all inside Firestore |
| **Profiles** | Login, name, note and avatar, editable, with the login rename handled |

Not done yet: video, live location, captions on photos, taking a photo with the camera,
transferring group ownership, and turning a one-to-one chat into a group.

## Architecture

MVP with a `Builder` as the module factory. Each screen is a `View` / `Presenter` /
`Manager` triple: the view knows nothing but its presenter's protocol, and the manager is
the only thing that talks to Firestore.

```
SecretMessanger/
├─ Module/
│  ├─ Authentication/   biometrics, sign-in, registration
│  └─ App/              contacts, chats, conversation, members, profiles
├─ Helpers/
│  ├─ Crypto/           keys, sealing, the conversation key
│  ├─ Image/            avatars: storage, encoder, the round view
│  ├─ Audio/            recorder and player
│  ├─ Location/         a single fix, with retries
│  └─ LoginRegistry/    unique names
└─ Builder/             module factory
```

Firestore is called directly from the managers rather than hidden behind a transport
protocol. That was a deliberate decision: this app is finished on Firebase, so there is
no second implementation for the abstraction to serve.

## Data in Firestore

```
users/{uid}              login, name, someInfo, publicKey, avatarVersion
logins/{login}           uid                      — a document per taken name
avatars/{uid}            data (bytes), version
conversation/{id}        users, owner, logins, lastMessage, convoKeys, keyVersion
   messages/{id}         senderId, message, type, enc, v, date
   audio/{id}            senderId, data (bytes)   — voice notes
   images/{id}           senderId, data (bytes)   — photos
```

Two ideas run through this schema.

**Media lives inside documents.** Cloud Storage would need the Blaze plan, and — more to
the point — its rules cannot read Firestore, so "only members of this conversation may
open this file" cannot be expressed there at all. A voice note in mono AAC is about
180 KB a minute; a photo is squeezed to fit a 700 KB budget. Both stay in subcollections
rather than in the message itself, because a chat re-reads its last fifty messages on
every change and megabytes cannot ride along.

**Bytes and their descriptions are separated.** The message carries a duration or the
image dimensions, which is enough to lay out the bubble before the bytes arrive.

## Encryption

Every user has a permanent Curve25519 key pair. The private half lives in the Keychain
and never leaves it; the public half is published to their profile. Keychain storage is
synchronisable, so the key travels to other devices of the same Apple ID through iCloud
Keychain — without that, a new phone would mean permanently unreadable history.

Each conversation has a symmetric key, stored in the conversation header sealed
separately for every member:

```
convoKeys: { "<uid>_<version>": "<ephemeral public key>.<ciphertext>" }
keyVersion: <current version>
```

Sealing uses a one-time key pair, so the recipient does not need to know who sealed it.
The conversation id and the key version are mixed into the HKDF output, which is what
stops a sealed key from being moved to another conversation or replayed as another
version — both are covered by tests.

Removing someone from a group issues a new key version for everyone else. Older versions
stay in the header so that history remains readable, and every message remembers which
version sealed it.

> **What encryption does not hide:** `senderId`, timestamps, the member list, logins, the
> avatar, and the fact and frequency of a conversation. Firestore sees all of it. The
> content is closed; the structure is not, and there is no point pretending otherwise.

## Security rules

`firestore.rules` is in the repository and deployed. Profiles are readable by any signed-in
user — that is what the contacts list is built on — while a conversation and its messages
are readable only by its members, `senderId` must match the signed-in user, and messages
cannot be edited or deleted by anyone.

The rules are covered by their own suite run through the Rules API, most recently 12 cases
for the avatar collection alone.

## Building

Xcode 16, iOS 17.6 and up. Dependencies resolve through SPM on first open:
firebase-ios-sdk 11.7+, MessageKit 5.0+.

> **Build signed.** With `CODE_SIGNING_ALLOWED=NO` the app compiles and launches, but
> Firebase Auth fails on `An error occurred when accessing the keychain`: without an
> entitlement there is no keychain to store the session in. On screen it looks like the
> Sign in button doing nothing at all, which is worth knowing before spending half a day
> on it.

`GoogleService-Info.plist` is committed on purpose — a client config is public by nature,
and what protects the database is the rules, not that file.

## Tests

64 tests, none of which need the network or a screen:

```bash
xcodebuild test -project SecretMessanger.xcodeproj -scheme SecretMessanger \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

They cover the code where a mistake is both expensive and invisible: the crypto
primitives (mostly the negative cases — a stranger's key opens nothing, a sealed key
cannot change conversation or version), the image encoders and their budgets, login
rules, the deterministic conversation id, the location payload, and the document schema
in both directions — what the app writes and what it reads back.

Not covered: anything that actually talks to Firestore, and the screens.
