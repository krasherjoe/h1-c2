# -*- coding: utf-8 -*-
"""MCP server for h1-core Gmail transport layer.

Provides tools for OpenCode to query sync status, error reports, backups,
and perform housekeeping via the Gmail API.
"""

import datetime
import os
import pickle
import re
from typing import Any, Sequence

import anyio
import mcp.server.stdio
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from mcp.server import Server
from mcp.server.models import InitializationOptions
from mcp.types import (
    CallToolResult,
    TextContent,
    Tool,
)

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]
SERVER = Server("h1-core-gmail-sync")

CREDENTIALS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "credentials")
CLIENT_SECRET_FILE = os.path.join(CREDENTIALS_DIR, "client_id.json")
TOKEN_FILE = os.path.join(CREDENTIALS_DIR, "token.pickle")

_LABELS_TO_ENSURE = ["Sync-Processed", "Sync-Error", "Sent-PDF-H1"]


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def get_gmail_service():
    """Authenticate and return a Gmail API service instance."""
    if not os.path.exists(CLIENT_SECRET_FILE):
        print(
            "ERROR: credentials/client_id.json not found.\n\n"
            "To set up Gmail API access:\n"
            "  1. Go to https://console.cloud.google.com/apis/credentials\n"
            "  2. Create a Desktop application OAuth 2.0 Client ID\n"
            "  3. Download the JSON and save it as:\n"
            f"     {CLIENT_SECRET_FILE}\n"
        )
        raise FileNotFoundError(f"Missing OAuth client ID file: {CLIENT_SECRET_FILE}")

    creds = None
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, "rb") as f:
            creds = pickle.load(f)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                CLIENT_SECRET_FILE, SCOPES
            )
            creds = flow.run_local_server(port=0)
        with open(TOKEN_FILE, "wb") as f:
            pickle.dump(creds, f)

    return build("gmail", "v1", credentials=creds)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _search_messages(service, query: str, max_results: int = 100) -> list[dict]:
    """Run a Gmail search and return message metadata."""
    try:
        result = (
            service.users()
            .messages()
            .list(userId="me", q=query, maxResults=max_results)
            .execute()
        )
        messages = result.get("messages", [])
        return messages
    except HttpError as e:
        return []


def _get_message_details(service, msg_id: str) -> dict | None:
    """Fetch full message metadata including subject and snippet."""
    try:
        msg = (
            service.users()
            .messages()
            .get(userId="me", id=msg_id, format="metadata")
            .execute()
        )
        return msg
    except HttpError:
        return None


def _get_header(headers: list[dict], name: str) -> str:
    for h in headers:
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def _hours_ago(hours: int) -> str:
    """Return Gmail search timestamp string for N hours ago."""
    t = datetime.datetime.utcnow() - datetime.timedelta(hours=hours)
    return t.strftime("%Y/%m/%d")


def _days_ago(days: int) -> str:
    t = datetime.datetime.utcnow() - datetime.timedelta(days=days)
    return t.strftime("%Y/%m/%d")


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

TOOLS: list[Tool] = [
    Tool(
        name="get_sync_status",
        description="Get count of [Sync:v2] messages in the last 24 hours, grouped by entity type",
        inputSchema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    Tool(
        name="get_errors",
        description="Get [Error:h1-core] messages from the last N hours (default 48)",
        inputSchema={
            "type": "object",
            "properties": {
                "hours": {
                    "type": "integer",
                    "description": "Hours to look back (default 48)",
                    "default": 48,
                }
            },
            "required": [],
        },
    ),
    Tool(
        name="get_backup_list",
        description="List [Backup] messages with subjects and dates",
        inputSchema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    Tool(
        name="count_pdf_labels",
        description="Count messages with the Sent-PDF-H1 label",
        inputSchema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    Tool(
        name="trigger_gc_dry_run",
        description="Simulate garbage collection: count messages that WOULD be deleted",
        inputSchema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    Tool(
        name="mark_as_read",
        description="Mark messages matching a Gmail search query as read",
        inputSchema={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Gmail search query to match messages",
                }
            },
            "required": ["query"],
        },
    ),
    Tool(
        name="ensure_labels",
        description="Create required Gmail labels if they don't exist",
        inputSchema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
]


@SERVER.list_tools()
async def handle_list_tools() -> list[Tool]:
    return TOOLS


@SERVER.call_tool()
async def handle_call_tool(
    name: str, arguments: dict | None
) -> CallToolResult:
    try:
        service = get_gmail_service()
    except FileNotFoundError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=str(e))],
            isError=True,
        )

    if name == "get_sync_status":
        return await _get_sync_status(service)
    elif name == "get_errors":
        hours = (arguments or {}).get("hours", 48)
        return await _get_errors(service, hours)
    elif name == "get_backup_list":
        return await _get_backup_list(service)
    elif name == "count_pdf_labels":
        return await _count_pdf_labels(service)
    elif name == "trigger_gc_dry_run":
        return await _trigger_gc_dry_run(service)
    elif name == "mark_as_read":
        query = (arguments or {}).get("query", "")
        return await _mark_as_read(service, query)
    elif name == "ensure_labels":
        return await _ensure_labels(service)
    else:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Unknown tool: {name}")],
            isError=True,
        )


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

