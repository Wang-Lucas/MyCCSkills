---
name: cpp-vault-bugfix
description: Diagnose and fix bugs in C++ projects using the vault as the primary knowledge source. Maps bug symptoms to requirements via the traceability matrix, navigates directly to relevant code, diagnoses root cause, applies a minimal fix, and updates the vault. Use when the user reports a bug, says "something is wrong", asks to "fix a bug using the vault", or mentions unexpected behavior in a vaulted project.
version: 0.1.0
---

# C++ Vault-Based Bug Fix

Diagnose and fix bugs in C++ projects by leveraging the existing knowledge vault. The vault is the primary knowledge source — read it before scanning any code. Be surgical: fix only what is broken, no refactoring.

## Prerequisites

- A `vault/` directory must exist at the project root with requirements, design notes, and a traceability matrix
- If the vault is stale (code has changed since the last vault generation), run `/cpp-obsidian-vault` first to synchronize

## Workflow

### Step 1: Symptom Analysis

Parse the user's bug report to extract:
- **Observed behavior**: What the user sees happening (error messages, incorrect output, crashes, UI glitches)
- **Expected behavior**: What the user expected to happen
- **Reproduction context**: Steps to reproduce, input data, configuration, environment
- **Severity**: Crash / data corruption / wrong result / cosmetic

Classify the symptom type to guide the search:
- **Functional bug**: Wrong output, missing feature behavior — map to requirements
- **Crash / exception**: Stack trace, segfault — map to class interactions and thread safety
- **UI bug**: Visual or interaction issue — map to REQ-UI-* requirements
- **Performance bug**: Slow operation, memory leak — map to design notes on thread safety and data flow
- **Build / configuration bug**: Compilation error, missing dependency — skip vault, check build files directly

### Step 2: Vault Lookup

1. Read `vault/MOC.md` to understand the vault structure and available notes
2. Read `vault/Traceability Matrix.md` to find requirements potentially related to the symptom
3. For each potentially relevant REQ:
   - Read the REQ file from `vault/requirements/`
   - Note the `status` field — if `deprecated`, deprioritize
   - Read the `## Acceptance Criteria` section — this defines **expected behavior**
   - Read the `## Implementation` section for `[[ClassName]]::method() — file:line` entries
   - Note the `## Design Decisions` section and read linked DES files from `vault/design/`
4. Read implementation/class notes from `vault/implementation/classes/` for each affected class:
   - Review the public API table, composition relationships, and thread safety markers
   - This gives you a quick understanding without reading every source file

Build a shortlist of the most likely affected code areas (3-5 targets maximum).

### Step 3: Code Navigation

Navigate directly to the source files identified from vault notes:
- Read only the relevant methods and their callers
- Trace the execution path from entry point to the symptom location
- Check the `## Implementation` entries in REQ files for the specific file:line references

For crash bugs, also check:
- Thread safety markers in class notes (mutex usage, atomic members)
- Composition relationships (ownership via `unique_ptr` vs non-owning `T*`)
- Callback chains (`std::function` members, Qt signal-slot connections)

For UI bugs, also check:
- REQ-UI-* files in `vault/requirements/`
- Presentation layer classes and their Qt signal/slot definitions

### Step 4: Root Cause Analysis

Compare **expected behavior** (from REQ acceptance criteria and design notes) with **actual code behavior**:

1. Identify the specific code path that produces the observed symptom
2. Trace back to find where the behavior diverges from the requirement
3. Distinguish between:
   - **Logic error**: Wrong algorithm, wrong condition, off-by-one
   - **Missing check**: Null pointer, empty container, edge case not handled
   - **State error**: Wrong initialization, stale state, race condition
   - **Integration error**: Wrong signal connected, wrong callback, wrong interface method
   - **Requirement gap**: The requirement never specified this behavior (file as a new REQ, not a bug)

Document the root cause in a concise statement:
```
Root cause: {one sentence describing what went wrong and why}
Location: {file:line or method name}
Affected REQ(s): {REQ-NNN links}
```

### Step 5: Fix Plan

Propose a minimal fix with specific changes. Format:

