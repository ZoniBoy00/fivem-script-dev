# Documentation and Version Verification

Use this reference whenever an answer depends on a current FiveM native, framework API, resource export, dependency, or game build.

## Verification order

1. **Identify the exact component** — framework, resource, native, game build, or dependency.
2. **Prefer official documentation** — use the official FiveM native docs, framework docs, or upstream resource documentation.
3. **Inspect upstream status** — check the canonical GitHub repository, default branch, latest commit/release, archive status, and the exact file/export path.
4. **Check compatibility** — verify the selected framework, bridge resource, dependency start order, and server game build.
5. **State uncertainty** — if the server version is unknown or the source cannot be verified, label the assumption and provide the check needed before deployment.

## Sources by component

| Component | Primary source |
|-----------|----------------|
| FiveM natives | `https://docs.fivem.net/natives/` |
| FiveM docs and manifests | `https://docs.fivem.net/docs/` |
| ESX | `https://docs.esx-framework.org/` and the canonical ESX repository |
| QBCore | `https://docs.qbcore.org/` and the canonical QBCore repository |
| QBox | `https://docs.qbox.re/` and the canonical Qbox-project repositories |
| Ox resources | `https://overextended.dev/docs` and the upstream resource repository |

## GitHub checks

For a repository or resource, verify all of the following before recommending it:

- the repository is the canonical upstream project, not an unrelated fork;
- the repository is not archived unless the user explicitly accepts that risk;
- the latest commit or release is recent enough for the server's FiveM build;
- the referenced file, export, event, or documentation URL exists;
- the license and dependency requirements are compatible with the project;
- the API is compatible with the selected framework and installed bridge resources.

Do not use stale online resource lists as proof that a resource is maintained. A repository name alone is not evidence that its current exports or compatibility claims are valid.

## Reporting format

When verification matters, report:

- component and version checked;
- source URL or repository;
- compatibility assumption;
- any unverified point;
- the fallback or server-side guard if the dependency is unavailable.