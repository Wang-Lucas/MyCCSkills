---
name: vault-driven-dev
description: Implement code changes driven by vault requirements. Reads changed/planned requirements from vault/requirements/, identifies implementation gaps using the traceability matrix, produces a change plan, and executes code modifications. Re-generates the vault after changes for round-trip consistency. Use when the user asks to "implement requirements from vault", "drive code from requirements", "implement REQ-NNN", "requirement-driven development", or "vault-driven dev".
version: 0.2.0
---

# Vault-Driven Development

Read requirements from the vault, identify what code needs to change, and implement it. Produces an implementation plan for review before making any code changes. After code changes, regenerates the vault for round-trip consistency.

## Prerequisites

- A `vault/` directory must exist at the project root with requirements, design notes, and a traceability matrix
- The vault must be up-to-date (run `/cpp-obsidian-vault` first if code has changed independently)

## Workflow

### Step 0: Read Business Context

1. Scan `vault/business/` for all `.md` files
2. For each BR note, parse the YAML frontmatter (`id`, `status`, `date-created`)
3. Identify BRs with `status: accepted` or `status: in-progress`
4. Read the `## Derived Requirements` section to map BR → REQ relationships
5. Include business context ("why") in the implementation plan summary

### Step 1: Read the Vault

1. Read `vault/Traceability Matrix.md` to build an index of all known requirements, their status, and their implementation links
2. Read `vault/MOC.md` to understand the vault structure
3. Scan all files in `vault/requirements/` and read each `.md` file
4. Scan `vault/design/` for all design notes, noting `status: proposed` entries

### Step 2: Identify Changed Requirements

For each requirement note:
- Parse the YAML frontmatter (`id`, `status`, `category`)
- Classify into:
  - **New**: `status: planned` with no `## Implementation` section
  - **Changed**: `status: implemented` but the description or design has been edited
  - **Partial**: `status: partial` — needs completion
  - **No action**: `status: implemented` with no changes, or `status: deprecated`

### Step 3: Gap Analysis

For each requirement needing work:

1. **Check for design**: Does the note have `## Design Decisions` with `[[DES-NNN]]` links?
   - If NO and status is `active` or `planned`: this requirement needs design first. Propose a design note.
   - If YES: read the linked design notes from `vault/design/`
   - If the design note has `status: proposed`: read it and incorporate into the implementation plan. Proposed designs are draft designs created by `/spec-to-vault` that need user approval before implementation.

2. **Check implementation links**: Parse the `## Implementation` section for `[[ClassName]]::method() — file:line` entries
   - If present: read the referenced code and verify it satisfies the requirement
   - If absent: the requirement has no implementation yet — plan from scratch

3. **Map to code locations**: Use the traceability matrix to find:
   - Which classes/files are associated with similar requirements in the same category
   - The layer (presentation/application/domain/infrastructure) for the new code

### Step 4: Generate Implementation Plan

For each requirement, produce a plan in this format:

```markdown
## {REQ-ID} — {Title}

**Status**: planned -> implemented (or partial -> implemented)

### Design Notes
- {List design notes or note that design needs to be created}

### Affected Files
| Layer | File | Action |
|-------|------|--------|
| domain | code/domain/X.h | CREATE |
| application | code/application/Y.cpp | MODIFY |

### Change Sequence
1. ...
2. ...

### Dependencies
- ...
```

**Present the full plan to the user and ask for approval before proceeding.**

### Step 5: Execute Code Changes

After user approval, implement changes in layer order:

1. **Domain layer first** (new types, enums, value objects)
2. **Infrastructure layer** (file I/O, SDK wrappers, utilities)
3. **Application layer** (controllers, wiring)
4. **Presentation layer** (UI elements)
5. **Tests** (unit tests for new/changed code)

Follow existing project conventions:
- `namespace vmrc` for all code
- `snake_case_` suffix for private members
- Doxygen `@brief` comments on all public APIs
- `std::function` callbacks in domain layer
- Qt signals/slots in application and presentation layers
- `std::atomic` for thread-safe counters
- Dependency inversion: controllers depend on interfaces, not concretions

### Step 6: Update Build System

Add any new `.h` and `.cpp` files to `proj/CMakeLists.txt` in the `SOURCES` and `HEADERS` lists. Update `tests/CMakeLists.txt` if new test files were created.

### Step 7: Verify

Run the build and tests. Fix any compilation errors or test failures.

### Step 8: Update Requirement Statuses

After successful build and tests:

1. For each REQ that was implemented:
   - Update `status: active` → `status: implemented` in the REQ file
   - Add `## Implementation` section with `[[ClassName]]::method() — file:line` entries
   - Add `## Test Coverage` section with test suite links

2. Check if the parent BR (from `source: BR-NNN`) has all its derived REQs implemented:
   - Read the BR note's `## Derived Requirements` section
   - For each linked REQ, check its `status` field
   - If all are `implemented`: update BR `status: in-progress` → `status: fulfilled`
   - Update the BR's `## Status History` table with the date and change

3. Update `vault/Traceability Matrix.md` to reflect new statuses

### Step 9: Regenerate Vault

### Step 9: Regenerate Vault

Invoke the `cpp-obsidian-vault` skill to regenerate the vault in incremental mode. This will:
- Update implementation notes for new/modified classes
- Update the traceability matrix
- Update requirement statuses where applicable
- Scan `vault/business/` and `vault/specs/` for new notes

Report the vault changes to the user.

## Edge Cases

- **Conflicting requirements**: Flag and ask user to resolve before proceeding
- **Missing design**: Propose a design note based on similar existing requirements
- **Vague requirements**: Flag for refinement with specific suggestions
- **Multi-layer requirements**: Only propose changes for layers that need work
- **Build failures**: Fix compilation errors and retry
