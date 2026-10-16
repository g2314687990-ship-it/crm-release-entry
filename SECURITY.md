# Release entry boundary

This repository contains only generic reviewed release entry files.

Application source, approval contents, credentials, raw private test logs, and plaintext release archives must never be committed, printed, cached, or uploaded here. A successful smoke check proves runner availability only; it does not approve a release.

Only standard GitHub-hosted runners are permitted. No self-hosted runner is registered by this project. Production deployment is manual.

Private access must remain disabled until the exact bootstrap and tool commits
are independently reviewed. Environment `trusted-entry-ab358` allows only tag
`release-entry-ab358-v1`; the active tag ruleset must deny updates and deletion
with no bypass actors. Verify the real environment rejection of unapproved refs
before adding any secret. The tag must resolve to the approved bootstrap commit.

The private read credential must be limited to the one application repository,
with Contents, Actions, Issues and Pull requests read access only. It is separate
from the public job token. Runtime receives neither token nor the transport key.
Encrypted diagnostic artifacts are for independent review and must be decrypted
privately; an encrypted upload or successful smoke is never release approval.
