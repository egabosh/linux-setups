# WARNING: All your data will be deleted!!!
# install mint
- boot from Mint medium (https://linuxmint-installation-guide.readthedocs.io/en/latest/burn.html)
- click on install

## for encrypted disk
- at "Installation type" choose "Erase disk and install Linux Mint" and "Advanced features"
- Check "Use LVM with the new Linux Mint installation" and "Encrypt the new Linux Mint installation for security"
- follow further instructions
- possibly use user autologin and home without encryption because the LVM volume underneath is already encrypted.

# after installation (if you want to use my setup)
boot the new installed linux mint system
## deactivate optional DoHoT
```
date | sudo tee /etc/dontusedohot
```
## set your domainname and your target server if you want to use x11vnc with SSH
```
# domain for the system
echo "subdomain.domain.tld" | sudo tee /etc/mydomain
# host which should be connected with x11vnc over SSH
echo "user@target-ssh-server-for-x11vnc-ssh" | sudo tee /etc/x11vnc-ssh-target
```
## download and run my setup scripts:
```
wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/mint/mint.sh
bash mint.sh
```
better reboot after first run to see more verbose boot progress and load changed Cinnamon design

# AI services on compute.lan (2x RX 7900 XTX = 48 GiB VRAM, Ryzen 9 9950X)

All services are deployed as Ansible playbooks from this `mint/` directory.
GPU[0]/GPU[1] selection happens via `HIP_VISIBLE_DEVICES` (ROCm/HIP has NO automatic
"use the free GPU" selection; without a pin every service uses device 0). llama.cpp alone
uses both GPUs via `--split-mode layer`. Deployment order: `compute-node-install.sh`.

## Ports, models & access

| Service (systemd) | Local port | Public (via Traefik on 172.23.0.222) | Auth | Model / draft head | Type |
|-------------------|------------|--------------------------------------|------|--------------------|------|
| llama-server | 8080 | `https://llm.<public-domain>` | Bearer | `Qwen3.8-27B-Uncensored-Q5_K_M.gguf` (17.9 GiB) + `mtp-Qwen3.8-27B-Uncensored.gguf` (mtp-RVN, 1.7 GiB) + `mmproj-Qwen3.8-27B-Uncensored-f16.gguf` (0.6 GiB) | Chat LLM, vision, uncensored, 262136 native context, `--parallel 2` |
| comfyui | 8188 | `https://comfyui.<public-domain>` | LAN/docker IPs only (`allowlocalipsonly`, external = 403) | `sd15.safetensors` (SD1.5 fp16) + `qwen_3_4b.safetensors`/`z_image_turbo_bf16.safetensors`/`ae.safetensors` (Z-Image-Turbo) | Text-to-image (worksheet graphics), HTTPS via Traefik; OpenWebUI talks to it over `https://comfyui.<public-domain>` (hairpin). No auth (RPC surface) -> restricted to local IPs |
| whisper-server | 8091 | - | localhost only | `ggml-large-v3-turbo` (whisper.cpp) | Speech-to-text backend |
| whisper-openai-proxy | 8082 | `https://stt.<public-domain>` | Bearer | - | OpenAI-compatible STT proxy (forwards to whisper-server 8091) |
| xtts-v2 | 8084 | `https://tts.<public-domain>` | Bearer | Coqui XTTS-v2 (multi-speaker, native venv, no Docker) | Text-to-speech |
| searxng-docker | 8081 | - | - | - | Meta search engine (host port 8081 -> container 8080) |
| tika-docker | 9998 | - | - | Apache Tika | Content/Document metadata extraction |
| piper-tts | (local) | - | - | Piper (CPU only) | Lightweight TTS |
| demucs-separate | 8085 | (LAN only, no public route yet) | Bearer | `htdemucs` (+ FT / 6s / mdx_extra variants, DL-init, CPU only) | Music stem separation (vocals/drums/bass), REST API + `g_stems` bash function |

## Demucs stem separation (CPU)
- Playbook: `demucs-separate-cpu.yml`, venv at `/opt/demucs/venv`, service `demucs-separate`, port 8085.
- **CLI helper:** `g_stems` from gaboshlib (`g_tts.bashfunc`-style function), e.g. `g_stems -i song.mp3 -o out/ -s vocals`.
- **API:** `POST /v1/audio/separation` with `multipart/form-data` (field `file`, optional `model`, `two_stems`, `format=zip|json`) or a JSON body `{"audio_b64": "...", "filename": "...", "model": "...", "two_stems": "..."}`.
  Requires `Authorization: Bearer <key>` (same key as llm/stt/tts). Default answer is a ZIP of stem wavs; `X-Stems` header lists the stems.
- `GET /health` stays open for monitoring; `GET /v1/models` (Bearer) lists the available models.
- One job at a time, model is loaded per request in a subprocess (no RAM pinned between jobs) - designed for the current low-RAM situation. Torch CPU wheels, ~80 MB model, RAM peak ~1-1.5 GB per job.

## Authentication (all three AI services use the SAME Bearer key)
- All keys come from one file: `/etc/llama-server/api-key` on compute.lan (format `LLAMA_API_KEY=<64 hex>`, mode 0640 root:llama).
- llama.cpp validates natively (`--api-key`); whisper/xtts proxies check `Authorization: Bearer <key>` against the same file.
- Clients (OpenWebUI and manually) must send `Authorization: Bearer <key>` - identical for llm/stt/tts.
- Health endpoints stay open for monitoring: `https://tts.<public-domain>/health`, `https://llm.<public-domain>/health`.

## Traefik routing (host 172.23.0.222, ssh -p33)
File providers in `/home/docker/traefik/providers/` (mirror: `debian/traefik.server/providers/`, synced via scp, FQDNs stripped for privacy):
- `llm.<public-domain>.yml` -> `http://172.23.0.225:8080`
- `stt.<public-domain>.yml` -> `http://172.23.0.225:8082`
- `tts.<public-domain>.yml` -> `http://172.23.0.225:8084`
Traefik watches the directory (no container restart needed). Backends return 502 while compute.lan sleeps (WoL).

Note: whisper-server intentionally uses 8091, not 8081 (8081 is taken by SearXNG).

## Planned memory usage (48 GiB VRAM + RAM)

VRAM (GPU[0]+GPU[1] together):
- llama worst case (full 256K context): ~34-35 GiB across both GPUs (model 17.9 + MTP 1.7 + mmproj 0.6 + KV q4_0 12.6 + overhead). KV is dynamic, typical chat sessions use only ~3-6 GiB -> realistic ~23-26 GiB.
- ComfyUI SD1.5 on GPU[1]: ~6-7 GiB peak during image generation.
- XTTS-v2 on GPU[1]: ~3 GiB. Whisper on GPU[1]: ~2 GiB.
- Total planned: fits 48 GiB. Fallback if llama at full context + simultaneous image+TTS hits the limit: reduce llama context to 200704 (saves ~2.7 GiB) or quant to Q4_K_M (saves ~2.5 GiB).

RAM (system + all services, two users):
- 32 GiB (2x16): sufficient for the whole parallel stack (llama peaks >3.5 GiB alone at startup; total ~10-15 GiB loaded).
- 64 GiB (2x32, RECOMMENDED): removes all RAM pressure during high-res ComfyUI generations, 256K sessions of both users, and future larger models.
- Current 8 GiB DIMM is NOT enough - install at least 32 GiB before relying on this box.

Same info lives in `mint/AGENTS.md` (kept as the operating reference).
