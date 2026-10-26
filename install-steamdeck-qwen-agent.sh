#!/usr/bin/env bash
# Steam Deck local Qwen coding-agent bootstrap.
# User-space install; does not use sudo, pacman, or alter SteamOS system files.
# Run from Desktop Mode / Konsole:
#   bash install-steamdeck-qwen-agent.sh
set -Eeuo pipefail

APP_DIR="${HOME}/.local/share/qwen-deck-agent"
BIN_DIR="${HOME}/.local/bin"
MODEL_DIR="${HOME}/Models/Qwen2.5-Coder-7B"
CONFIG_DIR="${HOME}/.config/opencode"
MODEL_FILE="${MODEL_DIR}/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
LLAMA_REPO="https://github.com/ggml-org/llama.cpp.git"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

mkdir -p "$APP_DIR" "$BIN_DIR" "$MODEL_DIR" "$CONFIG_DIR" "${HOME}/.cache/qwen-deck-agent"
exec > >(tee -a "${APP_DIR}/install.log") 2>&1

log "Steam Deck / user-space preflight"
printf 'User: %s\n' "$USER"
printf 'Home: %s\n' "$HOME"
printf 'Kernel: %s\n' "$(uname -r)"
if [[ ! -d /run/host ]]; then
  warn "This may not be SteamOS Desktop Mode. Continuing without system changes."
fi

for cmd in curl git cmake c++ python3; do
  if ! have "$cmd"; then warn "Missing prerequisite: $cmd"; fi
done
if ! have curl; then die "curl is required. On SteamOS it is normally available."; fi
if ! have git; then
  die "Git is missing. This installer will not use sudo or modify SteamOS. Install Git through a supported user-space method, then rerun."
fi

NODE_DIR="${APP_DIR}/node"
if [[ ! -x "${NODE_DIR}/bin/node" ]]; then
  log "Installing user-space Node.js runtime"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) die "Unsupported CPU architecture: $ARCH" ;;
  esac
  NODE_VERSION="22.16.0"
  NODE_TAR="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"
  mkdir -p "${APP_DIR}/downloads"
  curl -fL --retry 3 "$NODE_URL" -o "${APP_DIR}/downloads/${NODE_TAR}"
  mkdir -p "$NODE_DIR"
  tar -xJf "${APP_DIR}/downloads/${NODE_TAR}" -C "$NODE_DIR" --strip-components=1
fi
export PATH="${NODE_DIR}/bin:${BIN_DIR}:${PATH}"
printf 'PATH=%s\n' "$PATH" > "${APP_DIR}/env.sh"

if ! have opencode; then
  log "Installing OpenCode into user space"
  npm install -g --prefix "$APP_DIR/npm" opencode-ai
  mkdir -p "$BIN_DIR"
  ln -sf "${APP_DIR}/npm/bin/opencode" "${BIN_DIR}/opencode"
  export PATH="${APP_DIR}/npm/bin:${PATH}"
else
  log "OpenCode already installed; leaving it untouched"
fi

LLAMA_DIR="${APP_DIR}/llama.cpp"
LLAMA_BIN=""
if [[ -x "${LLAMA_DIR}/build/bin/llama-server" ]]; then
  LLAMA_BIN="${LLAMA_DIR}/build/bin/llama-server"
elif [[ -x "${BIN_DIR}/llama-server" ]]; then
  LLAMA_BIN="${BIN_DIR}/llama-server"
else
  log "Preparing llama.cpp in user space"
  if ! have cmake || ! have c++; then
    warn "CMake or C++ compiler missing. No compatible prebuilt asset is selected automatically."
    die "Could not build llama.cpp because cmake/c++ is missing. Install a compatible prebuilt llama.cpp bundle into ${BIN_DIR}, then rerun. See ${APP_DIR}/install.log."
  fi
  if [[ ! -d "$LLAMA_DIR/.git" ]]; then
    git clone --depth 1 "$LLAMA_REPO" "$LLAMA_DIR"
  else
    git -C "$LLAMA_DIR" pull --ff-only
  fi
  cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=ON -DGGML_VULKAN=OFF \
    -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TESTS=OFF
  cmake --build "$LLAMA_DIR/build" --config Release -j2
  LLAMA_BIN="${LLAMA_DIR}/build/bin/llama-server"
