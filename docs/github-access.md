# GitHub Access

## Phase 1 approach

Phase 1 uses local Git and existing GitHub SSH access.

GitFolder does not need to implement GitHub OAuth yet. It can run normal Git commands through the system Git installation.

The user is expected to have SSH access working already.

Example repository URL:

```txt
git@github.com:silvandiepen/Gitfolder.git
```

## Test connection

GitFolder should test GitHub access before enabling a folder.

Possible test:

```bash
git ls-remote git@github.com:silvandiepen/repo.git
```

If the command succeeds, GitFolder can use the repository.

If the command fails, show:

```txt
GitHub access failed. Check your SSH key or repository permissions.
```

## Repository setup modes

### Existing folder, empty GitHub repo

If the local folder is not a Git repository:

```bash
git init
git branch -M main
git remote add origin git@github.com:user/repo.git
git add .
git commit -m "Initial GitFolder snapshot"
git push -u origin main
```

### Existing Git repository

If the folder already has `.git`:

1. Check remote.
2. If no remote exists, add one.
3. If remote exists, confirm it matches the configured repo.
4. Use the configured branch.

## Deferred GitHub features

Later phases can add:

- GitHub OAuth.
- Repository picker.
- Create new repository from app.
- Token-based HTTPS Git access.
- Better account status.
- Support for GitHub Enterprise.

## Why not OAuth in Phase 1?

OAuth adds product complexity:

- Login flow.
- Token storage.
- Token refresh/revocation.
- Repository permissions.
- Git credential handling.
- App registration.

For a personal first version, SSH is simpler and enough.
