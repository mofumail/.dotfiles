#!/bin/bash
# Create a new workspace (next global ID) on the current monitor.
# If already on the highest workspace and it's empty, do nothing (stick).

ACTIVE=$(hyprctl activeworkspace -j)
CURRENT_WS=$(echo "$ACTIVE" | jq '.id')
CURRENT_WINDOWS=$(echo "$ACTIVE" | jq '.windows')

# Max workspace ID globally (excluding special/negative workspaces)
MAX_WS=$(hyprctl workspaces -j | jq '[.[] | select(.id > 0) | .id] | max')

# Already on the highest workspace and it's empty — stick
if [ "$CURRENT_WS" -eq "$MAX_WS" ] && [ "$CURRENT_WINDOWS" -eq 0 ]; then
    exit 0
fi

# Create and switch to next workspace (opens on focused monitor)
hyprctl dispatch workspace "$((MAX_WS + 1))"
