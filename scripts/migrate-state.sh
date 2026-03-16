#!/bin/bash
# =============================================================================
# extract-state.sh
#
# Extracts specific resources from a monolithic Terraform state file and
# generates a filtered JSON file. Does NOT push anything - you review first,
# then push manually when ready.
#
# Usage:  ./extract-state.sh <state.json> <resources.txt>
# Output: filtered-state-<YYYYMMDD-HHMMSS>.json in current directory
# =============================================================================
set -euo pipefail

# ---- VALIDATE PARAMS ----
# Ensure both arguments are provided: the full state file and the resource list
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <state.json> <resources.txt>"
  exit 1
fi

STATE_FILE=$(realpath "$1")   # Full terraform state (terraform state pull > state.json)
RESOURCES_FILE="$2"           # Text file with one resource per line

# Fail early if either file doesn't exist
[[ ! -f "$STATE_FILE" ]] && echo "Error: state file not found: $STATE_FILE" && exit 1
[[ ! -f "$RESOURCES_FILE" ]] && echo "Error: resources file not found: $RESOURCES_FILE" && exit 1

# ---- BUILD JQ FILTER ----
# Converts each line in resources.txt into a jq condition.
# The final filter will be: select( (cond1) or (cond2) or ... )
#
# Supports two formats:
#   "type.name"                        -> root resource (no module)
#   "module.mod_name.type.name[...]"   -> module resource (index is stripped)
build_jq_condition() {
  local resource="$1"

  if [[ "$resource" == module.* ]]; then
    # Module resource - example: module.icl_dev.aws_iam_role.this["backend"]
    #   cut -d. -f1-2 -> "module.icl_dev"          (module path)
    #   cut -d. -f3   -> "aws_iam_role"             (resource type)
    #   cut -d. -f4   -> "this["backend"]" -> "this" (name, strip index)
    local mod type name
    mod=$(echo "$resource" | cut -d. -f1-2)
    type=$(echo "$resource" | cut -d. -f3)
    name=$(echo "$resource" | cut -d. -f4 | cut -d'[' -f1)
    echo "(.module == \"$mod\" and .type == \"$type\" and .name == \"$name\")"
  else
    # Root resource - example: aws_iam_policy.my_policy
    #   cut -d. -f1 -> "aws_iam_policy"  (resource type)
    #   cut -d. -f2 -> "my_policy"       (resource name)
    # .module == null prevents accidentally matching a module resource
    # that happens to share the same type.name
    local type name
    type=$(echo "$resource" | cut -d. -f1)
    name=$(echo "$resource" | cut -d. -f2)
    echo "(.module == null and .type == \"$type\" and .name == \"$name\")"
  fi
}

# Read resources.txt line by line, skip comments (#) and blank lines,
# and chain all conditions with "or" into a single jq filter string
JQ_FILTER=""
while IFS= read -r resource; do
  [[ -z "$resource" || "$resource" == \#* ]] && continue
  condition=$(build_jq_condition "$resource")
  if [[ -z "$JQ_FILTER" ]]; then
    JQ_FILTER="$condition"
  else
    JQ_FILTER="$JQ_FILTER or $condition"
  fi
done < "$RESOURCES_FILE"

# If resources.txt was empty or only had comments, there's nothing to extract
[[ -z "$JQ_FILTER" ]] && echo "Error: no valid resources in $RESOURCES_FILE" && exit 1

# ---- EXTRACT ----
# Apply the filter to the full state file.
# Keeps the entire state structure (version, serial, terraform_version, etc.)
# but replaces .resources[] with only the matching ones.
# This preserves format compatibility for `terraform state push`.
OUTPUT_FILE="filtered-state-$(date +%Y%m%d-%H%M%S).json"

jq '.resources = [.resources[] | select('"$JQ_FILTER"')]' "$STATE_FILE" > "$OUTPUT_FILE"

# ---- VERIFY ----
# Compare unique resources requested (txt) vs found (state).
# Lines like this["backend"] and this["tfstate"] are instances of the
# same resource (type.name), so we deduplicate by stripping the index
# before counting. The jq filter already captures all instances.

# Strip index ["..."] and deduplicate to get unique resource names
TXT_COUNT=$(grep -vE '^\s*#|^\s*$' "$RESOURCES_FILE" | sed 's/\[.*\]$//' | sort -u | wc -l | xargs)
STATE_COUNT=$(jq '.resources | length' "$OUTPUT_FILE")

echo "=== Extracted ==="
jq -r '.resources[] | (if .module then .module + "." else "" end) + .type + "." + .name' "$OUTPUT_FILE"
echo ""
echo "Unique resources expected: $TXT_COUNT | Found in state: $STATE_COUNT"

# Also show total instances (including indexed) for full picture
INSTANCE_COUNT=$(jq '[.resources[].instances | length] | add' "$OUTPUT_FILE")
INSTANCE_TXT_COUNT=$(grep -cvE '^\s*#|^\s*$' "$RESOURCES_FILE" || echo 0)
echo "Total instances expected:  $INSTANCE_TXT_COUNT | Found in state: $INSTANCE_COUNT"

# Compare deduplicated resource names to find truly missing resources
if [[ "$TXT_COUNT" != "$STATE_COUNT" ]]; then
  echo ""
  echo "MISMATCH - missing resources:"
  grep -vE '^\s*#|^\s*$' "$RESOURCES_FILE" | sed 's/\[.*\]$//' | sort -u | while IFS= read -r resource; do
    found=$(jq -r '.resources[] | (if .module then .module + "." else "" end) + .type + "." + .name' "$OUTPUT_FILE" | grep -cF "$resource" || true)
    [[ "$found" -eq 0 ]] && echo "  MISSING: $resource"
  done
fi

# ---- DONE ----
# The script stops here. No push. Review the JSON, then push manually.
echo ""
echo "Output: $OUTPUT_FILE"
echo "Next: review the file, then push with:"
echo "  terraform -chdir=<stack-dir> state push -force $OUTPUT_FILE"
