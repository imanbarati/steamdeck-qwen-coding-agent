# Steam Deck Qwen Local Coding Agent

Run a local Qwen2.5-Coder model on Steam Deck / SteamOS and use it through OpenCode.

> **Status: experimental bootstrap.** The installer is a starting point and has not been verified on a physical Steam Deck. It may stop if build tools are unavailable, and upstream model/configuration details can change. Read the installer and handoff before running it.

## Target setup

- Qwen2.5-Coder-7B-Instruct GGUF, Q4_K_M quantization
- llama.cpp server bound to `127.0.0.1:8080`
- OpenCode configured to use the local OpenAI-compatible endpoint
- User-space files under `~/.local/share`, `~/.local/bin`, `~/Models`, and `~/.config`
- No `sudo`, `pacman`, system-file edits, or stored GitHub credentials

## Install

In SteamOS Desktop Mode, open Konsole and download this repository, then run:

```bash
git clone https://github.com/imanbarati/steamdeck-qwen-coding-agent.git
cd steamdeck-qwen-coding-agent
bash install-steamdeck-qwen-agent.sh
```

The installer downloads several gigabytes, including the model. It expects `curl`, `git`, a compatible Node.js runtime, and either CMake plus a C++ compiler to build llama.cpp or an already-installed compatible `llama-server` in the paths it checks. It does not install missing SteamOS system packages.

After a successful installation, run:

```bash
~/.local/bin/qwen-code
```

## Important notes

- This is a CPU-first configuration (`-ngl 0`, Vulkan disabled); performance may be limited.
- Do not run scripts from the internet without inspecting them first.
- Authenticate GitHub CLI separately if needed; never put tokens or passwords in this repository.
- The agent's local-model setup does not itself configure GitHub access or enable unattended pushes.
- Review diffs and test results before accepting code changes. Do not force-push, deploy, publish releases, or delete branches without explicit approval.

See [HANDOFF.md](HANDOFF.md) for implementation details, known gaps, and the next verification steps.
