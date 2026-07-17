# @gitkit/gitkanban-core

The platform-agnostic contract for **GitKanban** boards: the schema and logic for
turning a git repo of markdown files into a kanban board. TypeScript is the source
of truth; the Swift apps mirror this package.

It implements the canonical board contract defined in
`project-assets/Tasks/README.md` — root/project configuration with inheritance, and
markdown cards with YAML frontmatter.

## What's here

| Module | Responsibility |
|---|---|
| `types.ts` | `Lane`, `User`, `Epic`, `Priority`, `BoardConfig`, `ProjectConfig`, `EffectiveConfig`, card types |
| `frontmatter.ts` | Parse/serialize markdown frontmatter, **preserving keys the app does not model** |
| `inheritance.ts` | `resolveEffectiveConfig(root, project)` — lanes **replace**, vocabularies **merge** |
| `rank.ts` | Fractional rank keys for intra-lane ordering (insert rewrites one card) |
| `card.ts` | Read card fields, map `status`→lane, group cards into ordered columns |
| `validation.ts` | Validate a card against its effective config (status/priority/type/assignee/epic) |

## Design rules

- **One card = one file.** Editing a card never touches another card's bytes.
- **Column = a field (`status`), not a folder** at the data layer; folder-per-lane is the
  on-disk projection (see the contract). Lanes carry their `folder`, so both views agree.
- **Additive and lenient.** Unknown frontmatter/config keys are preserved on round-trip, so
  agents (sills) and other tools can add fields this package does not know about.

## Scripts

```bash
npm run typecheck -w packages/gitkanban-core
npm test -w packages/gitkanban-core
npm run build -w packages/gitkanban-core
```
