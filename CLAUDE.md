# CLAUDE.md

Follow AGENTS.md as the source of truth.

Before coding, read:

- AGENTS.md
- docs/00-index.md
- the current roadmap phase file

Do not load every document unless the task requires it.

Build Scap in phases. Do not start the landing page first.

Important:

- The real Xcode project is `apps/mac/Scap.xcodeproj`.
- Do not create fake placeholder `.xcodeproj` files.
- Empty app folders may contain `.gitkeep` only until Phase 00 creates real files.

Hard rules:

- Native Swift / SwiftUI / AppKit only.
- No Electron.
- No backend.
- No accounts.
- No cloud sync.
- No unrelated phase work.
- App must build after every phase.
- Screenshots, recordings and metadata must stay on the user's Mac in V0.1.
- The active V0.1 product is a screenshot/recording library, not a direct screen-capture engine.
- Do not require Screen Recording permission for the normal V0.1 flow.
