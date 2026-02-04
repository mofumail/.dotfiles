#!/bin/bash
# Switch to the previous workspace on the current monitor.

ACTIVE=$(hyprctl activeworkspace -j)
CURRENT_WS=$(echo "$ACTIVE" | jq '.id')
CURRENT_MON=$(echo "$ACTIVE" | jq -r '.monitor')

# Get all workspace IDs on this monitor, sorted ascending, excluding special workspaces
PREV_WS=$(hyprctl workspaces -j | jq -r \
    --arg mon "$CURRENT_MON" --argjson cur "$CURRENT_WS" \
    '[.[] | select(.monitor == $mon and .id > 0 and .id < $cur) | .id] | sort | last')

if [ "$PREV_WS" != "null" ] && [ -n "$PREV_WS" ]; then
    hyprctl dispatch workspace "$PREV_WS"
fi
