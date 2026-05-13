---
name: spec-to-vault
description: Bridge natural language business requirements to structured vault artifacts. Creates BR notes, SPEC notes, REQ files, and proposes design decisions. Updates the traceability matrix and MOC. Supports analysis-only mode. Use when the user asks to "add a requirement", "implement this feature", "what would this change", or pastes a business requirement for vault integration.
version: 0.1.0
---

# Spec-to-Vault — Business Requirement to Vault Bridge

Convert natural language business requirements into structured vault artifacts with full traceability.

## Invocation

When triggered, the user will provide a business requirement in natural language. Optionally they may specify a mode:
- **Default (full mode)**: Create all vault artifacts
- **Analysis-only** (`--analyze` or "what would this change"): Show impact analysis without creating files

## Workflow

### Step 1: Read Current Vault State

1. Read `vault/MOC.md` to understand current vault structure
2. Read `vault/Traceability Matrix.md` to build an index of all existing REQ IDs, DES IDs, and their statuses
3. Scan `vault/requirements/` to find the highest used ID in each category (REQ-NNN, REQ-UI-NNN, REQ-110+)
4. Scan `vault/design/` to find the highest used DES-NNN ID
5. Read `vault/00_Project Overview.md` for project context

### Step 2: Parse the Business Requirement

Analyze the user's input to identify:
- **Core business goal**: What problem is being solved and why
- **Functional sub-requirements**: Specific behaviors the system must support
- **Non-functional requirements**: Performance, reliability, security constraints
- **UI/UX requirements**: User interface changes, new screens, buttons, displays
- **Data/storage requirements**: File I/O, database, serialization needs

Extract acceptance criteria — observable, testable outcomes.

### Step 3: Assign IDs

Determine the next available IDs:

| Category | ID Pattern | How to find next |
|----------|-----------|------------------|
| Business Requirement | BR-NNN | Scan `vault/business/`, use max+1, start at BR-001 |
| Spec | SPEC-NNN | Scan `vault/specs/`, use max+1, start at SPEC-001 |
| Core requirement | REQ-NNN | Scan `vault/requirements/REQ-[0-9][0-9][0-9].md`, use max+1 |
| UI requirement | REQ-UI-NNN | Scan `vault/requirements/REQ-UI-*.md`, use max+1 |
| Future enhancement | REQ-110+ | If matches an existing planned REQ, reuse that ID |
| Design | DES-NNN | Scan `vault/design/DES-*.md`, use max+1 |

### Step 4: Create Business Requirement Note

**Directory**: `vault/business/`
**File**: `BR-NNN.md`

```yaml
---
id: BR-NNN
type: business-requirement
status: accepted
date-created: YYYY-MM-DD
date-updated: YYYY-MM-DD
---
```

```markdown
# BR-NNN — <Short Title>

## Business Context
<User's natural language description, refined for clarity>

## Acceptance Criteria
- <Observable outcome 1>
- <Observable outcome 2>

## Derived Requirements
- [[REQ-NNN]] — <title>
- [[REQ-NNN]] — <title>

## Status History
| Date | Change |
|------|--------|
| YYYY-MM-DD | Created |
```

### Step 5: Create Spec Note(s)

**Directory**: `vault/specs/`
**File**: `SPEC-NNN.md` (one per logical sub-spec, or one combined spec)

```yaml
---
id: SPEC-NNN
type: spec
status: active
date-created: YYYY-MM-DD
business-parent: [[BR-NNN]]
---
```

```markdown
# SPEC-NNN — <Title>

## Source
Derived from [[BR-NNN]]

## Specification
<Detailed specification text, decomposed from the business requirement>

## Derived Requirements
- [[REQ-NNN]] — <title>
- [[REQ-NNN]] — <title>
```

### Step 6: Create or Modify REQ Files

**Directory**: `vault/requirements/`

For each sub-requirement identified:

**If an existing REQ matches** (e.g., REQ-110 "CSV export" was already planned):
- Update the file: add `source: BR-NNN`, update description if needed, change `status: planned` → `status: active`
- Add to `## Design Decisions` and `## Implementation` sections if new info is available

**If a new REQ is needed**:
- Create `REQ-NNN.md` with:

```yaml
---
id: REQ-NNN
type: requirement
status: active
source: BR-NNN
category: core
date-created: YYYY-MM-DD
---
```

```markdown
# REQ-NNN — <Short Title>

## Description
<Detailed requirement description>

## Acceptance Criteria
- <Criterion 1>
- <Criterion 2>

## Design Decisions
- [[DES-NNN]] — <title> (if design exists or is proposed)

## Implementation
<!-- To be filled by vault-driven-dev -->

## Test Coverage
<!-- To be filled after implementation -->
```

**Category assignment rules:**
- Core logic / domain: REQ-045+ (next after REQ-044)
- New feature area: REQ-090+ (reserved for export/integration features)
- UI changes: REQ-UI-090+ (next after REQ-UI-080)
- Infrastructure: REQ-083+ (next after REQ-082)
- If an existing planned REQ (REQ-110 to REQ-116) matches, reuse that ID

### Step 7: Identify Design Impact

For each new/modified REQ:

1. **Check existing design**: Read `vault/design/DES-*.md` to see if existing design decisions cover the requirement.
   - Layered Architecture (DES-001) covers most structural decisions
   - Observer Pattern (DES-002) covers callback/signal needs
   - Thread Safety (DES-003) covers concurrent access
   - If an existing design applies, link it in the REQ file

2. **Propose new design if needed**: If the requirement introduces a pattern not covered by existing designs:
   - Create `vault/design/DES-NNN.md` with `status: proposed`
   - Include description, rationale, and affected layers

3. **Impact analysis summary**: Determine which code layers will need changes:
   - **Domain**: New types, new business logic, modified algorithms
   - **Infrastructure**: New file I/O, new SDK calls, new utilities
   - **Application**: New controller methods, new signals
   - **Presentation**: New UI elements, modified layouts

### Step 8: Update Traceability Matrix

Read `vault/Traceability Matrix.md` and add new rows for all new REQs:

```markdown
| REQ | Description | DES | IMPL | TEST | BR |
|-----|-------------|-----|------|------|-----|
| [[REQ-NNN]] | <title> | [[DES-NNN]] | — | — | [[BR-NNN]] |
```

For existing REQs that were modified (e.g., status changed), update their row if needed.

### Step 9: Update MOC

Read `vault/MOC.md` and add:

1. A **Business Requirements** section at the top (before "Requirements"):
```markdown
## Business Requirements
- [[BR-NNN]] — <title>
```

2. New entries under **Requirements** for any new REQ files
3. New entries under **Design Decisions** for any new DES files

### Step 10: Present Summary to User

Show a structured summary:

```markdown
## Requirement Analysis Complete

### Business Requirement Created
- [[BR-NNN]] — <title>

### Vault Artifacts Created/Modified
| File | Action | Description |
|------|--------|-------------|
| BR-NNN.md | CREATED | Business requirement |
| SPEC-NNN.md | CREATED | Specification |
| REQ-NNN.md | CREATED | Core requirement |
| REQ-UI-NNN.md | CREATED | UI requirement |
| REQ-110.md | MODIFIED | Status: planned → active |
| DES-NNN.md | CREATED (proposed) | New design decision |

### Impact Analysis
| Layer | Files Affected | Action |
|-------|---------------|--------|
| Domain | code/domain/X.h | NEW class |
| Infrastructure | code/infra/Y.h/cpp | NEW class |
| Application | code/application/RectCounterController.h | MODIFY |
| Presentation | code/presentation/MainWindow.h/cpp | MODIFY |

### Next Steps
Run `/vault-driven-dev` to implement these requirements.
```

## Analysis-Only Mode

When invoked with `--analyze` or "what would this change":
- Execute Steps 1, 2, 7 only
- Do NOT create or modify any files
- Present the impact analysis report showing what WOULD be created

## Edge Cases

- **Conflicting requirements**: If the new requirement contradicts an existing REQ or design, flag it with specific details and ask the user to resolve
- **Vague requirements**: If the business requirement is too high-level, suggest decomposition into specific sub-requirements
- **Duplicate detection**: If a similar requirement already exists, point it out and suggest updating rather than creating a new one
- **REQ-ID conflicts**: Always scan existing files before assigning IDs to avoid duplicates
- **No design coverage**: If no existing or proposed design covers the requirement, explicitly state that design work is needed before implementation