```markdown
## Bug Fix Plan

### Root Cause
{Root cause statement}

### Proposed Changes
| File | Line(s) | Change | Reason |
|------|---------|--------|--------|
| code/.../X.h/cpp | N-M | {specific change} | {why this fixes it} |

### Risk Assessment
- **Scope**: {files/methods affected by the change}
- **Side effects**: {potential regressions, if any}
- **Test coverage**: {existing tests that cover this area}
```

**Present the plan to the user and ask for approval before making any code changes.**

### Step 6: Apply Fix

After user approval, apply the minimal change:
- Modify only the files and lines identified in the fix plan
- Do not refactor, rename, or restructure unrelated code
- Follow existing project conventions:
  - `namespace vmrc` for all code
  - `snake_case_` suffix for private members
  - Doxygen `@brief` comments on new public APIs
  - `std::function` callbacks in domain layer
  - Qt signals/slots in application and presentation layers
  - `std::atomic` for thread-safe counters
  - Dependency inversion: controllers depend on interfaces, not concretions

### Step 7: Verify

1. Build the project. Fix any compilation errors introduced by the change.
2. Run the test suite. Verify no existing tests regress.
3. If possible, verify the specific bug scenario is resolved.
4. If tests fail and the failure is unrelated to the fix, investigate and resolve before proceeding.

### Step 8: Update Vault

After successful verification:

1. **Update affected REQ files**:
   - If a `## Known Issues` section exists, remove the fixed issue
   - Add a `## Bug Fix History` section if the file does not have one:
     ```markdown
     ## Bug Fix History
     | Date | Bug Description | Fix | File |
     |------|----------------|-----|------|
     | YYYY-MM-DD | {brief description} | {one-liner} | {file:line} |
     ```
   - If the REQ was `status: partial` due to this bug, consider updating to `status: implemented`

2. **Update implementation/class notes** (if the fix changed public API, signatures, or class structure):
   - Update `vault/implementation/classes/` notes to reflect any signature changes
   - Update composition relationships if pointers or ownership changed

3. **Update `vault/Traceability Matrix.md`**:
   - If any REQ status changed, update the corresponding row
   - If new implementation links were added, update the IMPL column

4. **Regenerate the vault**:
   - Invoke the `cpp-obsidian-vault` skill to regenerate in incremental mode
   - This ensures all cross-references and the MOC are consistent

Report the vault changes to the user.

## Edge Cases

- **No vault exists**: Inform the user that a vault is required for this workflow. Suggest running `/cpp-obsidian-vault` first to generate one, then retry.

- **Vault is incomplete** (missing traceability matrix or requirements): Read whatever vault notes exist. Fall back to scanning source code directly for the symptom-related areas. Proceed with diagnosis but note that the fix will be less traceable.

- **Multiple root causes**: If the symptom has more than one independent root cause, identify each one separately. Present all in the fix plan. Fix them in dependency order (lower-level causes first).

- **Not a bug — feature request**: If analysis reveals the behavior matches all requirements (the system works as specified), inform the user this is a feature gap, not a bug. Suggest using `/spec-to-vault` to add a new requirement, then `/vault-driven-dev` to implement it.

- **Test-only bug** (tests fail but code is correct): If the code satisfies the requirement but the test is wrong, fix the test file only. Update the `vault/tests/` note if the test structure changed.

- **Build / configuration bug**: If the issue is in `CMakeLists.txt`, compiler flags, or dependencies — this is outside the vault's scope. Diagnose and fix directly. Update `vault/00_Project Overview.md` if a new build dependency was added.

- **Third-party library bug**: If the root cause is in an external library (not project code), document it as a known issue in the relevant REQ file's `## Known Issues` section. Propose a workaround in project code if feasible.

- **Regression**: If the bug was introduced by a recent change, use `git log` and `git diff` to identify the introducing commit. Read the vault notes for the affected area to understand the original intent. Fix the regression while preserving the original design.

- **Heisenbug** (non-deterministic): Focus on thread safety markers in class notes. Check for missing mutexes, race conditions in `std::atomic` usage, and Qt cross-thread signal connections (`Qt::QueuedConnection`). Document the race condition in the relevant design note.
