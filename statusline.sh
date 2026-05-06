#!/bin/bash
# Instructions: Place this script in ~/.claude/, run `chmod +x ./statusline.sh`, then modify your settings.json file to add it. Ask Claude otherwise.

input=$(cat)

DIR=$(echo "$input" | jq -r '.workspace.current_dir // empty')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')

CTX_WINDOW=200000
CTX_TOTAL=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    CTX_TOTAL=$(jq -rs '
        [ .[]
          | select(.type=="assistant")
          | select(.isSidechain != true)
          | .message.usage
          | select(. != null)
          | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
        ] as $t
        | if ($t | length) == 0 then 0 else $t[-1] end
    ' "$TRANSCRIPT" 2>/dev/null)
    [ -z "$CTX_TOTAL" ] && CTX_TOTAL=0
fi

GREEN='\033[38;5;108m'
RED='\033[38;5;167m'
TRACK='\033[38;5;238m'
DIM='\033[2m'
RESET='\033[0m'

BAR_WIDTH=6

render_metric() {
    local label="$1" pct_raw="$2"
    [ -z "$pct_raw" ] && { printf '%s: %s—%s' "$label" "$DIM" "$RESET"; return; }

    local pct
    pct=$(printf '%.0f' "$pct_raw")

    local color="$GREEN"
    [ "$pct" -ge 85 ] && color="$RED"

    local halves=$(( (pct * BAR_WIDTH * 2 + 50) / 100 ))
    local max_halves=$((BAR_WIDTH * 2))
    [ "$halves" -gt "$max_halves" ] && halves=$max_halves
    local full=$((halves / 2))
    local half=$((halves % 2))
    local empty=$((BAR_WIDTH - full - half))

    local filled=""
    [ "$full" -gt 0 ] && printf -v f "%${full}s" && filled="${f// /█}"
    [ "$half" -gt 0 ] && filled="${filled}▌"
    local track=""
    [ "$empty" -gt 0 ] && printf -v e "%${empty}s" && track="${e// /░}"

    printf '%s: %b%s%b%b%s%b %b%d%%%b' "$label" "$color" "$filled" "$RESET" "$TRACK" "$track" "$RESET" "$color" "$pct" "$RESET"
}

FOLDER="${DIR##*/}"
[ -z "$FOLDER" ] && FOLDER="~"

SESSION=$(render_metric "session" "$FIVE_H")
WEEKLY=$(render_metric "week" "$WEEK")

CTX_PCT=$(awk -v t="$CTX_TOTAL" -v w="$CTX_WINDOW" 'BEGIN{printf "%.1f", (t/w)*100}')
CTX_HUMAN=$(awk -v t="$CTX_TOTAL" 'BEGIN{
    if (t < 1000) printf "%d", t;
    else if (t < 1000000) printf "%.1fk", t/1000;
    else printf "%.1fM", t/1000000;
}')
CTX_COLOR="$GREEN"
CTX_PCT_INT=$(printf '%.0f' "$CTX_PCT")
[ "$CTX_PCT_INT" -ge 85 ] && CTX_COLOR="$RED"
CTX="🧠 ${CTX_COLOR}${CTX_HUMAN}${RESET} ${DIM}(${CTX_PCT}%)${RESET}"

printf '%b📁 %s%b  |  %b  |  %b  |  %b\n' "$DIM" "$FOLDER" "$RESET" "$SESSION" "$WEEKLY" "$CTX"
