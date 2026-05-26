#!/usr/bin/env python3
"""
Sarvam TTS batch generator for krishna_stories_app.

Reads stories from assets/krishna_story_detail.json, generates WAV audio
for Gujarati (gu) and Hindi (hu) via Sarvam's Bulbul v2 TTS API, and writes
files to audio_out/. Resume-safe via .progress.json.

Usage:
    pip install requests rich

    # Estimate cost (no API calls)
    python generate.py estimate

    # Dry run — show what would be generated
    python generate.py run --api-key=XXX --dry-run

    # Generate one category only (smoke test)
    python generate.py run --api-key=XXX --only-category=1

    # Full batch (resumes from .progress.json automatically)
    python generate.py run --api-key=XXX --concurrency=2
"""

from __future__ import annotations

import argparse
import base64
import concurrent.futures
import hashlib
import io
import json
import math
import os
import random
import signal
import sys
import threading
import time
import wave
from pathlib import Path

import shutil
import subprocess

import requests
from rich.console import Console, Group
from rich.live import Live
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    TextColumn,
    TimeElapsedColumn,
    TimeRemainingColumn,
)
from rich.table import Table


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_JSON = SCRIPT_DIR.parent.parent / "assets" / "krishna_story_detail.json"
DEFAULT_OUT = SCRIPT_DIR / "audio_out"
PROGRESS_FILE = DEFAULT_OUT / ".progress.json"
LOG_FILE = DEFAULT_OUT / "generate.log"

SARVAM_URL = "https://api.sarvam.ai/text-to-speech"
MODEL = "bulbul:v2"

VOICE_POOL = ["abhilash", "hitesh", "vidya", "anushka"]
# Seed for deterministic per-chapter voice assignment. Change only if you
# explicitly want a different shuffle across the whole batch.
CHAPTER_VOICE_SEED = 42

LANG_TO_SARVAM = {
    "gu": "gu-IN",
    "hu": "hi-IN",  # app's non-standard 'hu' -> Sarvam's hi-IN
}

# Sarvam pricing: Bulbul v2 = ₹15 per 10,000 chars
INR_PER_CHAR_V2 = 0.0015
INR_TO_USD = 1.0 / 84.0

# Sarvam caps each `inputs` element at 500 chars,
# and the `inputs` array at 3 items per call.
CHUNK_LIMIT = 500
MAX_INPUTS_PER_CALL = 3


_progress_lock = threading.Lock()
_shutdown = threading.Event()


def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("estimate", help="Count characters and estimate cost. No API calls.")
    e.add_argument("--input", type=Path, default=DEFAULT_JSON)

    r = sub.add_parser("run", help="Generate audio. Resumes from .progress.json.")
    r.add_argument("--api-key", required=True, help="Sarvam API subscription key")
    r.add_argument("--input", type=Path, default=DEFAULT_JSON)
    r.add_argument("--out", type=Path, default=DEFAULT_OUT)
    r.add_argument("--concurrency", type=int, default=2)
    r.add_argument("--only-category", type=int, default=None,
                   help="Only generate this category number (e.g. 1 for data1). Useful for smoke testing.")
    r.add_argument("--langs", default="gu,hu",
                   help="Comma-separated languages to generate. Default: gu,hu")
    r.add_argument("--dry-run", action="store_true",
                   help="Show planned tasks but don't call the API")
    r.add_argument("--voice", default=None,
                   help="Force a single voice for all files. If omitted, picks randomly "
                        "from the v2 pool (same voice reused across a story's languages).")

    vm = sub.add_parser("voice-map",
                        help="Show the deterministic voice assigned to each chapter.")
    vm.add_argument("--input", type=Path, default=DEFAULT_JSON)

    a = sub.add_parser("audition",
                       help="Generate one sample clip per Bulbul v2 voice for blind review.")
    a.add_argument("--api-key", required=True, help="Sarvam API subscription key")
    a.add_argument("--input", type=Path, default=DEFAULT_JSON)
    a.add_argument("--lang", default="hu", choices=list(LANG_TO_SARVAM),
                   help="Language for audition clips. Default: hu (Hindi)")
    a.add_argument("--story", default="1.1.2",
                   help="Story key from krishna_story_detail.json to use as audition text. "
                        "Default: 1.1.2 (first Hindi story)")
    a.add_argument("--out", type=Path, default=SCRIPT_DIR / "audition",
                   help="Output directory for audition clips")
    a.add_argument("--voices", default=",".join(VOICE_POOL),
                   help="Comma-separated voices to audition. Default: all v2 voices")

    u = sub.add_parser("upload", help="Upload .opus files to Cloudflare R2.")
    u.add_argument("--src", type=Path, default=DEFAULT_OUT,
                   help="Source directory containing .opus files")
    u.add_argument("--langs", default="hu",
                   help="Comma-separated langs to upload (matches filename prefix). Default: hu")
    u.add_argument("--version", default="v1",
                   help="Path prefix in bucket. Default: v1 -> v1/hu/01_01.opus")
    u.add_argument("--concurrency", type=int, default=8,
                   help="Parallel uploads. R2 handles this easily; safe up to ~32")
    u.add_argument("--env-file", type=Path, default=SCRIPT_DIR / ".env",
                   help="Path to .env file with R2 credentials. Default: ./.env")
    u.add_argument("--r2-account-id", default=None,
                   help="Override R2 account ID (else read from .env)")
    u.add_argument("--r2-bucket", default=None,
                   help="Override R2 bucket name (else read from .env)")
    u.add_argument("--r2-access-key", default=None,
                   help="Override R2 access key ID (else read from .env)")
    u.add_argument("--r2-secret", default=None,
                   help="Override R2 secret access key (else read from .env)")
    u.add_argument("--public-base-url", default=None,
                   help="Public r2.dev or custom-domain base, e.g. https://pub-xxx.r2.dev. "
                        "If set, prints sample URLs after upload.")
    u.add_argument("--dry-run", action="store_true",
                   help="List planned uploads, don't push anything")

    return p.parse_args()


