#!/bin/bash
# notion-team-dashboard — Weekly Dashboard Generator
# Runs Claude Code CLI to query Notion MCP and generate an HTML dashboard.
#
# Prerequisites:
#   - Claude Code CLI (`claude`) installed and on PATH
#   - Notion MCP configured in Claude Code settings (~/.claude/settings.json)
#   - config.json in the same directory (copy from config.example.json)
#
# Usage:
#   ./generate_dashboard.sh              # generate dashboard
#   ./generate_dashboard.sh --dry-run    # print prompt only, don't run claude

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
LOG_FILE="${SCRIPT_DIR}/dashboard_gen.log"

# Check config exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config.json not found. Copy config.example.json to config.json and customize."
  exit 1
fi

# Check claude CLI exists
if ! command -v claude &> /dev/null; then
  echo "ERROR: claude CLI not found. Install Claude Code first."
  exit 1
fi

# Read config values
TEAM_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('team_name', 'Team'))")
TEAM_URL=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('team_url', ''))")
INTERN_DB=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('workspace', {}).get('intern_db_collection', ''))")
LOOKBACK=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('lookback_days', 7))")
OUTPUT_PATH=$(python3 -c "import json,os; p=json.load(open('$CONFIG_FILE'))['output_path']; print(p if os.path.isabs(p) else os.path.join('$SCRIPT_DIR', p))")

# Build member page IDs from config
MEMBER_PAGES=$(python3 -c "
import json
cfg = json.load(open('$CONFIG_FILE'))
for section in ['interns', 'graduate']:
    for name, info in cfg['members'].get(section, {}).items():
        pid = info.get('notion_page', '')
        if pid:
            print(f'   - {name}: {pid}')
")

# Build member list for context
MEMBER_LIST=$(python3 -c "
import json
cfg = json.load(open('$CONFIG_FILE'))
for section in ['graduate', 'staff', 'interns']:
    for name, info in cfg['members'].get(section, {}).items():
        role = info.get('role', section)
        alt = info.get('alt_name', '')
        alt_str = f' (also known as: {alt})' if alt else ''
        print(f'   - {name}: {role}{alt_str}')
")

# Build optional team URL instruction
TEAM_URL_INSTRUCTION=""
if [ -n "$TEAM_URL" ]; then
  TEAM_URL_INSTRUCTION="
2. Optionally fetch team members from ${TEAM_URL} for additional context."
fi

# Build optional intern DB instruction
INTERN_DB_INSTRUCTION=""
if [ -n "$INTERN_DB" ]; then
  INTERN_DB_INSTRUCTION="
   a) Search the intern/student database for top-level pages:
      - notion-search with data_source_url \"${INTERN_DB}\"
      - The \"timestamp\" field in results = LAST MODIFIED time (not creation time)
      - Filter results where timestamp is within the last ${LOOKBACK} days

   b) For each active member page found, search WITHIN it using page_url parameter:
      - notion-search with page_url set to the member's top-level page ID
      - This reveals all sub-pages and their modification timestamps
      - Filter sub-pages where timestamp is within the last ${LOOKBACK} days"
fi

# Build the prompt
PROMPT="You have access to Notion MCP tools. Generate the ${TEAM_NAME} weekly dashboard HTML.

## Instructions

1. Determine the current date and calculate the date range (last ${LOOKBACK} days).
${TEAM_URL_INSTRUCTION}
3. Search Notion for each team member's user ID using the notion-search tool with query_type \"user\". Search by name (try alternative names if provided).

4. IMPORTANT - Activity detection strategy (do NOT use created_date_range filter, it only catches new pages):
${INTERN_DB_INSTRUCTION}
   c) For all members, search broadly in the workspace:
      - Use notion-search without date filters but with created_by_user_ids
      - Check the timestamp field (= last modified) to find recently modified pages

   d) Do NOT use created_date_range filter - it misses edits to existing pages!

5. For pages with recent timestamps (within last ${LOOKBACK} days), fetch key ones with notion-fetch to get:
   - Page title and content summary
   - Ancestor path (to identify the project and the person)
   - Any to-do items, deadlines, or progress markers
   - Focus on pages with substantial content, skip blank/placeholder pages

6. Team members:
${MEMBER_LIST}

7. Known member top-level page IDs (for page_url searches):
${MEMBER_PAGES}

8. Compile findings and write the dashboard HTML to ${OUTPUT_PATH}

The HTML should be a single self-contained file (no external dependencies) with:
- Dark theme, modern cards layout
- Header with team name (\"${TEAM_NAME}\"), date range, and generation timestamp
- Stats row (active projects, members, deadlines, pages updated)
- Upcoming deadlines section
- Project activity cards with task progress (done/doing/todo)
- Clickable member cards that expand to show detailed activity:
  - Updated pages with dates, descriptions, and Notion links (https://www.notion.so/{pageId})
  - To-do items where available
  - Inactive members show \"No activity detected this week\"
- Activity timeline (chronological)
- Use <details>/<summary> for expand/collapse, pure CSS/JS, no frameworks
- Footer with generation info

IMPORTANT: Write the complete HTML file using the Write tool to ${OUTPUT_PATH}"

# Dry run mode
if [ "${1:-}" = "--dry-run" ]; then
  echo "$PROMPT"
  exit 0
fi

echo "[$(date)] Starting dashboard generation..." >> "$LOG_FILE"

cd "$SCRIPT_DIR"

# Run claude
claude --print -p "$PROMPT" >> "$LOG_FILE" 2>&1

echo "[$(date)] Dashboard generation complete." >> "$LOG_FILE"
echo "Dashboard written to: ${OUTPUT_PATH}"
