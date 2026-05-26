# generate_audio

Batch generates WAV audio for Krishna stories using Sarvam AI's Bulbul v2 TTS.

## Setup

```bash
pip install requests rich boto3
```

For R2 uploads, copy `.env.example` to `.env` and fill in your Cloudflare R2 credentials.
`.env` is gitignored.

## Usage

```bash
# Estimate cost without calling the API
python generate.py estimate

# Audition all v2 voices on one Hindi story (~₹19 / $0.22 total).
# Share audition/*.wav with reviewers, pick a winner.
python generate.py audition --api-key=$SARVAM_API_KEY

# Smoke test: one category, Hindi only, with the chosen voice
python generate.py run --api-key=$SARVAM_API_KEY \
    --langs=hu --only-category=1 --voice=<winner>

# Dry run: show planned tasks
python generate.py run --api-key=$SARVAM_API_KEY --dry-run

# Full Hindi batch with the chosen voice
python generate.py run --api-key=$SARVAM_API_KEY \
    --langs=hu --voice=<winner> --concurrency=2

# Upload all hu_*.opus files to Cloudflare R2
# Reads credentials from .env (see .env.example)
python generate.py upload --langs=hu
```

## Behavior

- Reads `../../assets/krishna_story_detail.json`.
- Generates `gu` and `hu` only (English uses on-device TTS; Sanskrit unsupported by Sarvam).
- Picks a random voice from the Bulbul v2 pool per story; reuses the same voice across both languages of that story.
- Output: `audio_out/{lang}_{category}_{story}.wav` (zero-padded).
- Resume-safe: `audio_out/.progress.json` tracks `text_sha256`, voice, and timestamp. Re-running skips done files; regenerates if source text changed.
- Live TUI shows the last 12 completed files (file, voice, chars, chunks, cost, time, status), a progress bar with ETA, and running totals (spent so far, estimated total cost).
- Human-readable log appended to `audio_out/generate.log`, one line per file with timestamp and full details.

## Voice pool (Bulbul v2)

`anushka`, `manisha`, `vidya`, `arya`, `abhilash`, `karun`, `hitesh`

## Notes

- Long stories are chunked at ~500 chars on sentence boundaries; chunks are sent in one API call (Sarvam returns parallel audios) and concatenated locally via Python's `wave` module.
- On 429/5xx: exponential backoff (1s, 2s, 4s, 8s, 16s) then fails that file. Other files continue.
- `audio_out/` and `.progress.json` are gitignored.