def load_tasks(json_path: Path, langs: list[str], only_category: int | None):
    """Walk the JSON and yield (category_num, story_num, lang, text) tasks."""
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    lang_suffix = {"gu": "1", "hu": "2"}  # per app's story_list_screen.dart

    tasks = []
    for top_key, sub in data.items():
        if not isinstance(sub, dict):
            continue
        if not top_key.startswith("data"):
            continue
        try:
            cat = int(top_key[len("data"):])
        except ValueError:
            continue
        if only_category is not None and cat != only_category:
            continue

        for k, v in sub.items():
            if not isinstance(v, str) or not v.strip():
                continue
            parts = k.split(".")
            if len(parts) != 3:
                continue  # we only want lang variants, not the base english key
            try:
                story = int(parts[1])
            except ValueError:
                continue
            suffix = parts[2]
            for lang in langs:
                if lang_suffix.get(lang) == suffix:
                    tasks.append((cat, story, lang, v))
                    break
    return tasks


def cmd_estimate(args):
    tasks = load_tasks(args.input, ["gu", "hu"], None)
    by_lang = {"gu": [0, 0], "hu": [0, 0]}  # [files, chars]
    for cat, story, lang, text in tasks:
        by_lang[lang][0] += 1
        by_lang[lang][1] += len(text)

    print(f"{'Lang':<6}{'Files':>8}{'Chars':>14}")
    total_chars = 0
    for lang in ("gu", "hu"):
        files, chars = by_lang[lang]
        print(f"{lang:<6}{files:>8}{chars:>14,}")
        total_chars += chars
    print(f"{'Total':<6}{'':<8}{total_chars:>14,}")
    print()
    inr = total_chars * INR_PER_CHAR_V2
    print(f"Bulbul v2 cost: ₹{inr:,.2f}  (~${inr * INR_TO_USD:,.2f})")


def chunk_text(text: str) -> list[str]:
    """Split text into <=500-char chunks at sentence boundaries when possible."""
    if len(text) <= CHUNK_LIMIT:
        return [text]
    # Prefer Hindi/Gujarati danda (।), then ., then space.
    chunks = []
    remaining = text
    while len(remaining) > CHUNK_LIMIT:
        window = remaining[:CHUNK_LIMIT]
        cut = max(window.rfind("।"), window.rfind("."), window.rfind("?"), window.rfind("!"))
        if cut < CHUNK_LIMIT // 2:
            cut = window.rfind(" ")
        if cut <= 0:
            cut = CHUNK_LIMIT
        chunks.append(remaining[:cut + 1].strip())
        remaining = remaining[cut + 1:].lstrip()
    if remaining:
        chunks.append(remaining)
    return [c for c in chunks if c]


