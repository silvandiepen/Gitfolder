# GitKanban (iOS)

The iOS counterpart of the GitKanban board app — the same "your kanban board is a git repo"
contract as [GitKanban macOS](../gitkanban-macos/), rendered on a touch UI.

**Status: working read/write board over an API transport.** The app is scaffolded and builds for
the iOS Simulator. It connects to a git host (GitHub, GitLab.com, or self-hosted GitLab) with a
personal access token, lists repositories, and loads a board **over the provider's REST API via
[git-pont](../../../_libs/git-pont)** — no local clone, no `git` binary, no `libgit2`. Cards can be
**created, edited, reordered, moved between lanes, and deleted**; each write is an immediate
provider commit and the board reloads. The board renders as **lanes (kanban) or a list** (toggle),
with **backlog lanes ordered last** and card **descriptions rendered as Markdown** in the detail.
Board parsing/model is the shared `swift/GitKit` (`RemoteBoardStore` + `BoardFileSource`). Still to
do: OAuth sign-in (personal-access-token only today), per-card history, offline/local mode, and
sync/conflict handling (writes are currently blind, last-writer-wins). An embedded-libgit2 offline
mode remains a possible later addition, not a gate — the earlier "libgit2 engine first" plan is
superseded.

## What it is

A native SwiftUI kanban app whose data source is a git repository of markdown card files. It reads
and writes the same boards macOS reads (one card = one markdown file with YAML frontmatter; a lane
is a folder and the card's `status` matches it), reusing the shared board logic rather than
inventing its own.

The defining difference from macOS is transport: **iOS has no shell and no `git` binary**, so it
cannot shell out to `git` the way macOS does. Instead of an on-device git engine, GitKanban iOS
talks to the host over HTTPS through **git-pont** — a provider abstraction with GitHub and GitLab
backends — reading files with `listDirectory`/`readFile` and writing them with
`commitFile`/`deleteFile`. GitKit's transport-agnostic `RemoteBoardStore` + `BoardFileSource` turn
those file operations into a parsed board, so the schema/model is shared with macOS and does not
fork.

## Dependencies

| Depends on | For | Status |
|---|---|---|
| [`@gitkit/gitkanban-core`](../../packages/gitkanban-core/) | Board schema + logic (TS, source of truth; Swift mirrors) | Built + tested |
| [`swift/GitKit`](../../swift/GitKit/) — `RemoteBoardStore` + `BoardFileSource` | Transport-agnostic board load/parse | Built; used by this app |
| [`swift/GitKit`](../../swift/GitKit/) — `KeychainService`, `CardText`, `BoardMarkdown` | Token storage + card parsing | Built; used by this app |
| [git-pont](../../../_libs/git-pont) — `GitPontCore`, `GitPontGitHub`, `GitPontGitLab` | Provider REST transport (read + write) | Built; linked in `project.yml` |

The app does **not** use `GitEngine`/`ShellGitEngine`, `GitHubOAuthService`, or any `Libgit2Engine`
— there is no on-device git and no libgit2 in the repo. It authenticates with a user-supplied
personal access token, not device-flow OAuth.

## What the app does today

- **Connect** to GitHub, GitLab.com, or a self-hosted GitLab with a personal access token
  (validated via the provider account call); token stored in the Keychain, provider choice in
  UserDefaults; auto-restore on launch.
- **List / search repositories** and pick one to open.
- **Load a board over the API** (no clone) via `GitPontFileSource` + `RemoteBoardStore`; switch
  between projects when a repo has more than one.
- **Render lanes** as grouped list sections (lane color + count, priority chips, id/`@assignee`)
  with a trailing **Uncategorised** column.
- **Create / edit / move / delete cards** — each is an immediate provider commit
  (`commitFile`/`deleteFile`), after which the board reloads; a "Saving…" overlay shows during
  writes. Pull-to-refresh reloads; sign out clears state.

## Where the plan and tasks live

- **Plan:** `/Users/silvandiepen/Projects/GitKit/GitKanban/plan/` — start with
  `platforms-and-git.md` (the macOS-vs-iOS git story), then `architecture.md`.
- **Tasks:** the `GitKit` board in `/Users/silvandiepen/Projects/Tasks/GitKit/`, epic
  **`gitkanban-ios`**.
- App-specific agent rules: [`AGENTS.md`](./AGENTS.md). Detail: [`docs/`](./docs/).
