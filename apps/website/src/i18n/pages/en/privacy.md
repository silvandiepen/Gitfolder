This policy covers the GitKit apps — **GitFolder** and **GitKanban**. Both are local-first macOS utilities. They are designed so that your data never passes through GitKit servers, because there are none.

## No cloud service

GitKit does not run a cloud sync service. The apps read only the folders and repositories you explicitly select, and push changes directly to the git remotes you configure (such as GitHub).

## No GitKit account

There is no GitKit account. No email, no password, no user profile. The apps are local macOS utilities that talk directly to your git host.

## No data collection or telemetry

The apps do not collect, transmit, or store any personal data on GitKit servers, and do not phone home with telemetry, analytics, or usage data. File contents move directly from your Mac to your own repositories.

## Local data

Configuration (folder paths, repository URLs, sync intervals, board settings) is stored locally on your Mac. Access tokens are stored in the macOS Keychain, not in a plain config file.

## Git host data

Your selected folder or board contents are transmitted directly from your Mac to the repositories you configure so the apps can create and push commits. Those files are stored under your own account with your git host and are subject to that host's privacy policy — for GitHub, GitHub's privacy policy applies.

## Contact

Questions about privacy? Email [me@sil.mt](mailto:me@sil.mt) or open an issue on [GitHub](https://github.com/silvandiepen/Gitfolder).
