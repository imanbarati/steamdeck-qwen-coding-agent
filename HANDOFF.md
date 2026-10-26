# Handoff: Steam Deck Qwen Local Coding Agent

## Goal

Create a cautious, mostly user-space local coding-agent setup for Steam Deck / SteamOS using Qwen2.5-Coder-7B-Instruct GGUF, llama.cpp, and OpenCode. Intended hardware context: Steam Deck with 16 GB shared memory and AMD GPU. Initial configuration prioritizes CPU compatibility over speed.

## Repository state

- Repository: https://github.com/imanbarati/steamdeck-qwen-coding-agent
- Bootstrap script: `install-steamdeck-qwen-agent.sh`
- This repository is an experimental starter, **not a verified one-click installer**.
- No claim is made that the script has been run successfully on a real Steam Deck.
- The script should be reviewed and corrected before recommending it to others.

## Intended architecture

1. Download a user-space Node.js runtime.
2. Install OpenCode under the project user's home directory.
3. Clone and compile llama.cpp in user space if CMake and a C++ compiler are available.
4. Download Qwen2.5-Coder-7B-Instruct Q4_K_M GGUF.
5. Configure OpenCode to use llama.cpp's OpenAI-compatible API at `http://127.0.0.1:8080/v1`.
6. Provide `~/.local/bin/qwen-code` to start the local model server and OpenCode.
7. Create a desktop shortcut in `~/.local/share/applications`.

## Paths created by the installer

- `~/.local/share/qwen-deck-agent/` — Node runtime, npm package, llama.cpp checkout/build, logs
- `~/Models/Qwen2.5-Coder-7B/` — model file
- `~/.config/opencode/opencode.json` — OpenCode provider config
- `~/.local/bin/qwen-code` — launcher
- `~/.local/share/applications/qwen-code.desktop` — desktop shortcut
- `~/AGENTS.md` — safety defaults, created only if no file exists

## Critical verification tasks for the next AI/developer

Do these before calling the installer reliable:

1. **Verify the model URL and filename.** Confirm the official Hugging Face repository actually contains the requested Q4_K_M file. Use the current upstream repository listing instead of assuming the URL is valid.
2. **Verify llama.cpp build flags and binary paths.** Check current upstream CMake options and whether the target executable is `build/bin/llama-server` on SteamOS.
3. **Verify OpenCode's current configuration schema.** Confirm provider key, model limits, base URL, package identifier, and model alias work with the currently published OpenCode release. Run a minimal smoke test.
4. **Fix prerequisites handling.** The current script warns about missing `cmake` / `c++` and then exits later. Make preflight output explicit and offer a safe, supported user-space fallback where possible. Do not use `sudo` or modify SteamOS system files silently.
5. **Add robust integrity checks.** Use upstream checksums/signatures where available, verify downloaded Node archive and model metadata, preserve resumable downloads, and avoid treating file size alone as integrity validation.
6. **Improve process management.** Check for a stale PID, handle port conflicts, wait for readiness with clear errors, and ensure the server is stopped appropriately when the UI exits if that is the intended behavior.
7. **Add diagnostics.** A `scripts/diagnose.sh` should report architecture, available disk space, RAM, required commands, file sizes, port status, and relevant log paths without exposing secrets.
8. **Test in layers.** Shell syntax check; lint/shellcheck if available; verify download URLs with HTTP status/metadata; build llama.cpp; launch server; query `/v1/models`; run a short OpenCode prompt. If no Steam Deck is available, clearly label all hardware tests as unperformed.
9. **Review GPU support.** Vulkan may improve AMD performance, but do not enable it unless the correct dependencies and build are validated. Keep a known-working CPU path.
10. **Document cleanup and recovery.** Explain how to stop the server, inspect logs, safely remove only files created by this installer, and rerun after interrupted downloads.

## Current script limitations / risks

- Model URL, archive URL, and current OpenCode config compatibility have not been independently verified here.
- The script requires `git`; it does not install it if missing.
- If CMake or a C++ compiler is missing, the installer exits; it does not actually fetch a prebuilt llama.cpp binary.
- The build explicitly disables Vulkan and uses CPU inference (`-ngl 0`).
- A file-size threshold catches some incomplete model downloads but is not a checksum.
- The launcher starts a server in the background and writes a PID file but does not currently clean up the process on exit.
- The OpenCode configuration may need updates for upstream schema changes.
- Installer and runtime behavior have not been validated on a real Steam Deck.

## Safety requirements

- Never use `sudo`, `pacman`, or modify immutable/system SteamOS files as an implicit step.
- Do not overwrite an existing `~/AGENTS.md`; the installer currently checks before creating it.
- Never request or store GitHub tokens in the repo. GitHub CLI auth is a separate user-controlled step.
- Do not force-push, delete branches, publish releases, deploy, or change remote settings without explicit approval.
- Preserve user data and existing repository changes.
- State clearly which checks were actually run and which are only proposed.

## Suggested future structure

```text
README.md
HANDOFF.md
install-steamdeck-qwen-agent.sh
scripts/diagnose.sh
config/opencode.example.json
LICENSE
```

Only add files when their contents are real and reviewed; do not claim missing diagnostics, CI, or tests exist.

## Upstream references

- llama.cpp: https://github.com/ggml-org/llama.cpp
- Qwen2.5-Coder GGUF repository: https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF
- OpenCode: https://opencode.ai/
- OpenCode configuration docs: https://opencode.ai/docs/config/

## Completion checklist

- [ ] Verify official model artifact and current OpenCode schema.
- [ ] Run shell syntax checks and inspect the script.
- [ ] Add diagnostics and safe cleanup instructions.
- [ ] Test the local HTTP endpoint and one short coding task.
- [ ] Test on physical Steam Deck if available.
- [ ] Update this handoff with real command outputs and known-good versions.