async def _get_sync_status(service) -> CallToolResult:
    since = _days_ago(1)
    query = f"subject:[Sync:v2] after:{since}"
    messages = _search_messages(service, query)
    total = len(messages)

    entity_counts: dict[str, int] = {}
    for msg_summary in messages:
        detail = _get_message_details(service, msg_summary["id"])
        if detail is None:
            continue
        subject = _get_header(detail.get("payload", {}).get("headers", []), "Subject")
        # Subject format: [Sync:v2] entityType:action:entityId
        parts = subject.split()
        if len(parts) >= 2:
            body = parts[1]
            entity_type = body.split(":")[0] if ":" in body else "unknown"
        else:
            entity_type = "unknown"
        entity_counts[entity_type] = entity_counts.get(entity_type, 0) + 1

    entity_lines = "\n".join(
        f"  - {k}: {v}" for k, v in sorted(entity_counts.items())
    )
    text = (
        f"Sync status (last 24h)\n"
        f"  Total messages: {total}\n"
        f"  By entity type:\n{entity_lines}"
    )
    return CallToolResult(content=[TextContent(type="text", text=text)])


async def _get_errors(service, hours: int) -> CallToolResult:
    since = _hours_ago(hours)
    query = f"subject:[Error:h1-core] after:{since}"
    messages = _search_messages(service, query, max_results=200)
    total = len(messages)
    lines = [f"Errors in last {hours}h: {total} found\n"]

    for msg_summary in messages[:50]:
        detail = _get_message_details(service, msg_summary["id"])
        if detail is None:
            continue
        headers = detail.get("payload", {}).get("headers", [])
        subject = _get_header(headers, "Subject")
        snippet = detail.get("snippet", "")
        internal_date = detail.get("internalDate", "")
        if internal_date:
            dt = datetime.datetime.fromtimestamp(int(internal_date) / 1000)
            date_str = dt.strftime("%Y-%m-%d %H:%M:%S")
        else:
            date_str = "unknown"
        lines.append(f"[{date_str}] {subject}")
        lines.append(f"       {snippet}\n")

    text = "\n".join(lines)
    return CallToolResult(content=[TextContent(type="text", text=text)])


async def _get_backup_list(service) -> CallToolResult:
    query = "subject:[Backup]"
    messages = _search_messages(service, query, max_results=100)
    total = len(messages)
    lines = [f"Backup messages: {total} found\n"]

    for msg_summary in messages[:50]:
        detail = _get_message_details(service, msg_summary["id"])
        if detail is None:
            continue
        headers = detail.get("payload", {}).get("headers", [])
        subject = _get_header(headers, "Subject")
        internal_date = detail.get("internalDate", "")
        if internal_date:
            dt = datetime.datetime.fromtimestamp(int(internal_date) / 1000)
            date_str = dt.strftime("%Y-%m-%d %H:%M:%S")
        else:
            date_str = "unknown"
        lines.append(f"  [{date_str}] {subject}")

    text = "\n".join(lines)
    return CallToolResult(content=[TextContent(type="text", text=text)])


