# GitKanban iOS — Features

**Everything on this page is Planned.** GitKanban iOS is the furthest-out target in the GitKit
monorepo. It is gated behind two things that do not exist yet: **GitKanban macOS (Phase 1)**, which
proves the board and produces the shared board UI layer, and the **iOS git engine**
(`Libgit2Engine`), which gives iOS a way to talk to git at all. Until both land, nothing here is
buildable. Where the plan is silent on an iOS specific, the entry says **Open**.

## Guiding contract (inherited, not re-invented)

GitKanban iOS ships the **same board contract as macOS**, so a board authored or edited on one
platform renders identically on the other:

- A board is a folder of markdown card files plus a board config file.
- One card = one markdown file (YAML frontmatter + markdown body).
- A **column is derived from the card's `status` field**, not from folder membership — moving a
  card edits one field in one file, keeping diffs and history clean.
- Ordering within a column uses **fractional rank keys** so an insert rewrites only one card.
- Config inheritance (`root` → `project`): lanes **replace**, vocabularies **merge**.
- Unknown frontmatter/config keys are **preserved on round-trip** (agent- and tool-written boards
  stay intact).

All of the above is owned by [`@gitkit/gitkanban-core`](../../../packages/gitkanban-core/)
(TypeScript, the source of truth) and mirrored into Swift. iOS consumes that mirror — it does not
fork the schema.

## Planned feature set

| Feature | What it is on iOS | Status | Notes |
|---|---|---|---|
| Open a board | Point the app at a GitHub repo + folder; clone locally | Planned | Reuses OAuth + Keychain from `swift/GitKit` |
| Board rendering | Columns + cards from a board, on a touch layout | Planned | Reuses the shared board UI; iOS navigation |
| Card editor | Frontmatter fields + markdown body | Planned | Shared editor domain; touch-native chrome |
| Create / archive card | Add a card file; archive (folder or `git rm`) | Planned | Archive strategy is **Open** (see Decisions/plan) |
| Move between columns | Drag a card = edit its `status` field | Planned | Touch drag-and-drop; one-field, one-file write |
| Reorder within a column | Mint one rank key between neighbours | Planned | Shared rank-key logic |
| Per-card history | "Who moved this and when" from `git log --follow` | Planned | Depends on `GitEngine.fileHistory` on libgit2 |
| Offline / local-first | Full local clone; edits work offline, sync later | Planned | Requires `Libgit2Engine` (true on-device git) |
| Git sync | Manual **Sync Now** + interval pull-rebase / push | Planned | Over HTTPS with a Keychain OAuth token |
| Conflict surfacing | Conflicts shown, never silently resolved | Planned | Mirrors macOS sync-state model |

## Platform-specific notes

- **Transport:** HTTPS with a GitHub OAuth token stored in the iOS Keychain. There is no SSH agent
  or `~/.ssh` on iOS; SSH-on-iOS (libssh2) is **not** targeted for v1.
- **Engine:** primary path is the embedded-libgit2 `Libgit2Engine`. A **GitHub HTTP API** engine
  (no local clone, read-mostly "lite" mode) is a possible fallback if libgit2 integration slips —
  the `GitEngine` protocol means the app layer does not care which wins.
- **Provider:** GitHub first (reuses GitFolder's OAuth). GitLab / generic remotes are Phase 3.

## Explicit non-goals (mirror the product spec)

- No realtime multiplayer — sync is eventual (git-speed, seconds-to-minutes), not live.
- No hosted service or accounts — the user brings their own git host.
- Not a full PM suite — no gantt, sprints/burndown, or time tracking in v1. It is a board.
- Multiple boards are Phase 3; v1 is one board.

## Gating dependencies (why this is Planned, not In Progress)

1. **GitKanban macOS (Phase 1)** must prove the markdown schema, conflict-resilient writes, and the
   board UI on a platform that already has git. The shared board UI layer is produced there.
2. **The iOS git engine** must exist: the `spikes/libgit2-ios/` spike (`GITKIT-128`) must show
   authenticated clone/commit/pull-rebase/push over HTTPS on-device, then `Libgit2Engine` must be
   implemented in `swift/GitKit`. This is the single highest-risk unknown and is de-risked first in
   Phase 2, before any iOS UI work.
