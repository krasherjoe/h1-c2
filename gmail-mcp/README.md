# h1-core Gmail MCP Server

Gmail API-based MCP (Model Context Protocol) server for querying h1-core's Gmail
transport layer. Allows OpenCode to inspect sync status, error reports, backups,
and perform housekeeping via Gmail API.

## Tools

| Tool | Description |
|------|-------------|
| `get_sync_status` | Count [Sync:v2] messages in last 24h, grouped by entity type |
| `get_errors` | List [Error:h1-core] messages within a given hour window |
| `get_backup_list` | List [Backup] messages with subjects and dates |
| `count_pdf_labels` | Count messages with Sent-PDF-H1 label |
| `trigger_gc_dry_run` | Simulate garbage collection: what would be deleted |
| `mark_as_read` | Mark messages matching a query as read |
| `ensure_labels` | Create required Gmail labels if missing |

## Setup

```bash
# Quick setup
./setup.sh

# Or manually
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Then place `client_id.json` (Google OAuth desktop credentials) in
`credentials/` and run:

```bash
source venv/bin/activate
python gmail_mcp_server.py
```

## OAuth

1. Go to https://console.cloud.google.com/apis/credentials
2. Create Desktop application OAuth 2.0 Client ID
3. Download JSON and save as `credentials/client_id.json`
4. First run opens a browser for consent; token is cached in `credentials/token.pickle`

## opencode.json 登録

```json
{
  "mcp": {
    "gmail": {
      "type": "local",
      "command": ["/path/to/h-1-core/gmail-mcp/gmail_mcp_server.py"],
      "enabled": false
    }
  }
}
```

OAuth client_id.json を配置してから `enabled: true` に変更すること。