async def _count_pdf_labels(service) -> CallToolResult:
    try:
        result = (
            service.users()
            .labels()
            .list(userId="me")
            .execute()
        )
        labels = result.get("labels", [])
        target = None
        for lbl in labels:
            if lbl["name"] == "Sent-PDF-H1":
                target = lbl
                break

        if target is None:
            return CallToolResult(
                content=[TextContent(type="text", text="Label 'Sent-PDF-H1' not found.")]
            )

        # Count messages with this label
        res = (
            service.users()
            .messages()
            .list(userId="me", labelIds=[target["id"]], maxResults=500)
            .execute()
        )
        count = len(res.get("messages", []))
        return CallToolResult(
            content=[TextContent(type="text", text=f"Messages with Sent-PDF-H1 label: {count}")]
        )
    except HttpError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Error: {e}")],
            isError=True,
        )


async def _trigger_gc_dry_run(service) -> CallToolResult:
    now = datetime.datetime.utcnow()
    lines = ["Garbage Collection Dry Run\n"]

    # Sync messages older than 3 days
    sync_cutoff = (now - datetime.timedelta(days=3)).strftime("%Y/%m/%d")
    q_sync = f"subject:[Sync:v2] before:{sync_cutoff}"
    sync_msgs = _search_messages(service, q_sync, max_results=500)
    lines.append(f"Sync messages (>3d old):   {len(sync_msgs)} would be deleted")

    # Error messages older than 7 days
    err_cutoff = (now - datetime.timedelta(days=7)).strftime("%Y/%m/%d")
    q_err = f"subject:[Error:h1-core] before:{err_cutoff}"
    err_msgs = _search_messages(service, q_err, max_results=500)
    lines.append(f"Error messages (>7d old):  {len(err_msgs)} would be deleted")

    # BCC PDF receipts older than 14 days
    pdf_cutoff = (now - datetime.timedelta(days=14)).strftime("%Y/%m/%d")
    q_pdf = f"label:Sent-PDF-H1 before:{pdf_cutoff}"
    pdf_msgs = _search_messages(service, q_pdf, max_results=500)
    lines.append(f"PDF receipts (>14d old):   {len(pdf_msgs)} would be deleted")

    # Backup: keep newest 3
    q_backup = "subject:[Backup]"
    backup_msgs = _search_messages(service, q_backup, max_results=500)
    if len(backup_msgs) > 3:
        lines.append(
            f"Backup messages:           {len(backup_msgs) - 3} would be deleted "
            f"(keeping 3 of {len(backup_msgs)})"
        )
    else:
        lines.append(f"Backup messages:           0 would be deleted ({len(backup_msgs)} total, 3 kept)")

    lines.append("\nNo actual deletions performed.")
    text = "\n".join(lines)
    return CallToolResult(content=[TextContent(type="text", text=text)])


async def _mark_as_read(service, query: str) -> CallToolResult:
    messages = _search_messages(service, query, max_results=200)
    if not messages:
        return CallToolResult(
            content=[TextContent(type="text", text="No messages matched the query.")]
        )

    msg_ids = [m["id"] for m in messages]
    try:
        service.users().messages().batchModify(
            userId="me",
            body={
                "ids": msg_ids,
                "removeLabelIds": ["UNREAD"],
            },
        ).execute()
        return CallToolResult(
            content=[
                TextContent(
                    type="text",
                    text=f"Marked {len(msg_ids)} messages as read.",
                )
            ]
        )
    except HttpError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Error: {e}")],
            isError=True,
        )


async def _ensure_labels(service) -> CallToolResult:
    try:
        result = service.users().labels().list(userId="me").execute()
        existing = {lbl["name"]: lbl["id"] for lbl in result.get("labels", [])}
    except HttpError as e:
        return CallToolResult(
            content=[TextContent(type="text", text=f"Error listing labels: {e}")],
            isError=True,
        )

    status_lines = []
    for name in _LABELS_TO_ENSURE:
        if name in existing:
            status_lines.append(f"  {name}: already exists (id={existing[name]})")
        else:
            try:
                lbl = (
                    service.users()
                    .labels()
                    .create(
                        userId="me",
                        body={"name": name, "labelListVisibility": "labelShow", "messageListVisibility": "show"},
                    )
                    .execute()
                )
                status_lines.append(f"  {name}: created (id={lbl['id']})")
            except HttpError as e:
                status_lines.append(f"  {name}: ERROR - {e}")

    text = "Labels:\n" + "\n".join(status_lines)
    return CallToolResult(content=[TextContent(type="text", text=text)])


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

async def main():
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await SERVER.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="h1-core-gmail-sync",
                server_version="1.0.0",
            ),
        )


if __name__ == "__main__":
    anyio.run(main)