def call_sarvam(api_key: str, chunks: list[str], lang: str, speaker: str) -> list[bytes]:
    """Call Sarvam TTS. Returns list of WAV bytes (one per chunk). Retries on 429/5xx."""
    payload = {
        "inputs": chunks,
        "target_language_code": LANG_TO_SARVAM[lang],
        "speaker": speaker,
        "model": MODEL,
        "speech_sample_rate": 22050,
        "enable_preprocessing": True,
    }
    headers = {
        "api-subscription-key": api_key,
        "Content-Type": "application/json",
    }

    backoff = 1
    for attempt in range(5):
        if _shutdown.is_set():
            raise RuntimeError("shutdown")
        try:
            resp = requests.post(SARVAM_URL, json=payload, headers=headers, timeout=120)
        except requests.RequestException as e:
            if attempt == 4:
                raise
            time.sleep(backoff)
            backoff *= 2
            continue

        if resp.status_code == 200:
            audios = resp.json().get("audios", [])
            if len(audios) != len(chunks):
                raise RuntimeError(f"Sarvam returned {len(audios)} clips for {len(chunks)} chunks")
            return [base64.b64decode(a) for a in audios]

        if resp.status_code in (429, 500, 502, 503, 504):
            if attempt == 4:
                raise RuntimeError(f"Sarvam {resp.status_code} after 5 retries: {resp.text[:200]}")
            time.sleep(backoff)
            backoff *= 2
            continue

        # Non-retryable
        raise RuntimeError(f"Sarvam {resp.status_code}: {resp.text[:300]}")

    raise RuntimeError("unreachable")


def concat_wavs(wav_bytes_list: list[bytes]) -> bytes:
    """Concatenate multiple WAV byte blobs into one WAV (preserves format of the first)."""
    if len(wav_bytes_list) == 1:
        return wav_bytes_list[0]

    out_buf = io.BytesIO()
    with wave.open(io.BytesIO(wav_bytes_list[0]), "rb") as first:
        params = first.getparams()
        frames = [first.readframes(first.getnframes())]

    for wb in wav_bytes_list[1:]:
        with wave.open(io.BytesIO(wb), "rb") as w:
            frames.append(w.readframes(w.getnframes()))

    with wave.open(out_buf, "wb") as out:
        out.setparams(params)
        for fr in frames:
            out.writeframes(fr)
    return out_buf.getvalue()