fi
[[ -x "$LLAMA_BIN" ]] || die "llama-server not found after build."
ln -sf "$LLAMA_BIN" "${BIN_DIR}/llama-server"

if [[ ! -s "$MODEL_FILE" ]]; then
  log "Downloading Qwen2.5-Coder 7B Instruct Q4_K_M GGUF (~4.7 GB)"
  curl -fL --retry 4 --retry-delay 2 --continue-at - "$MODEL_URL" -o "$MODEL_FILE"
fi
[[ -s "$MODEL_FILE" ]] || die "Model download failed."
if [[ "$(stat -c%s "$MODEL_FILE" 2>/dev/null || wc -c < "$MODEL_FILE")" -lt 1000000000 ]]; then
  die "Model file is unexpectedly small; download may be incomplete. Remove ${MODEL_FILE} and rerun."
fi

cat > "${CONFIG_DIR}/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llamacpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local llama.cpp",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1",
        "apiKey": "local"
      },
      "models": {
        "qwen25-coder-7b-q4km": {
          "name": "Qwen2.5-Coder 7B Instruct Q4_K_M",
          "limit": { "context": 8192, "output": 2048 }
        }
      }
    }
  },
  "model": "llamacpp/qwen25-coder-7b-q4km"
}
JSON

if [[ ! -f "${HOME}/AGENTS.md" ]]; then
  cat > "${HOME}/AGENTS.md" <<'AGENTS'
# Local coding-agent safety defaults

- Inspect repository instructions, Git status, architecture, and tests before editing.
- Plan substantial changes first and make small, reviewable edits.
- Run relevant tests and report failures honestly.
- Never expose secrets or overwrite unrelated user changes.
- Do not force-push, delete branches, publish releases, deploy, or change remote settings without explicit approval.
- Review `git diff` before proposing a commit.
AGENTS
fi

cat > "${BIN_DIR}/qwen-code" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="${HOME}/.local/share/qwen-deck-agent"
BIN_DIR="${HOME}/.local/bin"
MODEL_FILE="${HOME}/Models/Qwen2.5-Coder-7B/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
export PATH="${APP_DIR}/node/bin:${APP_DIR}/npm/bin:${BIN_DIR}:${PATH}"
SERVER="${BIN_DIR}/llama-server"
if [[ ! -x "$SERVER" ]]; then echo "llama-server is missing. Rerun the installer." >&2; exit 1; fi
if ! curl -fsS http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
  echo "Starting local Qwen model server on 127.0.0.1:8080..."
  "$SERVER" -m "$MODEL_FILE" --alias qwen25-coder-7b-q4km -c 8192 -n 2048 -ngl 0 -np 1 \
    --host 127.0.0.1 --port 8080 > "${APP_DIR}/server.log" 2>&1 &
  echo $! > "${APP_DIR}/server.pid"
  for _ in $(seq 1 120); do
    if curl -fsS http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then break; fi
    sleep 1
  done
  if ! curl -fsS http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
    echo "Model server failed to start. Inspect ${APP_DIR}/server.log" >&2
    exit 1
  fi
fi
if ! command -v opencode >/dev/null 2>&1; then echo "OpenCode command not found. Reopen terminal or rerun installer." >&2; exit 1; fi
exec opencode "$@"
LAUNCHER
chmod +x "${BIN_DIR}/qwen-code"

DESKTOP_DIR="${HOME}/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cat > "${DESKTOP_DIR}/qwen-code.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Qwen Local Coding Agent
Comment=Start local Qwen2.5-Coder and OpenCode
Exec=${BIN_DIR}/qwen-code
Terminal=true
Categories=Development;
DESKTOP
chmod +x "${DESKTOP_DIR}/qwen-code.desktop"

log "Verify installation"
"${NODE_DIR}/bin/node" --version || true
"${BIN_DIR}/llama-server" --version || true
if [[ -x "${APP_DIR}/npm/bin/opencode" ]]; then
  "${APP_DIR}/npm/bin/opencode" --version || true
elif have opencode; then opencode --version || true; fi
printf '\nInstaller log: %s\n' "${APP_DIR}/install.log"
printf 'Model file: %s\n' "$MODEL_FILE"
printf 'OpenCode config: %s\n' "${CONFIG_DIR}/opencode.json"
printf '\nDONE. Start with: %s\n' "${BIN_DIR}/qwen-code"
printf 'For GitHub automation, install/authenticate gh separately; no credentials were stored.\n'
