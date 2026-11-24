# Enclave OS — v2 Design (Arch base, Windows-like, assistant-only)

**Date:** 2026-11-17
**Status:** Draft — awaiting owner approval
**Supersedes:** `2026-11-14-enclave-os-design.md` (NixOS + AI-pilot direction)
**Repo:** https://github.com/headlessripper/EnclaveOS

---

## 0. What changed from v1 (and why)

The owner re-scoped the product after seeing FlowOS. Three decisions flipped the
foundation, so the v1 design (NixOS base + an AI that *operates* the system) is
retired and replaced by this document:

1. **Look:** retire the orange-glass identity. Enclave should feel like Windows —
   familiar enough to be mistaken for it at a glance — but **cleaner and nicer**,
   with Enclave's *own* branding and icons. Not a pixel-clone, not Microsoft's
   assets. "Enclave is not Windows; it's Windows-like."
2. **AI:** drop the AI that *operates the machine*. Keep a **helpful assistant +
   voice that answers and helps but never controls the system.**
3. **Base:** move from **NixOS → Arch**. NixOS existed in v1 only to give the
   piloting AI safe, atomic rollback. With the piloting AI gone, that reason is
   gone, and Arch is the lighter-friction, rolling, familiar base (and what
   FlowOS itself uses).

**Priority order, per owner:** UI / feel / experience comes first. Everything
else serves that.

---

## 1. Intent & Why

Enclave is a polished, consumer-grade Linux distribution that **feels like a
cleaner, calmer Windows**: the familiar layout and navigation of Windows, but
lighter, tidier, and nicer to use — with its own identity — and able to run the
apps people already rely on (Windows, Android, Linux) side by side.

A Windows user should sit down and *immediately know where everything is* — then
notice it's quieter, cleaner, and faster than what they left. Enclave is
**Windows-like in layout, Enclave in identity.**

### Success for 1.0
A person installs Enclave in a VM (or on metal), boots it, and within minutes
thinks *"this feels like Windows, but nicer — and it's its own thing."* They run
a Linux app, a Windows app, and an Android app from one coherent desktop, and
they can ask the built-in assistant (by text or voice) for help and answers.

---

## 2. Goals (1.0)

1. **A beautiful, polished, Windows-familiar desktop — the top priority.**
   Instantly familiar layout (taskbar, start menu, file manager, settings, system
   tray, window controls where a Windows user expects the *function*), but
   **cleaner and nicer than Windows**: less clutter, calmer visuals, generous
   spacing, Enclave branding and icon pack throughout. The **signature Enclave
   touch**: frameless windows + the floating control bubble, OS-wide.
2. **Universal app compatibility.** Linux apps natively (Flatpak + AUR), Windows
   apps via Wine/Proton, Android apps via Waydroid, plus native Enclave apps.
3. **Lightweight at rest.** Fast boot, low *idle* resource use, strong hardware
   support. Light while idle is the promise; running a Proton game and Android
   emulation at once is heavy on any OS and is explicitly **not** promised as
   light.
