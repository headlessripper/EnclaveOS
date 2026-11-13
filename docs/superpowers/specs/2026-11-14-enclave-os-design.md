# Enclave OS — 1.0 Design

**Date:** 2026-11-14
**Status:** Approved (2026-11-14)
**Repo:** https://github.com/headlessripper/EnclaveOS

---

## 1. Intent & Why

Enclave is a polished, consumer-grade Linux distribution that **feels like a
cleaner, calmer Windows** — the GUI quality, intuitive navigation, and easy
control of Windows, without the clutter, telemetry, or bloat — built on the
stability, versatility, and openness of Linux.

It aims to be **the best of both worlds** for both average consumers and power
users: lightweight but powerful ("lightweight but deadly"), able to run Linux,
Windows, and Android apps side by side, with a **deeply integrated AI assistant
that can actually operate the system** — and talk with the user, in both
directions, through voice (OpenVox).

The first release must feel like **a complete, finished operating system** — not
a Linux desktop with a new wallpaper.

### Why now / what success looks like
Success for 1.0 = a person can install Enclave in a VM (or on metal), boot it,
and within minutes think *"this is its own OS, and it's genuinely nicer to use."*
They can run the apps they already rely on (Linux/Windows/Android), ask the AI to
do real things for them safely, and talk to it by voice.

---

## 2. Goals (1.0)

The five essentials, confirmed with the owner:

1. **Beautiful, polished desktop** — Windows-level GUI quality; clean, uncluttered
   design; intuitive navigation; customizable taskbar, start menu, settings, and
   file manager. Enclave branding and icon pack throughout.
2. **Universal app compatibility** — Linux apps natively (Flatpak), Windows apps
   via Wine/Proton, Android apps via Waydroid, and native Enclave apps.
3. **Integrated AI** — a system assistant that understands natural language and
   operates apps, manages files, configures settings, and executes tasks under
   **user-controlled permissions**.
4. **OpenVox voice integration** — natural two-way spoken conversation with
   Enclave; intelligent voice responses; hands-free system control.
5. **Lightweight performance** — fast boot, low resource use, strong hardware
   support, strong security, reliable updates. *(This is a cross-cutting standard
   applied to every phase, not a separate phase.)*

---

## 3. Non-Goals (1.0)

- **Writing our own kernel / userland from scratch.** Enclave stands on the Linux
  kernel and the NixOS base. We build identity, integration, and polish — not a
  new kernel.
- **Reinventing the app-compat engines.** We integrate and polish Wine/Proton,
  Waydroid, and Flatpak — we do not write new ones.
- **A full third-party developer ecosystem / app marketplace at scale.** 1.0 ships
  the native app *format* and a basic store mechanism; a thriving third-party
  marketplace is a later release.
- **Mobile / tablet / phone editions.** Desktop (and VM) first.
- **Fully autonomous, unattended AI control of the whole machine.** See §6.

## 4. Anti-Goals (what would make this a failure even if it "works")

- It feels like "yet another Linux distro" at first boot. ← the cardinal sin.
- The AI feels like a bolted-on chatbot gimmick rather than something that
  *operates the system*.
- It's heavy, slow, or fragile — betraying "lightweight but deadly."
- The AI does something destructive the user didn't authorize, or leaks private
  data. Trust is the whole product; one bad autonomous action breaks it.
