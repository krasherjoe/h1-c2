#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Creating Python virtual environment..."
python3 -m venv "$DIR/venv"

echo "==> Activating venv and installing dependencies..."
source "$DIR/venv/bin/activate"
pip install --upgrade pip
pip install -r "$DIR/requirements.txt"

echo ""
echo "====================================="
echo "  Setup complete!"
echo "====================================="
echo ""
echo "Next steps:"
echo "  1. Go to https://console.cloud.google.com/apis/credentials"
echo "  2. Create a Desktop application OAuth 2.0 Client ID"
echo "  3. Download the JSON and save it as:"
echo "     $DIR/credentials/client_id.json"
echo "  4. Run the server:"
echo "     source $DIR/venv/bin/activate"
echo "     python $DIR/gmail_mcp_server.py"
echo ""
