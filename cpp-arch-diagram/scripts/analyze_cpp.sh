#!/bin/bash
# analyze_cpp.sh - Scan C++ source files and output a structured summary
# Usage: bash analyze_cpp.sh <directory>
#
# Outputs a structured summary of:
# - All .h/.hpp/.hxx/.cpp files found (excluding build artifacts)
# - Class/struct/enum definitions with inheritance
# - Abstract/interface class detection
# - Composition and aggregation relationships
# - Qt signals/slots markers
# - Thread safety markers
# - Callback patterns
# - Include relationships (project headers only)
# - CMake targets and dependencies

set -u

TARGET_DIR="${1:-.}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist." >&2
    exit 1
fi

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Helper: find source files excluding build artifacts and third-party code
find_sources() {
    find "$1" -type f \( -name "*.h" -o -name "*.hpp" -o -name "*.hxx" -o -name "*.cpp" \) \
        -not -path "*/build/*" \
        -not -path "*/cmake-build-*/*" \
        -not -path "*/out/*" \
        -not -path "*/.vscode/*" \
        -not -path "*/autogen/*" \
        -not -path "*/third_party/*" \
        -not -path "*/external/*" \
        -not -path "*/vendor/*" \
        -not -path "*moc_*" \
        -not -path "*qrc_*" \
        -not -path "*CMakeCXXCompilerId*" \
        2>/dev/null | sort
}

# Helper: check if an include path refers to a project header
is_project_include() {
    local included="$1"
    # Skip system includes (angle brackets already filtered by caller)
    # Check if any file with this basename exists in our project
    local base
    base="$(basename "$included")"
    echo "$KNOWN_HEADERS" | grep -qFx "$base"
}

echo "=== C++ Architecture Analysis: $TARGET_DIR ==="
echo ""

# --- File listing ---
echo "## Source Files"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rel_path="${file#$TARGET_DIR/}"
    echo "- $rel_path"
done
echo ""

# Count totals for size scaling hint
total_files=$(find_sources "$TARGET_DIR" | wc -l)
header_files=$(find_sources "$TARGET_DIR" | grep -cE '\.(h|hpp|hxx)$' || echo "0")
cpp_files=$(find_sources "$TARGET_DIR" | grep -cE '\.cpp$' || echo "0")
echo "**Total:** $total_files files ($header_files headers, $cpp_files implementations)"
echo ""

# --- Directory structure (portable: no associative arrays) ---
echo "## Directory Structure"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rel="${file#$TARGET_DIR/}"
    echo "$rel" | cut -d'/' -f1
done | sort | uniq -c | sort -rn | while read count dir; do
    echo "- **$dir/** ($count files)"
done
echo ""

# --- Build known headers set for include filtering ---
KNOWN_HEADERS=$(find_sources "$TARGET_DIR" | while IFS= read -r f; do
    [[ -n "$f" ]] && basename "$f"
done | sort -u)

