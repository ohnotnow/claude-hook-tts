#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HISTORY_FILE="${SCRIPT_DIR}/claude-hook-history.txt"

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')
TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')

if [ "$EVENT" = "Stop" ]; then
    PROMPT="Generate a short, snarky 5-10 word notification that you (Claude) have finished a task. Think 'Marvin the Paranoid Android' style."
elif [ "$EVENT" = "Notification" ]; then
    PROMPT="Generate a short, snarky 5-10 word notification that you (Claude) are waiting for input. Type: $TYPE. Think 'Marvin the Paranoid Android' style."
else
    exit 0
fi

RECENT=""
if [ -f "$HISTORY_FILE" ]; then
    RECENT=$(cat "$HISTORY_FILE")
fi

EXTRA="Do not use Emoji. Your response will be read aloud by a text-to-speech system."
FULL_PROMPT="$PROMPT $EXTRA Do not use any of these recent phrases:
$RECENT
Just return the message, nothing else."

tts() {
    local text="$1"
    local response=$(curl --silent --show-error https://api.replicate.com/v1/models/minimax/speech-02-turbo/predictions \
        --request POST \
        --header "Authorization: Bearer $REPLICATE_API_TOKEN" \
        --header "Content-Type: application/json" \
        --header "Prefer: wait" \
        --data "$(jq -n --arg t "$text" '{
            "input": {
                "text": $t,
                "emotion": "sad",
                "language_boost": "Danish",
                "english_normalization": true
            }
        }')")
    
    local audio_url=$(echo "$response" | jq -r '.output')
    if [ -n "$audio_url" ] && [ "$audio_url" != "null" ]; then
        curl -s "$audio_url" -o /tmp/tts-output.mp3
        afplay /tmp/tts-output.mp3
    fi
}


# Get the snarky message from Claude
JSON_PAYLOAD=$(jq -n \
    --arg content "$FULL_PROMPT" \
    '{
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 50,
        "messages": [{"role": "user", "content": $content}]
    }')

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$JSON_PAYLOAD")

MESSAGE=$(echo "$RESPONSE" | jq -r '.content[0].text')
echo "$RESPONSE" >> /tmp/responses.log

echo "$MESSAGE" >> "$HISTORY_FILE"
tail -n 10 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

# Use TTS instead of say
tts "$MESSAGE" &

