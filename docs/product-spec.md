# Product Spec

## Name

GitFolder

## One-line description

A macOS menu bar app that automatically versions selected folders with GitHub.

## Problem

Many folders contain files that should have history: notes, documents, markdown content, app data, project specs, design exports, configuration files, or writing drafts.

Git can provide this history, but using Git manually for normal folders is too much friction. The user has to remember to stage, commit, pull, and push.

GitFolder removes that manual workflow for selected folders.

## Goal

Make selected folders versioned by default.

The user should be able to:

1. Pick a folder.
2. Connect it to a GitHub repository.
3. Choose a sync interval.
4. Let GitFolder create automatic snapshot commits in the background.

## Product principles

- Status bar first.
- Quiet by default.
- No forced main window.
- Safe before clever.
- Never silently overwrite or delete user data.
- Hide Git complexity unless it is needed to explain an error.
- Prefer clear status messages over technical Git output.

## Primary user

A technical Mac user who wants automatic versioning for local folders without manually running Git commands.

Phase 1 assumes the user is comfortable with GitHub repositories and SSH keys.

## User-facing language

Use simple words:

- Folder
- Repository
- Sync
- Snapshot
- Last synced
- Needs attention
- Pause
- Sync now

Avoid exposing unnecessary Git internals:

- origin
- rebase
- staging
- detached HEAD
- untracked files

Technical details can still appear in logs.

## Core menu structure

```txt
GitFolder
├─ Sync Now
├─ Pause Syncing
├─ Folders
│  ├─ Notes — Synced 3 min ago
│  ├─ Tiko Content — Needs attention
│  └─ Add Folder…
├─ GitHub
│  ├─ Connected
│  └─ Test Connection
├─ Settings…
├─ Logs
└─ Quit GitFolder
```

## Business model

Phase 1 is a paid Mac App Store utility.

```txt
Price: €5
Purchase: one-time
Entitlement: lifetime
Subscriptions: no
In-app purchases: no
Distribution: Mac App Store only
```

This keeps the product simple. GitFolder does not need a billing backend, license server, account system, or external checkout in Phase 1.

## Core data model

The full data model lives in [Data model](data-model.md).

At the product level, the key entity is still a synced folder:

```ts
type SyncedFolder = {
  id: string
  name: string
  localPath: string
  bookmarkData?: string
  repoUrl: string
  provider: 'github'
  authMode: 'ssh'
  branch: string
  syncIntervalMinutes: 5 | 15 | 30 | 60
  enabled: boolean
  createdAt: string
  updatedAt: string
  lastSyncAt?: string
  lastSuccessfulSyncAt?: string
  lastStatus:
    | 'idle'
    | 'checking'
    | 'syncing'
    | 'synced'
    | 'paused'
    | 'waiting_for_connection'
    | 'needs_attention'
    | 'error'
    | 'conflict'
  lastError?: {
    code: string
    title: string
    message: string
    recoverySuggestion?: string
  }
}
```

## Non-goals

GitFolder is not:

- A full backup system.
- A Git client replacement.
- A Dropbox/iCloud replacement.
- A conflict resolver.
- A full file restore UI in Phase 1.
