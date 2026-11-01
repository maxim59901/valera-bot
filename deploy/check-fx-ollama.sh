#!/usr/bin/env bash
# Run on the FX-6400 Linux box: bash check-fx-ollama.sh
set -euo pipefail

echo "=== CPU ==="
lscpu | egrep 'Model name|Architecture|Flags|CPU\(s\)|Thread|Core' || true
echo
echo "AVX2 in flags?"
if lscpu | grep -qw avx2; then
  echo "YES — AVX2 present"
else
  echo "NO — AVX2 missing (typical for FX-6400)"
fi
echo "AVX in flags?"
if lscpu | grep -qw avx; then
  echo "YES — AVX present"
else
  echo "NO — AVX missing"
fi

echo
echo "=== RAM ==="
free -h || true

echo
echo "=== GPU ==="
lspci | egrep -i 'vga|3d|display' || true
echo
if command -v rocminfo >/dev/null 2>&1; then rocminfo | head -n 40; else echo "rocminfo: not installed"; fi
if command -v vulkaninfo >/dev/null 2>&1; then vulkaninfo --summary 2>/dev/null | head -n 40 || true; else echo "vulkaninfo: not installed"; fi

echo
echo "=== Ollama binary ==="
if command -v ollama >/dev/null 2>&1; then
  echo "ollama path: $(command -v ollama)"
  ollama --version || true
else
  echo "ollama: NOT FOUND in PATH"
fi

echo
echo "=== Ollama service / process ==="
systemctl is-active ollama 2>/dev/null || true
systemctl status ollama --no-pager -l 2>/dev/null | head -n 40 || true
pgrep -a ollama || echo "no ollama process"

echo
echo "=== Recent Ollama logs (AVX / illegal instruction) ==="
journalctl -u ollama -n 80 --no-pager 2>/dev/null | egrep -i 'avx|illegal|instruction|sigill|error|fail|gpu|vulkan|amd|rocm' || echo "(no matching journal lines)"
# also common install log locations
for f in /var/log/ollama.log "$HOME/.ollama/logs"*; do
  if [ -e "$f" ]; then
    echo "--- $f ---"
    egrep -i 'avx|illegal|instruction|sigill|error|fail' "$f" 2>/dev/null | tail -n 30 || true
  fi
done

echo
echo "=== API check ==="
curl -sS --max-time 3 http://127.0.0.1:11434/api/tags && echo || echo "API not responding on 127.0.0.1:11434"

echo
echo "=== Listen address ==="
ss -lntp 2>/dev/null | egrep '11434|8000' || netstat -lntp 2>/dev/null | egrep '11434|8000' || true

echo
echo "=== Quick generate smoke (may be slow) ==="
if curl -sS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  MODEL=$(curl -s http://127.0.0.1:11434/api/tags | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -n 1)
  if [ -n "${MODEL:-}" ]; then
    echo "Using model: $MODEL"
    curl -sS --max-time 120 http://127.0.0.1:11434/api/generate \
      -d "{\"model\":\"$MODEL\",\"prompt\":\"Say hi in one word\",\"stream\":false}" \
      | head -c 400
    echo
  else
    echo "No models pulled yet. Example: ollama pull hermes3:8b-q4_K_M"
  fi
else
  echo "Skip generate — API down"
fi

echo
echo "Done."