4. **A helpful assistant + voice (advisory only).** A built-in assistant, with
   OpenVox voice, that understands natural language and **answers questions,
   explains, guides, and helps** — but **never operates the machine** (no system
   changes, no acting on the user's behalf). See §6.

---

## 3. Non-Goals (1.0)

- Writing our own kernel or userland. Enclave stands on the Linux kernel + Arch.
- Reinventing the compatibility engines (Wine/Proton, Waydroid, Flatpak).
- **An AI that operates/controls the system.** Explicitly dropped in v2.
- **macOS app support (Darling).** Dropped — out of scope for 1.0.
- A full third-party app marketplace at scale.
- Mobile / tablet / phone editions.
- Pixel-perfect Windows cloning or use of Microsoft's icons, names, or branding.

## 4. Anti-Goals (failure even if it "works")

- It feels like "yet another Linux distro" at first boot. ← the cardinal sin.
- It feels like a **cheap or uncanny Windows skin** — janky, inconsistent, an
  obvious reskin rather than a coherent, polished OS.
- Clutter creeps back in (the Windows problem we're escaping).
- It's heavy, slow, or fragile — betraying "lightweight at rest."
- The assistant feels like a bolted-on chatbot gimmick, or oversteps and tries
  to act on the system.

---

## 5. Constraints

- **Base:** **Arch Linux**, shipped as a custom reproducible ISO built with
  **`archiso`** (see §7).
- **Desktop/compositor:** **KDE Plasma 6 on Wayland (KWin)**, trimmed — chosen for
  the Windows-like layout, deep customizability, and because our bubble/frameless
  standard is built on KWin scripting (§8).
- **Window standard (kept from v1):** every window is frameless with a floating,
  always-on-top, draggable **control bubble** (drag / minimize / maximize / close
  + window functions). OS-wide, including foreign (Wine/Waydroid/Flatpak) apps via
  a KWin script that strips native decorations and attaches the bubble.
- **App compatibility:** Flatpak + AUR (Linux), Wine/Proton (Windows), Waydroid
  (Android). No macOS.
- **Assistant (advisory):** reuses the **chat/assistant** parts of Alpha Code
  (owner's Tauri 2 + React AI app at `C:\Users\nateg\Documents\Alpha_Project`) —
  the conversation UI, local model runner (llama-server, GGUF), and memory — but
  **not** the system-pilot / permission-gate / UI-control machinery, which is out
  of scope now. Hybrid brain: bring-your-own local GGUF (private default) or an
  optional Enclave cloud model later.
- **OpenVox (owned):** on-device, fully-offline voice stack (STT/TTS, streaming
  TTS with barge-in). Supplies the voice layer. In v2 it drives a *conversational*
  assistant, not system control.
- **Assets:** Enclave icon pack (`light-orange-dot`) + Enclave branding; a new
  Windows-familiar-but-cleaner visual theme replaces the orange-glass theme.
- **Dev/test:** VMware + WSL on the owner's machine; VM boot is the primary test
  loop. Target hardware: x86_64 (AMD/Intel).
- **Audience (1.0):** owner + a small group — so store/signing/update stay light.
- **Team:** effectively solo builder + AI pair. Favors integration over
  from-scratch work, and phasing over big-bang.

---

## 6. Assistant Scope & Boundary (replaces v1's AI-pilot safety model)

The assistant is **advisory and read-only toward the system.** It can:

- Answer questions, explain how to do things, teach, and hold a natural
  conversation (text or OpenVox voice).
- Read context the user explicitly shares with it.

It **cannot**:

- Change system settings, install/remove software, edit config, manage files on
  the user's behalf, send messages, or take any outward-facing or irreversible
  action.

Because the assistant never mutates the system, Enclave does **not** need
declarative rollback for AI safety — which is precisely why Arch (no built-in
atomic rollback) is now an acceptable base. (Normal system resilience — snapshots,
backups — is a separate, ordinary concern, not an AI-safety requirement.)

A later milestone *may* reintroduce limited, permission-gated actions; it is out
of scope for 1.0 and would come back through design review.

---

## 7. Approaches Considered

### 7a. The base

| Option | Summary | Why / why not |
|---|---|---|
| **Arch** *(chosen)* | Rolling, ultralight, AUR has everything; `archiso` builds a branded custom ISO. | **Chosen.** With the piloting AI dropped, NixOS's rollback edge no longer matters. Arch is lighter friction for a solo builder, rolling, familiar, has every package, and is what FlowOS uses. Cost: no built-in atomic rollback/reproducibility (acceptable now; mitigated by ordinary snapshots if wanted). |
| NixOS | Declarative config, atomic generations, reproducible ISOs. | Dropped. Its whole value here was safe AI rollback; without piloting AI, the steep Nix cost buys little. |
| Fedora Atomic | Immutable core, atomic rollback, container apps. | Dropped. Heavier; immutability fights the deep shell customization the UI-first goal needs. |

### 7b. The shell (how we reach the Windows-like look)

| Option | Summary | Why / why not |
|---|---|---|
| **Trimmed KDE Plasma 6 / KWin, themed Windows-like-but-cleaner** *(chosen)* | Strip Plasma to essentials; theme the panel, start menu, file manager into a cleaner Windows-familiar shell with Enclave branding. | **Chosen.** Most Windows-like + most customizable DE; our bubble/frameless KWin work carries over unchanged; best app-compat/gaming story; salvages most existing Phase-1 design. Cost: higher idle RAM than a minimal stack, but comfortably "light at rest." |
| Minimal Wayland stack (labwc / Hyprland) + hand-built shell | Lowest idle RAM. | Dropped. We'd re-engineer the bubble on a new compositor and hand-build the whole shell — far more work, less polish, throws away the KWin design. Only wins if raw idle RAM beats everything, which it doesn't here (UI/feel is priority #1). |
| Base on a ready-made "Windows 11" Arch spin | Fast to a Windows look. | Dropped. That's the chosen approach with someone else's branding and less control; such spins are Plasma-based anyway. |

---

## 8. Decided "How"

- **Base:** Arch, custom ISO via `archiso` (custom profile; Enclave branding, boot
  splash, naming baked in).
- **Shell:** KDE Plasma 6 on Wayland (KWin), trimmed to essentials, re-themed into
  a **Windows-familiar but cleaner** experience:
  - A single bottom **taskbar** (Enclave's — cleaner than Windows', our icons),
    start menu / launcher, system tray, clock.
  - **File manager**, **Settings**, and system dialogs laid out where a Windows
    user expects the *function*, but tidier and calmer.
  - Enclave icon pack + a cohesive Enclave theme (visual language proposed below).
- **Window standard:** frameless windows + the floating **control bubble**,
  OS-wide; native Enclave apps get it by default, foreign apps via the KWin
  script that strips decorations and attaches the bubble.
- **App compatibility:** Flatpak + AUR (Linux), Wine/Proton (Windows, incl. games
  via Proton), Waydroid (Android), each with a clean Enclave launcher/entry point.
- **Assistant:** the advisory assistant from Alpha Code's chat layer + local GGUF
  runner; OpenVox for voice; hybrid local/cloud provider switch (local is the
  private default).
- **Visual language (builder's proposal — owner to confirm, see §12):** calm,
  modern, flat-leaning with *restrained* depth — rounded corners, light
  translucency used sparingly (not heavy glass), generous spacing, strong
  typography, and **one tasteful Enclave accent** rather than the loud
  orange→magenta bloom. Full light + dark. The point is "quieter and cleaner than
  Windows," not "more decorated."

---

## 9. Phase Plan

Each phase ends in something bootable/testable in VMware. Lightweight-at-rest is a
standard applied every phase, not a separate phase.

### Phase 0 — Foundation (Arch)
`archiso` custom profile; lean Arch base; reproducible-enough ISO build; clean
boot in VMware; Enclave branding scaffold (boot splash, naming).
**Done when:** a branded Enclave Arch ISO builds and boots to a basic session in a
VM.

### Phase 1 — The Enclave Desktop (TOP PRIORITY — UI / feel / experience)
Trimmed Plasma 6 sculpted into the Windows-familiar-but-cleaner Enclave shell:
taskbar, start menu, file manager, settings, theme, icon pack, **and** the
frameless-window + floating-bubble standard (native default + KWin script for
foreign apps).
**Done when:** first boot *feels like Enclave* — familiar as Windows, visibly
cleaner and nicer, with the bubble standard — not stock Plasma and not a cheap
skin.

### Phase 2 — Universal Apps
Flatpak + AUR; Wine/Proton + a clean Enclave launcher for Windows apps; Waydroid
for Android; (native `.enc` app format + a basic store — can be trimmed/deferred
for 1.0 if needed).
**Done when:** a user installs and runs a Linux, a Windows, and an Android app
from one coherent interface.

### Phase 3 — Assistant + Voice (advisory)
Integrate Alpha Code's chat assistant + local GGUF runner as the built-in,
**advisory** assistant; wire OpenVox for two-way voice. No system control.
**Done when:** the user can hold a natural text/voice conversation with Enclave
that answers and helps, offline, with a local or (later) cloud model — and it
never touches the system.

---

## 10. Cross-Cutting Standard
Every phase: fast boot & low idle resource use; broad hardware/driver support;
basic security hardening; reliable updates. Measured before a phase is "done."

---

## 11. What's Left to the Builder
- `archiso` profile layout and ISO build tooling specifics.
- Exact Plasma trimming + theming to hit the Windows-familiar-but-cleaner look.
- The KWin bubble script port/verification on Plasma 6 Wayland.
- Packaging specifics for Wine/Proton + Waydroid on Arch.
- Assistant extraction strategy from Alpha Code (chat layer only).
- Whether the native `.enc` format/store ships in 1.0 or defers.

---

## 12. Open for the Owner
1. **Visual direction (priority — this is the #1 goal).** §8 proposes a calm,
   flat-leaning look with restrained translucency and a single Enclave accent
   (not the old orange-glass bloom). Confirm the vibe and the accent, or point me
   at references you love — I can show mockups before we build Phase 1.

---

## 13. Approval
Awaiting owner approval. On approval, next step is the implementation plan
(superpowers:writing-plans), starting Phase 0.