# --- Class/struct/enum definitions ---
echo "## Class/Struct/Enum Definitions"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Only process header files
    case "$file" in
        *.h|*.hpp|*.hxx) ;;
        *) continue ;;
    esac
    rel_path="${file#$TARGET_DIR/}"

    # Extract class/struct/enum class definitions, excluding forward declarations
    # A forward declaration is a line like: class Foo;  or  struct Bar;
    grep -nE '^\s*(class|struct|enum\s+class)\s+[A-Za-z_]' "$file" 2>/dev/null | \
    grep -vE ';\s*$' | while IFS= read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        content=$(echo "$match" | cut -d: -f2-)

        # Skip preprocessor directive lines
        echo "$content" | grep -qE '^\s*#' && continue

        # Determine kind
        kind=""
        if echo "$content" | grep -qE 'enum\s+class'; then
            kind="enum class"
        elif echo "$content" | grep -qE '\bstruct\b'; then
            kind="struct"
        else
            kind="class"
        fi

        # Extract name
        if [[ "$kind" == "enum class" ]]; then
            name=$(echo "$content" | sed -n 's/.*enum\s\+class[[:space:]]\+\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p')
        else
            name=$(echo "$content" | sed -n "s/.*$kind[[:space:]]\+\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p")
        fi
        [[ -z "$name" ]] && continue

        # Check for inheritance (first public base on same line)
        parent=$(echo "$content" | sed -n 's/.*:[[:space:]]*public[[:space:]]\+\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p')

        # Check for abstract class: look for pure virtual (virtual ... = 0;) within class body
        is_abstract=""
        if [[ "$kind" == "class" || "$kind" == "struct" ]]; then
            if awk "/^[[:space:]]*(class|struct)[[:space:]]+$name/,/^[[:space:]]*};/" "$file" 2>/dev/null | grep -qE 'virtual[[:space:]].*=[[:space:]]*0[[:space:]]*;' ; then
                is_abstract=" [abstract]"
            fi
        fi

        if [[ -n "$parent" ]]; then
            echo "- $kind \`$name\` extends \`$parent\`${is_abstract} ($rel_path:$line_num)"
        else
            echo "- $kind \`$name\`${is_abstract} ($rel_path:$line_num)"
        fi
    done
done
echo ""

# --- Composition & member variables ---
echo "## Composition & Aggregation"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    case "$file" in *.h|*.hpp|*.hxx) ;; *) continue ;; esac
    rel_path="${file#$TARGET_DIR/}"

    # unique_ptr / shared_ptr composition
    grep -nE 'std::(unique_ptr|shared_ptr)<[[:space:]]*[A-Za-z_]' "$file" 2>/dev/null | \
    grep -vE '^\s*//' | while IFS= read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        content=$(echo "$match" | cut -d: -f2-)
        ptr_kind=$(echo "$content" | sed -n 's/.*std::\(unique_ptr\|shared_ptr\).*/\1/p')
        ptr_type=$(echo "$content" | sed -n 's/.*std::\(unique_ptr\|shared_ptr\)<[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\).*/\2/p')
        [[ -z "$ptr_type" ]] && continue
        echo "- **$rel_path**: composition via \`$ptr_kind<$ptr_type>\` (:$line_num)"
    done

    # Raw pointer members (potential aggregation) - skip void* (opaque handles)
    # Only match lines that look like member variable declarations (end with ; or _suffix)
    grep -nE '^\s+[A-Za-z_][A-Za-z0-9_:]*\*[[:space:]]+[a-zA-Z_]' "$file" 2>/dev/null | \
    grep -vE '^\s*//|void\s*\*|^\s*friend\s|^\s*\*' | \
    grep -vE '\(' | while IFS= read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        content=$(echo "$match" | cut -d: -f2-)
        ptr_type=$(echo "$content" | sed -n 's/.*[[:space:]]\+\([A-Za-z_][A-Za-z0-9_:]*\)\*[[:space:]]\+.*/\1/p')
        member=$(echo "$content" | sed -n 's/.*\*[[:space:]]\+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/p')
        [[ -z "$ptr_type" || -z "$member" ]] && continue
        echo "- **$rel_path**: aggregation \`$ptr_type* $member\` (:$line_num)"
    done
done
echo ""

# --- Qt signals/slots ---
echo "## Qt Signals/Slots"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    case "$file" in *.h|*.hpp|*.hxx) ;; *) continue ;; esac
    rel_path="${file#$TARGET_DIR/}"
    if grep -q 'Q_OBJECT' "$file" 2>/dev/null; then
        sig_count=$(grep -oE '^\s*signals\s*:' "$file" 2>/dev/null | wc -l)
        slot_count=$(grep -oE '\bslots\s*:' "$file" 2>/dev/null | wc -l)
        echo "- **$rel_path**: Q_OBJECT, $sig_count signal(s), $slot_count slot(s)"
    fi
done
echo ""

