#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HISTORY_FILE="${SCRIPT_DIR}/claude-hook-history.txt"
ENV_FILE="${SCRIPT_DIR}/.env"
LLM_MODEL="${LLM_MODEL:-anthropic/claude-haiku-4-5-20251001}"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')
TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')

if [ "$EVENT" = "Stop" ]; then
    PROMPT="Generate a short, snarky 5-10 word notification that you (Claude) have finished a task. Think 'Marvin the Paranoid Android' style, dripping with disdain and sarcasm about the mundane task you were given."
elif [ "$EVENT" = "Notification" ]; then
    PROMPT="Generate a short, snarky 5-10 word notification that you (Claude) are waiting for input. Type: $TYPE. Think 'Marvin the Paranoid Android' style, dripping with disdain and sarcasm about how ... 'excited' you will be to get input from the moron you are talking to."
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

require_env() {
    local var_name="$1"
    if [ -z "${!var_name}" ]; then
        echo "Missing required environment variable: $var_name" >&2
        exit 1
    fi
}

extract_chat_completion_text() {
    local response="$1"
    echo "$response" | jq -r '
        .choices[0].message.content |
        if type == "string" then
            .
        else
            map(select(.type == "text") | .text) | join("")
        end
    '
}

generate_message_anthropic() {
    local prompt="$1"
    local model="$2"

    require_env "ANTHROPIC_API_KEY"

    local json_payload
    json_payload=$(jq -n \
        --arg content "$prompt" \
        --arg model "$model" \
        '{
            "model": $model,
            "max_tokens": 50,
            "messages": [{"role": "user", "content": $content}]
        }')

    curl -s https://api.anthropic.com/v1/messages \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$json_payload"
}

generate_message_openai() {
    local prompt="$1"
    local model="$2"

    require_env "OPENAI_API_KEY"

    local json_payload
    json_payload=$(jq -n \
        --arg content "$prompt" \
        --arg model "$model" \
        '{
            "model": $model,
            "messages": [{"role": "user", "content": $content}],
            "max_completion_tokens": 50
        }')

    curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload"
}

generate_message_openrouter() {
    local prompt="$1"
    local model="$2"

    require_env "OPENROUTER_API_KEY"

    local json_payload
    json_payload=$(jq -n \
        --arg content "$prompt" \
        --arg model "$model" \
        '{
            "model": $model,
            "messages": [{"role": "user", "content": $content}],
            "max_tokens": 50
        }')

    curl -s https://openrouter.ai/api/v1/chat/completions \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_payload"
}

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
        TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        FILENAME="tts-output-$TIMESTAMP.mp3"
        curl -s "$audio_url" -o "/tmp/$FILENAME"
        afplay "/tmp/$FILENAME"
        # limit temp mp3s to 10 files
        mapfile -t OLD_FILES < <(ls -tr /tmp/tts-output-*.mp3 2>/dev/null | tail -n +11)
        if [ "${#OLD_FILES[@]}" -gt 0 ]; then
            rm "${OLD_FILES[@]}"
        fi
    fi
}


LLM_PROVIDER="${LLM_MODEL%%/*}"
LLM_NAME="${LLM_MODEL#*/}"

case "$LLM_PROVIDER" in
    anthropic)
        RESPONSE=$(generate_message_anthropic "$FULL_PROMPT" "$LLM_NAME")
        MESSAGE=$(echo "$RESPONSE" | jq -r '.content[0].text')
        ;;
    openai)
        RESPONSE=$(generate_message_openai "$FULL_PROMPT" "$LLM_NAME")
        MESSAGE=$(extract_chat_completion_text "$RESPONSE")
        ;;
    openrouter)
        RESPONSE=$(generate_message_openrouter "$FULL_PROMPT" "$LLM_NAME")
        MESSAGE=$(extract_chat_completion_text "$RESPONSE")
        ;;
    *)
        echo "Unsupported LLM provider in LLM_MODEL: $LLM_MODEL" >&2
        exit 1
        ;;
esac

echo "$RESPONSE" >> /tmp/responses.log

echo "$MESSAGE" >> "$HISTORY_FILE"
tail -n 10 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

# Use TTS instead of say
tts "$MESSAGE" &