def load_progress() -> dict:
    if PROGRESS_FILE.exists():
        try:
            with open(PROGRESS_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def save_progress(progress: dict):
    PROGRESS_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = PROGRESS_FILE.with_suffix(".json.tmp")
    with open(tmp, "w") as f:
        json.dump(progress, f, indent=2, ensure_ascii=False)
    tmp.replace(PROGRESS_FILE)


def story_id(cat: int, story: int) -> str:
    return f"{cat:02d}_{story:02d}"


def out_filename(out_dir: Path, lang: str, cat: int, story: int) -> Path:
    return out_dir / f"{lang}_{cat:02d}_{story:02d}.wav"


_chapter_voice_map: dict | None = None


def _build_chapter_voice_map(json_path: Path) -> dict:
    """Balanced, seeded shuffle of voices across chapters.
    Each voice gets ceil(N/len(pool)) or floor(N/len(pool)) chapters."""
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    chapters = sorted(
        int(k[len("data"):]) for k in data
        if k.startswith("data") and k[len("data"):].isdigit()
    )
    n = len(chapters)
    pool = VOICE_POOL
    # Repeat pool enough times, truncate to n, shuffle deterministically
    repeated = (pool * ((n + len(pool) - 1) // len(pool)))[:n]
    rng = random.Random(CHAPTER_VOICE_SEED)
    rng.shuffle(repeated)
    return dict(zip(chapters, repeated))


def chapter_voice(cat: int, json_path: Path = DEFAULT_JSON) -> str:
    """Voice assigned to this chapter under the balanced seeded shuffle."""
    global _chapter_voice_map
    if _chapter_voice_map is None:
        _chapter_voice_map = _build_chapter_voice_map(json_path)
    return _chapter_voice_map[cat]


def pick_voice(progress: dict, sid: str, cat: int, forced: str | None = None) -> str:
    """Forced voice wins; else reuse prior voice for this story;
    else deterministic seeded pick keyed to the chapter so all stories in a chapter share a voice."""
    if forced:
        return forced
    existing = progress.get(sid, {}).get("voice")
    if existing in VOICE_POOL:
        return existing
    return chapter_voice(cat)


def process_task(api_key: str, out_dir: Path, progress: dict,
                 cat: int, story: int, lang: str, text: str,
                 forced_voice: str | None = None) -> dict:
    """Generate one (cat, story, lang) file. Returns a result dict."""
    sid = story_id(cat, story)
    sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
    out_path = out_filename(out_dir, lang, cat, story)
    started = time.time()

    with _progress_lock:
        entry = progress.setdefault(sid, {})
        prior_lang = entry.get(lang)
        if prior_lang and prior_lang.get("sha256") == sha and out_path.exists():
            return {
                "status": "skip", "file": out_path.name, "voice": entry.get("voice", "-"),
                "chars": len(text), "chunks": 0, "cost_inr": 0.0, "elapsed": 0.0,
            }
        voice = pick_voice(progress, sid, cat, forced_voice)
        entry["voice"] = voice  # lock voice before either lang's file is written

    chunks = chunk_text(text)
    # Sarvam's `inputs` array caps at MAX_INPUTS_PER_CALL items per request,
    # so batch the chunks and concat the WAVs across batches.
    wav_list: list[bytes] = []
    for i in range(0, len(chunks), MAX_INPUTS_PER_CALL):
        batch = chunks[i:i + MAX_INPUTS_PER_CALL]
        wav_list.extend(call_sarvam(api_key, batch, lang, voice))
    combined = concat_wavs(wav_list)

    out_dir.mkdir(parents=True, exist_ok=True)
    tmp_path = out_path.with_suffix(".wav.tmp")
    with open(tmp_path, "wb") as f:
        f.write(combined)
    tmp_path.replace(out_path)

    # Encode Opus alongside WAV. Failure is non-fatal — WAV stays the source of truth.
    opus_path = encode_opus(out_path)
    opus_ok = opus_path is not None

    elapsed = time.time() - started
    with _progress_lock:
        progress[sid][lang] = {
            "sha256": sha,
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "chars": len(text),
            "chunks": len(chunks),
        }
        save_progress(progress)

    return {
        "status": "ok", "file": out_path.name, "voice": voice,
        "chars": len(text), "chunks": len(chunks),
        "cost_inr": len(text) * INR_PER_CHAR_V2, "elapsed": elapsed,
    }


_ffmpeg_warned = False


def encode_opus(wav_path: Path, bitrate: str = "24k") -> Path | None:
    """Encode wav_path to .opus next to it. Returns path or None if ffmpeg failed/missing.
    Prints a one-time warning if ffmpeg can't be found, so silent failures are noticed."""
    global _ffmpeg_warned
    if shutil.which("ffmpeg") is None:
        if not _ffmpeg_warned:
            sys.stderr.write(
                "WARNING: ffmpeg not found on PATH — Opus encoding is being skipped. "
                "WAV files will still be generated. To fix, ensure ffmpeg is on PATH "
                "for the Python you're running (try: `which ffmpeg` from this shell).\n"
            )
            _ffmpeg_warned = True
        return None
    opus_path = wav_path.with_suffix(".opus")
    tmp = opus_path.with_suffix(".opus.tmp")
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
             "-c:a", "libopus", "-b:a", bitrate, "-ac", "1",
             "-application", "voip", str(tmp)],
            check=True, capture_output=True,
        )
        tmp.replace(opus_path)
        return opus_path
    except subprocess.CalledProcessError as e:
        if tmp.exists():
            tmp.unlink()
        if not _ffmpeg_warned:
            sys.stderr.write(
                f"WARNING: ffmpeg failed for {wav_path.name}: "
                f"{e.stderr.decode('utf-8', errors='ignore')[:200]}\n"
            )
            _ffmpeg_warned = True
        return None


def open_log() -> "io.TextIOBase":
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    return open(LOG_FILE, "a", encoding="utf-8", buffering=1)


def log_line(log_fh, status: str, file: str, voice: str, chars: int,
             chunks: int, cost_inr: float, elapsed: float, error: str = ""):
    ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    cost = f"₹{cost_inr:.4f}"
    base = (f"{ts}  {status:<4}  {file:<22}  voice={voice:<9}  "
            f"chars={chars:>5}  chunks={chunks:>2}  cost={cost:<10}  elapsed={elapsed:5.2f}s")
    if error:
        base += f"  error={error}"
    log_fh.write(base + "\n")


def render_tui(recent_rows: list, totals: dict, total_pending: int) -> Group:
    table = Table(title="Sarvam TTS — recent files", expand=True)
    table.add_column("#", justify="right", style="dim", width=5)
    table.add_column("File", style="cyan")
    table.add_column("Voice", style="magenta")
    table.add_column("Chars", justify="right")
    table.add_column("Chunks", justify="right")
    table.add_column("Cost ₹", justify="right", style="green")
    table.add_column("Time", justify="right")
    table.add_column("Status", justify="center")

    for row in recent_rows[-12:]:
        status_color = {"ok": "green", "skip": "yellow", "fail": "red"}.get(row["status"], "white")
        table.add_row(
            str(row["idx"]),
            row["file"],
            row["voice"],
            f"{row['chars']:,}",
            str(row["chunks"]),
            f"{row['cost_inr']:.3f}",
            f"{row['elapsed']:.1f}s",
            f"[{status_color}]{row['status']}[/{status_color}]",
        )

    done = totals["ok"] + totals["skip"] + totals["fail"]
    spent = totals["cost_inr"]
    est_total = (spent / max(done, 1)) * total_pending if done > 0 else 0.0
    summary = (
        f"[bold]Progress:[/bold] {done}/{total_pending}    "
        f"[green]ok:[/green] {totals['ok']}    "
        f"[yellow]skip:[/yellow] {totals['skip']}    "
        f"[red]fail:[/red] {totals['fail']}    "
        f"[bold]spent:[/bold] ₹{spent:.2f}  (~${spent * INR_TO_USD:.2f})    "
        f"[dim]est. total: ₹{est_total:.2f}[/dim]"
    )
    return Group(table, summary)


def cmd_run(args):
    console = Console()
    langs = [l.strip() for l in args.langs.split(",") if l.strip()]
    for l in langs:
        if l not in LANG_TO_SARVAM:
            sys.exit(f"unsupported lang: {l} (supported: {list(LANG_TO_SARVAM)})")

    args.out.mkdir(parents=True, exist_ok=True)
    tasks = load_tasks(args.input, langs, args.only_category)
    progress = load_progress()

    # Pre-filter already-done tasks
    pending = []
    pre_skipped = 0
    for cat, story, lang, text in tasks:
        sid = story_id(cat, story)
        sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
        out_path = out_filename(args.out, lang, cat, story)
        entry = progress.get(sid, {}).get(lang)
        if entry and entry.get("sha256") == sha and out_path.exists():
            pre_skipped += 1
            continue
        pending.append((cat, story, lang, text))

    total_chars = sum(len(t[3]) for t in pending)
    est_inr = total_chars * INR_PER_CHAR_V2

    console.print(f"[bold]Tasks:[/bold] {len(tasks)} total, "
                  f"[yellow]{pre_skipped}[/yellow] already done, "
                  f"[cyan]{len(pending)}[/cyan] pending")
    console.print(f"[bold]Pending chars:[/bold] {total_chars:,}  "
                  f"(~₹{est_inr:,.2f} / ${est_inr * INR_TO_USD:,.2f})")
    console.print(f"[dim]Log file: {LOG_FILE}[/dim]")

    if args.dry_run:
        for cat, story, lang, text in pending[:20]:
            console.print(f"  would gen: {out_filename(args.out, lang, cat, story).name}  ({len(text)} chars)")
        if len(pending) > 20:
            console.print(f"  ... and {len(pending) - 20} more")
        return

    if not pending:
        console.print("[green]Nothing to do.[/green]")
        return

    def handle_sigint(signum, frame):
        _shutdown.set()
    signal.signal(signal.SIGINT, handle_sigint)

    log_fh = open_log()
    log_fh.write(f"\n--- run started {time.strftime('%Y-%m-%d %H:%M:%S')} "
                 f"({len(pending)} files, est ₹{est_inr:.2f}) ---\n")

    totals = {"ok": 0, "skip": 0, "fail": 0, "cost_inr": 0.0}
    recent_rows: list = []
    completed_idx = 0

    progress_bar = Progress(
        TextColumn("[bold blue]{task.description}"),
        BarColumn(),
        MofNCompleteColumn(),
        TextColumn("•"),
        TimeElapsedColumn(),
        TextColumn("•"),
        TimeRemainingColumn(),
        expand=True,
    )
    bar_task = progress_bar.add_task("Generating", total=len(pending))

    start = time.time()
    with Live(render_tui(recent_rows, totals, len(pending)), console=console,
              refresh_per_second=4, transient=False) as live:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as ex:
            futures = {
                ex.submit(process_task, args.api_key, args.out, progress, cat, story, lang, text, args.voice):
                    (cat, story, lang)
                for cat, story, lang, text in pending
            }
            for fut in concurrent.futures.as_completed(futures):
                cat, story, lang = futures[fut]
                completed_idx += 1
                try:
                    res = fut.result()
                    totals[res["status"]] += 1
                    totals["cost_inr"] += res["cost_inr"]
                    row = {"idx": completed_idx, **res}
                    recent_rows.append(row)
                    log_line(log_fh, res["status"], res["file"], res["voice"],
                             res["chars"], res["chunks"], res["cost_inr"], res["elapsed"])
                except Exception as e:
                    totals["fail"] += 1
                    fname = f"{lang}_{cat:02d}_{story:02d}.wav"
                    recent_rows.append({
                        "idx": completed_idx, "status": "fail", "file": fname,
                        "voice": "-", "chars": 0, "chunks": 0, "cost_inr": 0.0, "elapsed": 0.0,
                    })
                    log_line(log_fh, "fail", fname, "-", 0, 0, 0.0, 0.0, error=str(e))

                progress_bar.update(bar_task, advance=1)
                live.update(Group(render_tui(recent_rows, totals, len(pending)), progress_bar))

                if _shutdown.is_set():
                    for f in futures:
                        if not f.running() and not f.done():
                            f.cancel()

    elapsed = time.time() - start
    log_fh.write(f"--- run finished in {elapsed:.1f}s: "
                 f"ok={totals['ok']} skip={totals['skip']} fail={totals['fail']} "
                 f"cost=₹{totals['cost_inr']:.2f} ---\n")
    log_fh.close()

    console.print()
    console.print(f"[bold green]Done.[/bold green] "
                  f"ok={totals['ok']} skip={totals['skip']} fail={totals['fail']}  "
                  f"spent: ₹{totals['cost_inr']:.2f} (~${totals['cost_inr'] * INR_TO_USD:.2f})  "
                  f"in {elapsed:.1f}s")
    if totals["fail"]:
        console.print(f"[red]Re-run the command to retry failed files (resume is automatic).[/red]")


def cmd_voice_map(args):
    console = Console()
    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)
    chapters = sorted(
        int(k[len("data"):]) for k in data
        if k.startswith("data") and k[len("data"):].isdigit()
    )

    table = Table(title=f"Chapter → voice (seed={CHAPTER_VOICE_SEED}, pool={VOICE_POOL})")
    table.add_column("Chapter", justify="right")
    table.add_column("Voice", style="cyan")
    counts: dict = {v: 0 for v in VOICE_POOL}
    for cat in chapters:
        v = chapter_voice(cat)
        counts[v] += 1
        table.add_row(str(cat), v)
    console.print(table)
    console.print(f"[bold]Distribution:[/bold] " +
                  "  ".join(f"{v}={n}" for v, n in counts.items()))