- Clutter creeps back in (the Windows problem we're escaping).

---

## 5. Constraints

- **Base:** NixOS (decided — see §7).
- **Reproducibility:** Enclave must build to a reproducible, shippable ISO.
- **Rollback:** Every system change must be revertible (NixOS generations), so AI
  or update mistakes are non-events.
- **Dev/test environment:** VMware + WSL already installed on the owner's machine;
  VM boot is the primary test loop for early phases.
- **Assets:** Enclave icon pack provided (`light-orange-dot` — dark crescent-C with
  orange dot; multiple resolutions + SVG).
- **OpenVox (owned by us):** a complete **on-device, fully-offline** voice stack
  (`pip install openvox`; repo: github.com/Zashiron/OpenVox). STT, TTS, streaming
  TTS with barge-in, voice clone/enroll, enhance, and crucially **`openvox.agent`**
  — a mic→STT→LLM→streaming-TTS agent loop. This supplies the entire Phase 4 voice
  layer; Phase 4 becomes integration, not construction. Deployment: **on-device**.
- **Alpha Code (owned by us):** an advanced Tauri 2 + React AI-agent app with a
  Python backend (`C:\Users\nateg\Documents\Alpha_Project`). Supplies much of Phase
  3 — see §8.1. Reused, not rebuilt.
- **Target hardware (1.0):** x86_64 only (AMD + Intel). Min 8 GB RAM / rec 16 GB;
  storage 40 GB min / 100 GB rec; CPU 4-core 64-bit min; integrated GPU supported,
  dedicated Nvidia recommended for AI workloads.
- **Audience (1.0):** the owner + a small group ("me and some others for now") — so
  store, signing, and update infrastructure stay lightweight for 1.0.
- **Team:** effectively solo builder (owner) + AI pair. Favors integration over
  from-scratch engineering, and phasing over big-bang.

---

## 6. The AI-Pilot Safety Model (core design principle)

Because the AI *operates the system*, safety is designed in from day one, not
bolted on:

- **Declarative + rollback.** The AI changes the system primarily by editing the
  NixOS declarative config and rebuilding. A bad change = roll back one generation
  at boot. The AI never imperatively mangles a live system where it can be avoided.
- **Permission tiers.** Actions are classed by risk. Low-risk (read a file, open an
  app, answer a question) run freely. Medium/high-risk (delete data, change system
  settings, install software, send messages, anything outward-facing or
  irreversible) require explicit user confirmation each time.
- **Capability sandboxing.** Native Enclave apps declare exactly what they can
  touch; when the AI pilots an app it cannot exceed that declared scope.
- **1.0 autonomy level: assisted, not unattended** *(confirmed by owner)*. The AI
  acts *with the user present and approving* risky steps. "AI pilots by itself"
  fully unattended is an explicit later milestone, gated behind a proven track
  record of the above. Alpha Code's existing permission gate ("backend may narrow
  but never widen") is the enforcement mechanism.

---

## 7. Approaches Considered (the base)

| Option | Summary | Why / Why not |
|---|---|---|
| **A. NixOS** *(chosen)* | Whole OS defined as declarative config; atomic generations; reproducible ISOs. | **Chosen.** Best fit: AI pilots by editing config + instant rollback; reproducible builds for a shippable distro; whole system as code. Cost: steep Nix learning curve (borne mainly by the AI builder), more upfront polish work. |
| B. Arch-based | Rolling, ultralight, AUR has everything. | Fastest to a light, pretty desktop; but owner-owned stability, no built-in rollback/reproducible ISO — more fragile for AI-piloting. |
| C. Fedora Atomic | Immutable core, atomic rollback, container apps. | Same safety story, more approachable; but heavier and immutability fights deep customization. |
| — Ubuntu/Debian | Stable, familiar. | Dropped: too heavy / old-package for "lightweight but deadly." |

**Decision: Option A (NixOS).** The declarative-config + rollback + reproducible-ISO
combination is nearly purpose-built for a shippable distro that an AI safely pilots.

---

## 8. Decided "How" (settled in conversation)

- **Base OS:** NixOS (flakes).
- **Desktop environment:** **KDE Plasma** — the most Windows-like *and* most
  customizable DE, so we can sculpt the clean Enclave look without fighting the
  toolkit. *(Builder's call, owner did not object.)*
- **Window system — the Enclave standard (from Alpha Code):** every window is
  **frameless with a custom title bar**, and carries a **floating, always-on-top,
  draggable bubble**. The bubble holds a sub-bubble of window controls (drag,
  minimize, maximize, close) plus window-related functions the user can reach from
  the bubble. This is the OS-wide standard.
  - *Native Enclave apps (Tauri):* built in as the default in the `.enc` SDK (it is
    already how Alpha Code works).
  - *Foreign apps (Wine/Waydroid/Flatpak):* a **KWin script/effect** strips their
    own decorations and attaches the Enclave bubble, so the standard holds OS-wide.
- **App compatibility:** Flatpak (Linux), Wine/Proton (Windows), Waydroid (Android),
  native Enclave apps.
- **Native app format — "the Enclave App" (`.enc`):** sandboxed, capability-scoped
  apps that publish a machine-readable **Action Manifest** (a structured list of
  what the app can *do*, with named params). The AI and OpenVox pilot native apps by
  **calling declared actions**, not screen-scraping. Default SDK **Tauri** (Rust +
  system webview — tiny, fast, modern); format is runtime-agnostic (Qt/GTK may ship
  the same manifest). Packaged reproducibly via Nix, signed, distributed via the
  Enclave store. Non-native (Windows/Linux/Android) apps are piloted via UI control
  as a fallback; native apps are the first-class, most-pilotable citizens.
- **AI brain — hybrid (owner's choice):** the user chooses their provider.
  - **Bring-your-own local GGUF** — drop in a `.gguf` model; it plugs in and runs
    on-device via Alpha Code's local model runner (llama-server, OpenAI-compatible).
    Private, offline, no marginal cost.
  - **Enclave cloud — GPT-OSS-20B** — our hosted model (built later) for maximum
    capability when the user opts in.
  The system presents these as a simple provider switch; local is the private default.
- **Model store (LM-Studio-style):** a built-in store to discover, download, and
  manage GGUF models from Hugging Face (authenticated with the owner's HF read
  token, held in the OS keyring — never in code/config). Downloaded models register
  with the local runner automatically.
- **Voice:** OpenVox, on-device, integrated at Phase 4 — its `openvox.agent` loop
  wires mic→STT→AI→streaming-TTS with barge-in; its actions map to the same Action
  Manifests the AI uses, so voice and the AI assistant share one command surface.
- **Build order (phased):** 0 Foundation → 1 Desktop → 2 Apps → 3 AI pilot →
  4 Voice. Essential #5 (lightweight/secure/reliable) is a standard across all.

### 8.1 Alpha Code reuse (owner's existing Tauri AI app)
Alpha Code is reused as the foundation of the Enclave AI layer rather than rebuilt:

| Alpha Code part | Role in Enclave |
|---|---|
| AI agent harness (permission gate, constraints, journaling, memory/lessons/told-facts) | The Enclave AI assistant brain + the §6 safety enforcement |
| Local model runner (llama-server, OpenAI-compatible, GGUF) | The local half of the hybrid AI brain; backs the model store |
| Tauri 2 + React desktop app (pane dock, canvases, settings, bubble) | Base for the Enclave AI client UI; validates the `.enc`/Tauri SDK direction |
| Browser/UI pilot (`instruments/pilot.py`) | The UI-control fallback for non-native (Windows/Linux/Android) apps |
| JSON-RPC 2.0 / WebSocket backend contract | The AI ↔ system integration surface |

Phase 3 becomes **adapt + integrate Alpha Code into the OS** rather than build an
assistant from zero. (Exact extraction/forking strategy is a Phase 3 planning task.)

---

## 9. Phase Plan

Each phase ends in something bootable/testable in VMware.

### Phase 0 — Foundation
NixOS flake + repo structure; reproducible ISO build pipeline; Btrfs + generations
for rollback; clean boot in VMware; Enclave branding scaffold (boot splash, naming).
**Done when:** a branded Enclave ISO builds reproducibly and boots to a basic
session in a VM, and we can roll back a change.

### Phase 1 — The Enclave Desktop (essential #1)
KDE Plasma sculpted into the Enclave look: clean uncluttered layout, custom taskbar,
start menu, file manager, settings, theme, and the icon pack wired in. Plus the
**Enclave window system** (§8): frameless windows + the floating control bubble —
native apps via the SDK default, foreign apps via the KWin script/effect.
**Done when:** first boot *feels like Enclave* — a complete, polished desktop with
the frameless/bubble window standard, not stock Plasma.

### Phase 2 — Universal Apps (essential #2)
Flatpak store integration; Wine/Proton + a clean Enclave launcher for Windows apps;
Waydroid for Android; the `.enc` native format + SDK + a basic Enclave store; decide
the native-app baseline set.
**Done when:** a user can install and run a Linux app, a Windows app, an Android app,
and a native Enclave app from one coherent interface.

### Phase 3 — The AI Pilot (essential #3)
Adapt and integrate **Alpha Code** (§8.1) into Enclave as the system assistant:
natural-language understanding; action execution via native Action Manifests +
UI-control fallback; file/settings management; the permission-tier + rollback safety
model from §6. Ship the **hybrid AI brain** (BYO local GGUF via the local runner, or
Enclave cloud GPT-OSS-20B) and the **LM-Studio-style model store** (HF-backed, token
in keyring).
**Done when:** the AI reliably performs real multi-step tasks across apps/files/
settings, asking permission for risky steps, with rollback proven; a user can add a
GGUF model from the store and switch providers.

### Phase 4 — OpenVox Voice (essential #4)
Integrate **OpenVox** on-device on top of the Phase 3 brain via `openvox.agent`:
speech-in (user → OS/AI), speech-out (OS/AI → user), streaming TTS with barge-in,
hands-free control mapped to the same Action Manifests.
**Done when:** the user can hold a natural spoken conversation with Enclave and
control it hands-free, intelligently, offline.

---

## 10. Cross-Cutting Standard — Essential #5
Applied every phase: fast boot & low idle resource use; broad hardware/driver
support; security hardening and the AI-safety model; reliable atomic updates with
rollback. Each phase is measured against these before it's "done."

---

## 11. What's Left to the Builder
- Repo/flake layout and module structure.
- ISO build tooling specifics.
- Exact Plasma theming implementation to hit the Enclave look.
- Action Manifest schema details and the Tauri SDK surface.
- Store mechanism implementation.
- Packaging specifics for Wine/Proton/Waydroid under Nix.

---

## 12. Decisions (resolved)
All prior open questions are settled:

1. **AI brain:** hybrid — bring-your-own local GGUF (via Alpha Code's local runner,
   private default) or Enclave cloud GPT-OSS-20B (built later). Plus an
   LM-Studio-style, HF-backed model store. (§8)
2. **OpenVox:** on-device, fully offline; integrated via `openvox.agent` at Phase 4.
3. **AI autonomy (1.0):** assisted — user approves risky steps; unattended is a
   later milestone. (§6)
4. **Audience (1.0):** the owner + a small group; lightweight store/signing/update.
5. **Hardware (1.0):** x86_64 (AMD/Intel); 8 GB min / 16 GB rec RAM; 40 GB min /
   100 GB rec storage; 4-core min; iGPU ok, Nvidia dedicated recommended for AI.

---

## 13. Approval
Design doc awaiting owner approval. On approval, next step is the implementation
plan (per phase, starting Phase 0).
