---
name: cpp-obsidian-vault
description: Generate an Obsidian-compatible knowledge vault from a C++ project, connecting requirements to design to implementation with wikilinks and traceability. Supports both initial generation and incremental updates. Should be used when the user asks to "generate obsidian vault", "knowledge graph", "traceability matrix", "link requirements to code", "obsidian docs", "knowledge vault", or "update vault".
version: 0.3.0
---

# C++ Obsidian Knowledge Vault Generator

Generate and maintain an Obsidian-compatible knowledge vault that connects requirements to design to implementation to tests. Supports **incremental updates** — the vault itself becomes the source of truth for requirements and design, with code scans used to keep implementation notes in sync.

## Invocation

When triggered, look for an existing `vault/` directory at the project root. If one exists, operate in **incremental mode** (update existing notes, add new ones). If not, operate in **initial generation mode** (create from scratch).

## Initial Generation Mode

### Step 1: Discover Project Artifacts

Scan for:
- **Spec documents**: Numbered `.md` files at project root (e.g., `0_SPEC.md`, `1_UI.md`, `2_Arch.md`, `3_UT.md`)
- **Source files**: `.h` and `.cpp` files under `code/` or `src/` directories
- **Test files**: `.cpp` files under `tests/` directories
- **Build files**: `CMakeLists.txt` for project metadata

### Step 2: Extract Requirements

Parse each spec document section by section. Assign sequential IDs:

| Source Document | ID Pattern | Example |
|----------------|-----------|---------|
| `0_SPEC.md` (core spec) | `REQ-NNN` | REQ-001, REQ-020 |
| `1_UI.md` (UI design) | `REQ-UI-NNN` | REQ-UI-001 |
| `3_UT.md` (unit tests) | `REQ-UT-NNN` | REQ-UT-001 |

Each spec section (component responsibility, API method, UI element, interaction step, future feature) becomes a discrete requirement note.

### Step 3: Extract Design Decisions

From the architecture document, identify:
- Design patterns (Observer, Strategy, Singleton, etc.)
- Architectural patterns (Layered, MVC, Clean Architecture)
- Thread safety strategies
- Interface segregation decisions

Assign `DES-NNN` IDs.

### Step 4: Generate Class Notes

For each class/struct found in source files, create a note containing:
- Doxygen `@brief` description
- Public API method table
- Thread safety markers (`std::atomic`, `std::mutex`)
- Composition relationships (`unique_ptr`, raw pointers)
- Qt signals/slots (if applicable)
- Links to requirements, design decisions, and tests

### Step 5: Generate Flow Notes

Extract Mermaid diagrams from the architecture document. Create one note per flow (initialization, processing, lifecycle, etc.) with the diagram and a description of each step.

### Step 6: Generate Test Notes

From the test documentation, create one note per test suite containing:
- Suite name and test count
- Table of test cases with names and validation targets
- Links to the implementation classes and requirements they cover

### Step 7: Generate MOC and Traceability Matrix

**MOC.md**: Map of Content — vault entry point with organized wikilinks to all notes. Include a **Business Requirements** section at the top (before "Requirements") if `vault/business/` exists. Include a **Specs** section if `vault/specs/` exists.

**Traceability Matrix.md**: Complete table linking every requirement to its design decisions, implementation classes/files, and test coverage. Add a **BR** column linking to the parent business requirement when available:

```markdown
| BR | REQ | Description | DES | IMPL | TEST |
|----|-----|-------------|-----|------|------|
| [[BR-001]] | [[REQ-110]] | CSV export | [[DES-008]] | [[CsvExporter]] | [[CsvExporter Tests]] |
```

For REQs without a business parent, leave the BR column empty (`—`).

---

## Incremental Update Mode

When a `vault/` directory already exists, operate differently:

### Step 1: Read Existing Vault

1. Read `vault/MOC.md` to understand current vault structure
2. Read `vault/Traceability Matrix.md` for current traceability
3. Scan all existing notes in `vault/` to build an index
4. Scan `vault/business/` for BR notes (if directory exists)
5. Scan `vault/specs/` for SPEC notes (if directory exists)

### Step 2: Scan Source Code for Changes

