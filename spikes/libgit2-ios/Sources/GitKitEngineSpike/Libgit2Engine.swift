import Foundation
import SwiftGit2

// libgit2-backed GitEngine for iOS. This is a SPIKE implementation: it is written to be read
// and run on a Mac, and it is deliberately explicit about which parts are confidently
// expressible with the SwiftGit2 high-level API and which parts are the known-risky ones that
// may force a drop to the libgit2 C API. Every method documents the underlying libgit2 C-API
// call sequence, which is the stable source of truth regardless of wrapper.
//
// NOT COMPILED in the authoring session (Linux, no Swift/libgit2/iOS SDK). Treat the SwiftGit2
// calls as a starting point to reconcile against the pinned SwiftGit2 fork's exact API.
public struct Libgit2Engine: GitEngine {
    public init() {}

    // MARK: clone  —  git_clone with a credentials callback
    // C-API: git_clone(&repo, url, path, &opts) where
    //   opts.fetch_opts.callbacks.credentials = cb returning
    //   git_credential_userpass_plaintext_new(out, "x-access-token", token)
    public func clone(from remoteURL: URL, into directory: URL, credentials: GitCredentials) async throws {
        let creds = Credentials.plaintext(username: credentials.username, password: credentials.token)
        let result = Repository.clone(from: remoteURL, to: directory, credentials: creds)
        switch result {
        case .success:
            return
        case .failure(let error):
            // libgit2 reports auth failures as GIT_EAUTH (-16). Surface them distinctly so the
            // app can prompt re-auth (mirrors the token flow shared with macOS).
            if error.code == -16 { throw GitEngineError.authFailed(error.localizedDescription) }
            throw GitEngineError.cloneFailed(error.localizedDescription)
        }
    }

    // MARK: commitAll  —  stage everything, then git_commit_create
    // C-API: git_index_add_all(index, ...) → git_index_write + git_index_write_tree →
    //        git_commit_create(&oid, repo, "HEAD", author, committer, "UTF-8", msg, tree, parents)
    public func commitAll(in directory: URL, message: String, author: Signature) async throws -> CommitResult {
        let repo: Repository
        switch Repository.at(directory) {
        case .success(let r): repo = r
        case .failure(let e): throw GitEngineError.commitFailed(e.localizedDescription)
        }

        // Stage every change (adds, modifications, deletions) — the iOS equivalent of `git add -A`.
        // NOTE: the app layer must run the pre-push SAFETY SCAN (GITKIT-112) BEFORE this stage so
        // secrets/large files are never committed. The spike stages unconditionally on purpose to
        // isolate the git question.
        guard let sig = try? SwiftGit2.Signature(name: author.name, email: author.email) else {
            throw GitEngineError.commitFailed("invalid signature")
        }
        switch repo.stageAllAndCommit(message: message, signature: sig) {
        case .success(let commit):
            return CommitResult(sha: commit.oid.description, message: message)
        case .failure(let e):
            let s = e.localizedDescription
            if s.localizedCaseInsensitiveContains("nothing to commit") {
                return CommitResult(sha: "", message: "No changes")
            }
            throw GitEngineError.commitFailed(s)
        }
    }

    // MARK: pullRebase  —  fetch then rebase/merge, conflict-safe
    // C-API: git_remote_fetch(...) → git_rebase_init / git_rebase_next / git_rebase_commit;
    //        on GIT_ECONFLICT: git_rebase_abort(rebase) and throw .conflict so the tree is clean.
    // KNOWN RISK: SwiftGit2's rebase/merge coverage is thin. If it cannot do a conflict-safe
    // rebase, this is the first place to drop to the C API. The non-negotiable behavior (audit
    // EXP-0002 / GITKIT-013) is: NEVER leave the tree mid-rebase and NEVER commit conflict markers.
    public func pullRebase(in directory: URL, branch: String, credentials: GitCredentials) async throws {
        // Intentionally unimplemented in the spike scaffold: this is exactly the capability we must
        // prove/measure on a Mac, and guessing SwiftGit2's rebase API here would be misleading.
        // Validation steps are in README.md. Implement fetch first (low risk), then attempt rebase;
        // if rebase is unavailable, record that finding and plan the C-API path.
        throw GitEngineError.notImplemented(
            "pullRebase: prove fetch (git_remote_fetch) + conflict-safe rebase on device; see README checklist"
        )
    }

    // MARK: push  —  git_remote_push with the same credentials callback  ← THE make-or-break capability
    // C-API: git_remote_lookup(&remote, repo, "origin") →
    //        git_remote_push(remote, &refspecs["refs/heads/<branch>:refs/heads/<branch>"], &opts)
    //        with opts.callbacks.credentials = userpass_plaintext(x-access-token, token)
    // KNOWN RISK: historically the weakest area of the Swift wrappers. If SwiftGit2 lacks a working
    // authenticated push, that is the single most important finding of this spike — it decides
    // whether we adopt SwiftGit2 or go straight to the libgit2 C API for the real engine.
    public func push(in directory: URL, branch: String, credentials: GitCredentials) async throws {
        throw GitEngineError.notImplemented(
            "push: prove authenticated HTTPS push (git_remote_push + userpass callback) on device; see README checklist"
        )
    }
}

// The two helpers below (`stageAllAndCommit`, `Repository.at`) name the shape we need from the
// wrapper. If the pinned SwiftGit2 fork spells these differently, adapt here — the call sites and
// the C-API comments above are the contract.
private extension Repository {
    func stageAllAndCommit(message: String, signature: SwiftGit2.Signature) -> Result<Commit, NSError> {
        // Placeholder for: index.addAll → writeTree → commit(tree, parents:[HEAD]).
        // Left explicit rather than faked so a Mac dev wires it to the real API and can trust
        // everything that DOES compile.
        return .failure(NSError(domain: "spike", code: 1, userInfo: [NSLocalizedDescriptionKey:
            "stageAllAndCommit: wire to SwiftGit2 index/commit API — see C-API comment"]))
    }
}
