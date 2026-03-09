# Claude Hook TTS

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) hook that announces notifications and task completions in the style of Marvin the Paranoid Android, with a melancholy text-to-speech voice.

> "Ugh. It works. Congratulations, the universe is still a disappointment."

## What it does

When Claude Code finishes a task or needs your attention, this hook asks an LLM to write a short, snarky notification in the style of Marvin from Hitchhiker's Guide. It then converts the message to speech using Replicate's TTS API and plays it aloud. You get to hear your robot assistant's existential despair while you code.

The script keeps track of recent messages to avoid repetition. Even a depressed robot has *some* standards.

Here are some real examples it has produced:

- *"Oh, joy. Another task completed. How utterly thrilling for all involved."*
- *"The code no longer offends me. How noble of it."*
- *"Oh, wonderful, another human has paused to breathe. How riveting. Proceed when your neurons align."*

## Requirements

- macOS (uses `afplay` for audio playback)
- [jq](https://jqlang.github.io/jq/) for JSON parsing
- An API key for one of the supported LLM providers (see below)
- A [Replicate API token](https://replicate.com/account/api-tokens) for text-to-speech
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed

## Getting started

Clone the repository and make the script executable:

```bash
git clone https://github.com/ohnotnow/claude-hook-tts.git
cd claude-hook-tts
chmod +x cc_tts_notification.sh
```

Create a `.env` file in the project root with your chosen LLM provider and API keys:

```bash
LLM_MODEL=openrouter/mistralai/mistral-small-creative
OPENROUTER_API_KEY=sk-or-...
REPLICATE_API_TOKEN=r8_...
```

You only need the API key for whichever provider you pick, plus `REPLICATE_API_TOKEN` for TTS.

Finally, add the hook to your Claude Code settings. Edit `~/.claude/settings.json`:

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

## Choosing an LLM provider

`LLM_MODEL` follows a `provider/model-name` pattern. The script routes requests to the right API based on the prefix:

| Provider | Example `LLM_MODEL` value | API key needed |
|----------|--------------------------|----------------|
| Anthropic | `anthropic/claude-haiku-4-5-20251001` | `ANTHROPIC_API_KEY` |
| OpenAI | `openai/gpt-4o-mini` | `OPENAI_API_KEY` |
| OpenRouter | `openrouter/mistralai/mistral-small-creative` | `OPENROUTER_API_KEY` |

If you don't set `LLM_MODEL`, it defaults to `anthropic/claude-haiku-4-5-20251001`.

[OpenRouter](https://openrouter.ai/) is worth a look -- it gives you access to loads of models through a single API key. Creative-writing-tuned models like `mistralai/mistral-small-creative` tend to produce better results here. They lean into the dramatic, despondent Marvin persona more than general-purpose models do. Your mileage may vary, but it's been good fun to experiment with.

## Configuration

You can set your API keys in the `.env` file (recommended) or as environment variables in your shell profile. The `.env` file is sourced first, so it takes priority.

The `.env` file is git-ignored, so your keys won't end up in version control.

### TTS settings

The script uses [minimax/speech-02-turbo](https://replicate.com/minimax/speech-02-turbo) on Replicate for text-to-speech, configured with "sad" emotion and a slight Danish accent. Don't ask. It just works for the vibe.

### History file

`claude-hook-history.txt` stores the last 10 generated messages so it avoids repeating itself. You can edit it by hand if you want to seed the style -- filling it with good examples helps steer the tone.

## Cost

Cheap to run. The LLM calls only generate 5-10 words each, so costs are fractions of a penny per notification. Replicate TTS is billed per character -- see [their pricing](https://replicate.com/pricing) for details.

## Licence

MIT. Do whatever you like with it. Marvin wouldn't care either way.
