# Claude Hook TTS

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) hook that announces notifications and task completions in the style of Marvin the Paranoid Android - complete with a melancholy text-to-speech voice.

> "I've finished your task. I won't pretend it brought me any joy."

## What it does

When Claude Code finishes a task or needs your attention, this hook:

1. Asks Claude (via the API) to generate a short, snarky notification in the style of Marvin from The Hitchhiker's Guide to the Galaxy
2. Converts the message to speech using Replicate's TTS API with a suitably despondent tone
3. Plays the audio so you can hear your robot assistant's existential despair

It also keeps track of recent messages to avoid repetition - even a depressed robot has *some* standards.

## Requirements

- macOS (uses `afplay` for audio playback)
- [jq](https://jqlang.github.io/jq/) for JSON parsing
- One LLM API key for your chosen provider:
  - [Anthropic API key](https://console.anthropic.com/)
  - [OpenAI API key](https://platform.openai.com/)
  - [OpenRouter API key](https://openrouter.ai/)
- A [Replicate API token](https://replicate.com/account/api-tokens)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ohnotnow/claude-hook-tts.git
   cd claude-hook-tts
   ```

2. Make the script executable:
   ```bash
   chmod +x cc_tts_notification.sh
   ```

3. Set your API keys as environment variables:
   ```bash
   export ANTHROPIC_API_KEY="your-anthropic-api-key"
   export OPENAI_API_KEY="your-openai-api-key"
   export OPENROUTER_API_KEY="your-openrouter-api-key"
   export REPLICATE_API_TOKEN="your-replicate-api-token"
   ```
   You only need the LLM key for the provider you choose, plus `REPLICATE_API_TOKEN`.
   (You'll likely want to add these to your shell profile)

4. Add the hook to your Claude Code settings. Edit `~/.claude/settings.json` and add:
   ```json
   {
     "hooks": {
       "Notification": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "/full/path/to/claude-hook-tts/cc_tts_notification.sh"
             }
           ]
         }
       ],
       "Stop": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "/full/path/to/claude-hook-tts/cc_tts_notification.sh"
             }
           ]
         }
       ]
     }
   }
   ```

## Configuration

The script uses a single configurable `LLM_MODEL` setting near the top of `cc_tts_notification.sh`:

```bash
LLM_MODEL="${LLM_MODEL:-anthropic/claude-haiku-4-5-20251001}"
```

This follows a LiteLLM-style `provider/model` pattern. Examples:

- `anthropic/claude-haiku-4-5-20251001`
- `openai/gpt-5`
- `openrouter/google/gemini-2.5-pro`

The script routes requests automatically based on the provider prefix:
- `anthropic/...` uses `ANTHROPIC_API_KEY`
- `openai/...` uses `OPENAI_API_KEY`
- `openrouter/...` uses `OPENROUTER_API_KEY`

The script also uses:
- **minimax/speech-02-turbo** on Replicate for TTS with a "sad" emotion and slight Danish accent (don't ask)

Feel free to tweak the prompt or TTS settings in the script to adjust the personality.

The claude-hook-history.txt history file is an example - if you edit it before using the script, haiku will pick up on the style.  It has a tendancy to 'reset to mean' so once in a while you might need to re-edit it.

If you want to use specific API keys just for this script to make tracking usage easier, you can create a `.env` file in the project root with values like:

```bash
LLM_MODEL=openrouter/google/gemini-2.5-pro
OPENROUTER_API_KEY=sk-or-...
REPLICATE_API_TOKEN=r8_...
```

The `.env` file is ignored by git, but use it at your own judgement.

## Cost

This is quite cheap to run:
- Claude Haiku API calls are fractions of a penny
- Replicate TTS is billed per character (see [their pricing](https://replicate.com/pricing))

## License

MIT - do whatever you like with it. Marvin wouldn't care either way.