def cmd_audition(args):
    console = Console()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)
    # Walk dataN dicts looking for the requested story key
    text = None
    for sub in data.values():
        if isinstance(sub, dict) and args.story in sub:
            text = sub[args.story]
            break
    if not text:
        sys.exit(f"story key {args.story!r} not found in {args.input}")

    voices = [v.strip() for v in args.voices.split(",") if v.strip()]
    for v in voices:
        if v not in VOICE_POOL:
            sys.exit(f"unknown voice {v!r}. v2 pool: {VOICE_POOL}")

    args.out.mkdir(parents=True, exist_ok=True)
    chars = len(text)
    total_cost = chars * INR_PER_CHAR_V2 * len(voices)

    console.print(f"[bold]Audition:[/bold] {len(voices)} voices × {chars} chars "
                  f"({args.lang}, story {args.story})")
    console.print(f"[bold]Cost:[/bold] ~₹{total_cost:.2f} (~${total_cost * INR_TO_USD:.3f})")
    console.print(f"[dim]Output dir: {args.out}[/dim]\n")

    chunks = chunk_text(text)
    for voice in voices:
        out_path = args.out / f"{voice}.wav"
        if out_path.exists():
            console.print(f"[yellow]skip[/yellow]  {out_path.name} already exists")
            continue
        started = time.time()
        try:
            wav_list: list[bytes] = []
            for i in range(0, len(chunks), MAX_INPUTS_PER_CALL):
                batch = chunks[i:i + MAX_INPUTS_PER_CALL]
                wav_list.extend(call_sarvam(args.api_key, batch, args.lang, voice))
            combined = concat_wavs(wav_list)
            tmp = out_path.with_suffix(".wav.tmp")
            with open(tmp, "wb") as f:
                f.write(combined)
            tmp.replace(out_path)
            elapsed = time.time() - started
            console.print(f"[green]ok[/green]    {out_path.name:<20} {elapsed:5.2f}s")
        except Exception as e:
            console.print(f"[red]fail[/red]  {voice}: {e}")

    console.print(f"\n[bold]Done.[/bold] Share these clips: [cyan]{args.out}[/cyan]")
    console.print(f"Once a winner is picked, run the full batch with: "
                  f"[dim]python3 generate.py run --api-key=... --langs={args.lang} "
                  f"--voice=<winner>[/dim]")


