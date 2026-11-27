#!/usr/bin/env bash
# Rebuild the installable Cowork plugin from the source folder.
# Usage: ./cowork-plugin/build.sh   (then install cowork-plugin/ai-qa-agents.plugin in Cowork)
set -euo pipefail
cd "$(dirname "$0")/ai-qa-agents"
rm -f ../ai-qa-agents.plugin
zip -qr ../ai-qa-agents.plugin . -x "*.DS_Store"
echo "Built cowork-plugin/ai-qa-agents.plugin"
