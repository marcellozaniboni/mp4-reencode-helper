# mp4-reencode-helper

An interactive Bash script that wraps **ffmpeg** to apply the most common “personal video” operations (resize, rotate, aspect ratio, trimming) and re-encode to mp4 with sensible defaults.

This project is meant to be a practical, hackable starting point for your own needs.

---

## Features

- **Input/Output:** takes exactly two arguments: `input.mp4` and `output.mp4`
- **Interactive prompts** before encoding:
  - ffmpeg **preset** (default: `slow`)
  - target **resolution**: `1080p`, `720p` (default), `480p`
  - **rotation**: `0` (default), `90`, `180`, `270`
  - **display aspect ratio (DAR)**: no change (default), `4:3`, `14:9`, `16:9`, plus common smartphone formats like `9:16`, `1:1`
  - video **encoder** (default: `libx264`, plus other “MP4-friendly” options if available)
  - **audio**: copy or AAC (default: copy)
  - optional **trim**: start time in seconds (default `0`) and optional end time in seconds
- output is optimized for compatibility:
  - `-pix_fmt yuv420p` for broad device/player support
  - `-movflags +faststart` for “streamable” MP4 (moov atom at the beginning)

---

## Requirements

- Linux (or macOS) with:
  - **Bash**
  - **FFmpeg** installed and available in `PATH`

Check installation:

```bash
ffmpeg -version
bash --version
```