def load_env(path: Path) -> dict:
    """Minimal KEY=VALUE .env parser. Ignores comments and blank lines."""
    out: dict = {}
    if not path.exists():
        return out
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.strip().strip('"').strip("'")
        out[k.strip()] = v
    return out


def cmd_upload(args):
    console = Console()
    try:
        import boto3
        from botocore.config import Config
        from botocore.exceptions import ClientError
    except ImportError:
        sys.exit("boto3 not installed. Run: pip install boto3")

    env = load_env(args.env_file)
    account_id = args.r2_account_id or env.get("R2_ACCOUNT_ID")
    bucket = args.r2_bucket or env.get("R2_BUCKET")
    access_key = args.r2_access_key or env.get("R2_ACCESS_KEY_ID")
    secret = args.r2_secret or env.get("R2_SECRET_ACCESS_KEY")
    public_base = args.public_base_url or env.get("R2_PUBLIC_BASE_URL")

    missing = [name for name, val in [
        ("R2_ACCOUNT_ID", account_id), ("R2_BUCKET", bucket),
        ("R2_ACCESS_KEY_ID", access_key), ("R2_SECRET_ACCESS_KEY", secret),
    ] if not val]
    if missing:
        sys.exit(f"Missing R2 credentials: {', '.join(missing)}.\n"
                 f"Add them to {args.env_file} or pass via CLI flags.")

    langs = [l.strip() for l in args.langs.split(",") if l.strip()]

    # Walk source dir for matching .opus files
    files: list[Path] = []
    for lang in langs:
        files.extend(sorted(args.src.glob(f"{lang}_*.opus")))
    if not files:
        sys.exit(f"No .opus files found in {args.src} for langs={langs}")

    def remote_key(local: Path) -> str:
        # Local: hu_01_01.opus  ->  Remote: v1/hu/01_01.opus
        stem = local.stem  # hu_01_01
        lang, rest = stem.split("_", 1)
        return f"{args.version}/{lang}/{rest}.opus"

    console.print(f"[bold]Source:[/bold] {args.src}")
    console.print(f"[bold]Bucket:[/bold] {bucket}")
    console.print(f"[bold]Layout:[/bold] {args.version}/<lang>/<cat>_<story>.opus")
    console.print(f"[bold]Files:[/bold] {len(files)} candidates ({sum(f.stat().st_size for f in files) // 1024} KB total)")
    if public_base:
        sample = remote_key(files[0])
        console.print(f"[dim]Sample URL: {public_base.rstrip('/')}/{sample}[/dim]")

    if args.dry_run:
        for f in files[:10]:
            console.print(f"  would upload {f.name} -> {remote_key(f)}")
        if len(files) > 10:
            console.print(f"  ... and {len(files) - 10} more")
        return

    endpoint = f"https://{account_id}.r2.cloudflarestorage.com"
    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret,
        config=Config(signature_version="s3v4", region_name="auto",
                      retries={"max_attempts": 5, "mode": "standard"}),
    )

    totals = {"uploaded": 0, "skipped": 0, "failed": 0, "bytes": 0}
    recent_rows: list = []
    rows_lock = threading.Lock()

    progress_bar = Progress(
        TextColumn("[bold blue]{task.description}"),
        BarColumn(),
        MofNCompleteColumn(),
        TextColumn("•"),
        TimeElapsedColumn(),
        TextColumn("•"),
        TimeRemainingColumn(),
        expand=True,
    )
    bar_task = progress_bar.add_task("Uploading", total=len(files))

    def render() -> Group:
        table = Table(title=f"R2 upload — recent files (bucket: {bucket})", expand=True)
        table.add_column("#", justify="right", style="dim", width=5)
        table.add_column("File", style="cyan")
        table.add_column("Key", style="dim")
        table.add_column("Size", justify="right")
        table.add_column("Time", justify="right")
        table.add_column("Status", justify="center")
        for row in recent_rows[-12:]:
            color = {"up": "green", "skip": "yellow", "fail": "red"}[row["status"]]
            table.add_row(str(row["idx"]), row["file"], row["key"],
                          f"{row['size'] // 1024} KB", f"{row['elapsed']:.2f}s",
                          f"[{color}]{row['status']}[/{color}]")
        summary = (f"[bold]Progress:[/bold] {totals['uploaded'] + totals['skipped'] + totals['failed']}/{len(files)}    "
                   f"[green]up:[/green] {totals['uploaded']}    "
                   f"[yellow]skip:[/yellow] {totals['skipped']}    "
                   f"[red]fail:[/red] {totals['failed']}    "
                   f"[bold]uploaded:[/bold] {totals['bytes'] // 1024} KB")
        return Group(table, summary)

    def upload_one(idx: int, local: Path) -> dict:
        key = remote_key(local)
        size = local.stat().st_size
        started = time.time()
        try:
            # HEAD check: skip if remote already has same size
            try:
                head = client.head_object(Bucket=bucket, Key=key)
                if head["ContentLength"] == size:
                    return {"idx": idx, "file": local.name, "key": key,
                            "size": size, "status": "skip", "elapsed": time.time() - started}
            except ClientError as e:
                if e.response["Error"]["Code"] not in ("404", "NoSuchKey"):
                    raise
            client.upload_file(
                str(local), bucket, key,
                ExtraArgs={"ContentType": "audio/ogg",
                           "CacheControl": "public, max-age=2592000"},  # 30 days
            )
            return {"idx": idx, "file": local.name, "key": key, "size": size,
                    "status": "up", "elapsed": time.time() - started}
        except Exception as e:
            return {"idx": idx, "file": local.name, "key": key, "size": size,
                    "status": "fail", "elapsed": time.time() - started, "error": str(e)}

    def handle_sigint(signum, frame):
        _shutdown.set()
    signal.signal(signal.SIGINT, handle_sigint)

    start = time.time()
    with Live(render(), console=console, refresh_per_second=4, transient=False) as live:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as ex:
            futures = {ex.submit(upload_one, i + 1, f): f for i, f in enumerate(files)}
            for fut in concurrent.futures.as_completed(futures):
                res = fut.result()
                with rows_lock:
                    recent_rows.append(res)
                    if res["status"] == "up":
                        totals["uploaded"] += 1
                        totals["bytes"] += res["size"]
                    elif res["status"] == "skip":
                        totals["skipped"] += 1
                    else:
                        totals["failed"] += 1
                progress_bar.update(bar_task, advance=1)
                live.update(Group(render(), progress_bar))
                if _shutdown.is_set():
                    for f in futures:
                        if not f.running() and not f.done():
                            f.cancel()

    elapsed = time.time() - start
    console.print()
    console.print(f"[bold green]Upload done.[/bold green] "
                  f"up={totals['uploaded']} skip={totals['skipped']} fail={totals['failed']}  "
                  f"{totals['bytes'] // 1024} KB in {elapsed:.1f}s")
    if public_base and files:
        sample = remote_key(files[0])
        console.print(f"[dim]Test URL:[/dim] {public_base.rstrip('/')}/{sample}")


def main():
    args = parse_args()
    if args.cmd == "estimate":
        cmd_estimate(args)
    elif args.cmd == "run":
        cmd_run(args)
    elif args.cmd == "audition":
        cmd_audition(args)
    elif args.cmd == "voice-map":
        cmd_voice_map(args)
    elif args.cmd == "upload":
        cmd_upload(args)


if __name__ == "__main__":
    main()
