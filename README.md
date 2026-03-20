# notion-team-dashboard

Auto-generate a weekly activity dashboard from your team's Notion workspace. Powered by [Claude Code](https://claude.com/claude-code) CLI and the [Notion MCP Server](https://github.com/makenotion/notion-mcp-server).

**Zero backend. Zero database. Just one shell script → one HTML file.**

```
generate_dashboard.sh
  → Claude Code CLI (claude --print)
    → Notion MCP tools (search, fetch)
      → Collects per-member activity
    → Writes dashboard.html
```

## What You Get

A self-contained HTML dashboard with:

- **Stats overview** — active projects, team members, deadlines, pages updated
- **Deadline tracker** — upcoming deadlines with countdown
- **Project cards** — task progress (done / doing / todo) per project
- **Member cards** — expandable cards showing each member's weekly activity with direct Notion links
- **Activity timeline** — chronological view of all workspace changes
- **Dark theme** — modern, responsive layout; no external dependencies

## Prerequisites

| Requirement | Notes |
|---|---|
| [Claude Code CLI](https://claude.com/claude-code) | `claude` command on PATH |
| [Node.js](https://nodejs.org/) ≥ 18 | For running the Notion MCP server via `npx` |
| Python 3 | For config parsing (pre-installed on macOS/Linux) |
| A Notion workspace | With an [internal integration](#step-1-create-a-notion-integration) |

## Setup

### Step 1: Create a Notion Integration

1. Go to [notion.so/my-integrations](https://www.notion.so/my-integrations)
2. Click **"+ New integration"**
3. Fill in:
   - **Name**: e.g. `Team Dashboard`
   - **Associated workspace**: select your workspace
   - **Capabilities**: enable **Read content**, **Read comments**, **Read user information**
4. Click **Submit** → copy the **Internal Integration Secret** (starts with `ntn_...`)

### Step 2: Share Pages with the Integration

In Notion, for each top-level page you want the dashboard to track:

1. Open the page → click **"..."** (top right) → **"Connections"**
2. Search for your integration name (e.g. `Team Dashboard`)
3. Click **Confirm**

> The integration can only see pages explicitly shared with it (and their sub-pages).

### Step 3: Configure Claude Code with Notion MCP

Add the Notion MCP server to your Claude Code settings.

**Option A: Global settings** (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "notion": {
      "command": "npx",
      "args": ["-y", "@notionhq/notion-mcp-server"],
      "env": {
        "OPENAPI_MCP_HEADERS": "{\"Authorization\": \"Bearer ntn_YOUR_TOKEN_HERE\", \"Notion-Version\": \"2022-06-28\"}"
      }
    }
  }
}
```

**Option B: Project settings** (`.claude/settings.json` in the repo):

Same format as above. This keeps the MCP config scoped to this project. Note: the token is in an env var, so treat this file as sensitive (it's `.gitignore`'d by default).

> Replace `ntn_YOUR_TOKEN_HERE` with your actual integration token from Step 1.

### Step 4: Install & Configure

```bash
git clone https://github.com/YOUR_USERNAME/notion-team-dashboard.git
cd notion-team-dashboard

# Create your config
cp config.example.json config.json
```

Edit `config.json` with your team info:

```jsonc
{
  "team_name": "My Research Lab",      // shown in dashboard header
  "team_url": "",                       // optional: team website URL
  "output_path": "./dashboard.html",    // where to write the dashboard
  "lookback_days": 7,                   // how many days back to scan

  "workspace": {
    // Optional: if you have a Notion database for interns/students,
    // put its collection ID here. Find it via notion-search.
    "intern_db_collection": ""
  },

  "members": {
    "graduate": {
      "Alice Kim": {
        "role": "PhD",
        "focus": "Machine Learning",
        "notion_page": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "alt_name": "김앨리스"           // optional: alternative name for search
      }
    },
    "staff": {
      "Bob Lee": {
        "role": "Research Engineer"
      }
    },
    "interns": {
      "Carol Park": {
        "since": "2026-01",
        "notion_page": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      }
    }
  }
}
```

#### Finding Notion Page IDs

A Notion page ID is the 32-character hex string in any Notion URL:

```
https://www.notion.so/My-Page-Title-abc123def456...
                                     ^^^^^^^^^^^^^^^^
                                     This is the page ID
```

Or use Claude Code interactively:

```bash
claude
> Search Notion for "Alice Kim" using notion-search
```

### Step 5: Run

```bash
# Generate the dashboard
./generate_dashboard.sh

# Preview
open dashboard.html    # macOS
xdg-open dashboard.html  # Linux
```

**Dry-run mode** (prints the prompt without calling Claude):

```bash
./generate_dashboard.sh --dry-run
```

## Scheduling (Optional)

### macOS — launchd (recommended)

1. Edit `com.notion-team-dashboard.plist`:
   - Update the script path to your installation directory
   - Update log paths if desired

2. Install:
   ```bash
   cp com.notion-team-dashboard.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.notion-team-dashboard.plist
   ```

3. To unload:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.notion-team-dashboard.plist
   ```

By default it runs every **Friday at 9:00 AM**. Edit the `StartCalendarInterval` in the plist to change.

### Linux / WSL — cron

```bash
crontab -e
# Add (every Friday at 9 AM):
0 9 * * 5 /path/to/notion-team-dashboard/generate_dashboard.sh
```

## Configuration Reference

| Field | Required | Description |
|---|---|---|
| `team_name` | Yes | Display name for your team in the dashboard header |
| `team_url` | No | Team website URL; if provided, Claude will fetch it for additional context |
| `output_path` | Yes | Path for the generated HTML file (relative to script dir or absolute) |
| `lookback_days` | No | Number of days to look back for activity (default: 7) |
| `workspace.intern_db_collection` | No | Notion collection ID for an intern/student database (format: `collection://UUID`) |
| `members.graduate` | No | Map of graduate student names → `{role, focus, notion_page?, alt_name?}` |
| `members.staff` | No | Map of staff names → `{role}` |
| `members.interns` | No | Map of intern names → `{since, notion_page?}` |

### Member Fields

| Field | Description |
|---|---|
| `role` | Position label: `PhD`, `MS`, `Postdoc`, `Research Engineer`, etc. |
| `focus` | Research area / team (shown as tag in dashboard) |
| `notion_page` | UUID of the member's top-level Notion page (enables deep sub-page search) |
| `alt_name` | Alternative name for Notion user search (e.g., name in another language) |
| `since` | Start date for interns (YYYY-MM format) |

## How Activity Detection Works

The dashboard uses a **timestamp-based strategy** instead of creation date filtering, because `created_date_range` only catches new pages and misses edits to existing ones.

1. **Database search** (if `intern_db_collection` is set) — queries the database, checks the `timestamp` field (= last modified time)
2. **Sub-page search** — for each member with a `notion_page` ID, searches within their page tree using the `page_url` parameter
3. **User-based search** — searches the workspace with `created_by_user_ids` to find pages created by each member, then filters by modification timestamp

This combination catches both new pages and edits to existing ones within the lookback window.

## Project Structure

```
notion-team-dashboard/
├── generate_dashboard.sh          # Main script — builds prompt, runs Claude
├── config.example.json            # Config template (copy to config.json)
├── config.json                    # Your config (gitignored)
├── com.notion-team-dashboard.plist  # macOS scheduler template
├── LICENSE                        # MIT
└── .gitignore
```

## Troubleshooting

### "Invalid API key" error
- Verify your Notion token in Claude Code's MCP settings
- Make sure the token starts with `ntn_`
- Ensure the integration is still active at [notion.so/my-integrations](https://www.notion.so/my-integrations)

### No activity detected for a member
- Check that the member's pages are **shared with the integration** (Step 2)
- Verify the `notion_page` ID in config is correct
- Try searching manually: `claude -p "Search Notion for 'MemberName' using notion-search"`

### Claude CLI not found
- Install Claude Code: [claude.com/claude-code](https://claude.com/claude-code)
- Ensure `claude` is on your PATH

### Dashboard is empty or minimal
- The integration can only see pages explicitly shared with it
- Share the top-level workspace pages or the relevant team pages with the integration

## License

MIT — see [LICENSE](LICENSE).