1. Discover all `.h` and `.cpp` files under `code/` or `src/`
2. For each **implementation/ class** note, re-scan the corresponding source file
3. Compare current code against what the note describes:
   - New methods added → update the note
   - Methods removed → remove from note
   - New classes/files → create new notes
   - Removed classes/files → mark notes as deprecated
4. Update implementation notes accordingly

### Step 3: Update from Existing Vault Requirements

1. Read all notes in `vault/requirements/` — these are the **source of truth** for requirements
2. If new requirements were added to the vault since last generation (identified by new REQ IDs not in the traceability matrix), incorporate them
3. If requirements were edited by the user, preserve those edits

### Step 4: Update from Existing Vault Design

1. Read all notes in `vault/design/` — these are the **source of truth** for design
2. If new design decisions were added, incorporate them
3. If design was updated by the user, preserve those edits

### Step 5: Update Test Notes

1. Scan test files for new test cases
2. Update `vault/tests/` notes accordingly
3. Add links from requirements to new tests where applicable

### Step 5b: Update Business and Spec Notes (Incremental)

If `vault/business/` and `vault/specs/` exist:

1. For each BR note, verify its `## Derived Requirements` links point to existing REQ files
2. For each SPEC note, verify its `## Derived Requirements` links are valid
3. If a REQ referenced by a BR/SPEC has been deleted, flag it in the BR/SPEC note
4. Include BR and SPEC notes in the MOC regeneration

### Step 5c: Migrate Stale Source References (One-Time)

For each note in `vault/requirements/`:

1. Check the `source:` field in YAML frontmatter
2. If `source:` matches `0_SPEC.md`, `1_UI.md`, `2_Arch.md`, or `3_UT.md`:
   - Update to `source: legacy-spec:<original-path>` (e.g., `legacy-spec:0_SPEC.md#3.3`)
   - This preserves the reference while indicating the source document was archived
3. If `source:` references `doc/architecture.md`, keep as-is (current location)

### Step 6: Regenerate MOC and Traceability Matrix

Always regenerate these two files to reflect the current state of all notes.

## Vault Structure

```
vault/
├── MOC.md                          # Entry point (auto-generated)
├── Traceability Matrix.md          # BR → REQ → DES → IMPL → TEST (auto-generated)
├── 00_Project Overview.md          # Summary
├── business/                       # Business requirements (BR-NNN)
│   └── BR-001.md ...
├── specs/                          # Specification notes (SPEC-NNN)
│   └── SPEC-001.md ...
├── requirements/
│   ├── REQ-001.md ...              # Core requirements
│   ├── REQ-UI-001.md ...           # UI requirements
│   └── REQ-UT-001.md ...           # Test requirements
├── design/
│   ├── DES-001.md ...              # Design patterns
├── implementation/
│   ├── classes/                    # Class notes
│   ├── structs/                    # Struct notes
│   └── entry-points/               # main() etc.
├── tests/                          # Test suite notes
├── flows/                          # Flow diagrams
└── diagrams/                       # Architecture diagrams
```

## Note Conventions

### Frontmatter

Every note has YAML frontmatter:

```yaml
---
id: REQ-025
type: requirement
status: implemented
source: 0_SPEC.md#3.3
category: core
---
```

Types: `requirement`, `design`, `implementation`, `test`, `flow`, `diagram`, `business-requirement`, `spec`

Status values: `implemented`, `partial`, `planned`, `deprecated`

### Wikilinks

Use human-readable names:
- Classes: `[[MyService]]`
- Design: `[[Thread Safety Strategy]]`
- Requirements: `[[REQ-025]]`
- Tests: `[[MyService Tests]]`

### Tags

| Category | Tags |
|----------|------|
| Type | `#requirement` `#design` `#implementation` `#test` `#flow` `#diagram` |
| Layer | `#presentation` `#application` `#domain` `#infrastructure` |
| Status | `#implemented` `#partial` `#planned` `#deprecated` |
| Pattern | `#observer` `#singleton` `#strategy` `#thread-safe` `#layered` |

## Output

Write all notes to `vault/` directory. In incremental mode, preserve user edits to notes — only update sections that have changed due to code changes. Notes should be self-contained but heavily cross-linked so Obsidian's graph view shows meaningful connections.
