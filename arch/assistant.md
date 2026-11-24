# Enclave — advisory assistant + OpenVox voice (Phase 3)

A built-in assistant that **answers and helps** by text and voice, and **never
operates the machine**. This is the v2 scope: the AI-that-pilots-the-system from
v1 is dropped.

## The advisory boundary (non-negotiable)
`/etc/enclave/assistant.toml` sets `advisory_only = true`, `system_actions =
false`. The shipped assistant has **no system-control tools wired in** — no
settings changes, installs, file ops, or actions on the user's behalf. It reads
only what the user explicitly shares. (A future, permission-gated action mode is
out of scope for 1.0 and would come back through design review.)

## What we reuse from Alpha Code
Alpha Code (`C:\Users\nateg\Documents\Alpha_Project`, Tauri 2 + React + Python)
is the source — but **only its chat layer**:

| Take | Leave |
|---|---|
| Conversation UI (pane, chat, settings) | The system-pilot / UI-control (`instruments/pilot.py`) |
| Local model runner (llama-server, GGUF) | The permission gate + action execution |
| Memory / lessons / told-facts | JSON-RPC system-integration surface |

Extraction = fork the chat app, strip the pilot/permission machinery, repackage
as an `.enc` app that installs to `/usr/lib/enclave/assistant/enclave-assistant`.
That fork is the remaining build work; the OS-side wiring below is in place.

## OS-side wiring (shipped)
- `enclave-assistant` — launches the app (or points to setup if not installed).
- `enclave-voice` — OpenVox conversational agent (`openvox.agent`: mic → STT →
  assistant → streaming TTS, barge-in). Same advisory boundary.
- `enclave-models` — list/add local GGUF models.
- `enclave-assistant-setup` — opt-in installer for the runtime: `llama.cpp`
  (AUR), OpenVox (`pipx install openvox`), and the models dir.
- Start-menu entry + config at `/etc/enclave/assistant.toml`.

## Hybrid brain
- **Local (default, private):** drop a `.gguf` in `~/.local/share/enclave/models`;
  `llama-server` serves it OpenAI-compatibly to the assistant.
- **Cloud (opt-in, later):** an Enclave-hosted model; tokens live in KWallet,
  never in config.

## Why opt-in, not baked into the ISO
`llama.cpp` is AUR and OpenVox is a pip package; models are large. As with app
compat, `enclave-assistant-setup` installs these on the running system. A signed
`[enclave]` repo can later bake a default runtime + small model into the image.