# --- Thread safety markers ---
echo "## Thread Safety Markers"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rel_path="${file#$TARGET_DIR/}"
    atomics=$(grep -oE 'std::atomic' "$file" 2>/dev/null | wc -l)
    mutexes=$(grep -oE 'std::mutex' "$file" 2>/dev/null | wc -l)
    threads=$(grep -oE 'std::thread' "$file" 2>/dev/null | wc -l)
    if [[ "$atomics" -gt 0 ]] || [[ "$mutexes" -gt 0 ]] || [[ "$threads" -gt 0 ]]; then
        echo "- **$rel_path**: $atomics atomic(s), $mutexes mutex(es), $threads thread(s)"
    fi
done
echo ""

# --- Callback patterns ---
echo "## Callback Patterns"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    case "$file" in *.h|*.hpp|*.hxx) ;; *) continue ;; esac
    rel_path="${file#$TARGET_DIR/}"
    grep -nE '(std::function|using.*Callback)' "$file" 2>/dev/null | \
    grep -vE '^\s*//' | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        line_num=$(echo "$line" | cut -d: -f1)
        content=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        echo "- **$rel_path**: $content (:$line_num)"
    done
done
echo ""

# --- Include relationships (project headers only) ---
echo "## Include Relationships (project headers)"
echo ""
find_sources "$TARGET_DIR" | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rel_path="${file#$TARGET_DIR/}"
    grep '^\s*#include\s*"' "$file" 2>/dev/null | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        included=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/')
        if is_project_include "$included"; then
            echo "- **$rel_path** -> $included"
        fi
    done
done
echo ""

# --- CMake targets and dependencies ---
echo "## CMake Targets"
echo ""
cmake_found=false
find "$TARGET_DIR" -name "CMakeLists.txt" \
    -not -path "*/build/*" \
    -not -path "*/third_party/*" \
    -not -path "*/external/*" \
    -not -path "*/vendor/*" \
    2>/dev/null | while IFS= read -r cmake; do
    rel="${cmake#$TARGET_DIR/}"

    # Extract project() declarations
    grep -iE '^\s*project\s*\(' "$cmake" 2>/dev/null | while IFS= read -r line; do
        proj=$(echo "$line" | sed -n 's/.*project[[:space:]]*([[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/Ip')
        ver=$(echo "$line" | sed -n 's/.*VERSION[[:space:]]\+\([A-Za-z0-9.]*\).*/\1/Ip')
        [[ -n "$proj" ]] && echo "- **$rel**: project($proj${ver:+ v$ver})"
    done

    # Extract targets (add_executable, add_library)
    grep -iE '^\s*(add_executable|add_library)\s*\(' "$cmake" 2>/dev/null | while IFS= read -r line; do
        target_type=$(echo "$line" | sed -n 's/.*\(add_executable\|add_library\).*/\1/Ip')
        target_name=$(echo "$line" | sed -n 's/.*\(add_executable\|add_library\)[[:space:]]*([[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\).*/\2/Ip')
        [[ -n "$target_name" ]] && echo "- $target_type: $target_name ($rel)"
    done

    # Extract link relationships
    grep -iE '^\s*target_link_libraries\s*\(' "$cmake" 2>/dev/null | while IFS= read -r line; do
        target=$(echo "$line" | sed -n 's/.*target_link_libraries[[:space:]]*([[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/Ip')
        deps=$(echo "$line" | sed "s/.*target_link_libraries[[:space:]]*([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*//;s/)[[:space:]]*$//")
        [[ -n "$target" ]] && echo "- $target links: $deps"
    done
done
if [[ $(find "$TARGET_DIR" -name "CMakeLists.txt" -not -path "*/build/*" -not -path "*/third_party/*" 2>/dev/null | wc -l) -eq 0 ]]; then
    echo "- No CMakeLists.txt found"
fi
echo ""

echo "=== End of Analysis ==="
echo "(Total files: $total_files)"
