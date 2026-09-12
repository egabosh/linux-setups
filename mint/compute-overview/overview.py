#!/usr/bin/env python3
"""compute-overview: lightweight LAN dashboard for compute.lan.

Serves a self-refreshing HTML page (JS polls /api) plus a JSON endpoint.
Shows CPU + RAM load, per-GPU use/VRAM/temperature (rocm-smi), the state of
the AI services (llama/comfyui/whisper/xtts/demucs) and all active TCP
connections sorted by service with the source client resolved.

Stdlib only - no third-party dependencies. Bind port is set via PORT_OPTION
(the systemd unit overrides the default: 8088).
"""

import glob
import io
import json
import os
import re
import socket
import subprocess
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "0.0.0.0"
PORT = 8086  # overridden by systemd env PORT_OPTION or hardcoded in the unit

# local service ports on this box -> (display name, kind)
PORT_MAP = {
    22: ("ssh", "admin"),
    80: ("traefik-local", "proxy"),
    8080: ("llama-server", "llm"),
    8081: ("searxng", "search"),
    8082: ("whisper-proxy", "stt-proxy"),
    8084: ("xtts-v2", "tts"),
    8085: ("demucs-separate", "stems"),
    8086: ("compute-overview", "dashboard"),
    8091: ("whisper-server", "stt"),
    8188: ("comfyui", "image"),
    5000: ("whoogle", "search"),
    9050: ("tor", "socks"),
    9998: ("tika", "doc"),
}

SERVICES = [  # systemd services to show as own rows
    ("llama-server", 8080),
    ("comfyui", 8188),
    ("whisper-server", 8091),
    ("whisper-openai-proxy", 8082),
    ("xtts-v2", 8084),
    ("demucs-separate", 8085),
]

CPU_SAMPLE_SEC = 0.5
GPU_CACHE_SEC = 2.0
PROC_SAMPLE_SEC = 1.2
TOP_PROCS = 15
CLK_TCK = float(os.sysconf("SC_CLK_TCK") or 100)
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE") or 4096
_RESOLVE_CACHE = {}
_GPU_CACHE = {"ts": 0.0, "data": None}
_PROC_CACHE = {"ts": 0.0, "data": None}
_SHOWPIDS_CACHE = {"ts": 0.0, "data": None}
_GPU_PDEV = None
_LLAMA_KEY = None  # cached shared Bearer key (None = not loaded yet)


def shell(cmd, timeout=6):
    """Run a shell command, return stdout stripped or '' on any failure."""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                           timeout=timeout)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def load_stats():
    """Parse /proc/loadavg into a 3-tuple of floats."""
    try:
        return tuple(float(x) for x in open("/proc/loadavg").read().split()[:3])
    except Exception:
        return (0.0, 0.0, 0.0)


def cpu_usage():
    """Per-core and total CPU usage in percent (delta over 0.5 s)."""
    def read():
        vals = {}
        for line in open("/proc/stat"):
            if line.startswith("cpu"):
                p = line.split()
                name = p[0]
                nums = [int(x) for x in p[1:9]]  # user..steal (guest folded in)
                idle = nums[3] + nums[4]
                vals[name] = (sum(nums), idle)
        return vals

    before = read()
    time.sleep(CPU_SAMPLE_SEC)
    after = read()
    out = {"total": 0.0, "cores": []}
    core_names = sorted(k for k in after if k != "cpu")
    for name in core_names:
        t0, i0 = before.get(name, (0, 0))
        t1, i1 = after[name]
        dt = max(t1 - t0, 1)
        out["cores"].append(int(100 * (1 - (i1 - i0) / dt)))
    t0, i0 = before.get("cpu", (0, 0))
    t1, i1 = after["cpu"]
    dt = max(t1 - t0, 1)
    out["total"] = int(100 * (1 - (i1 - i0) / dt))
    return out


def mem_info():
    """RAM + swap summary from /proc/meminfo."""
    info = {}
    for line in open("/proc/meminfo"):
        k, v = line.split(":")[0], int(line.split()[1])
        info[k] = v * 1024  # KiB -> bytes
    used = info["MemTotal"] - info["MemAvailable"]
    buf = info["SwapTotal"] - info["SwapFree"]
    return {
        "total": info["MemTotal"], "avail": info["MemAvailable"],
        "used": used, "pct": 100 * used // info["MemTotal"],
        "swap_total": info["SwapTotal"], "swap_used": buf,
    }


def gpu_stats():
    """GPU use/VRAM/temperature per card via rocm-smi (cached 2 s)."""
    now = time.time()
    if _GPU_CACHE["data"] and now - _GPU_CACHE["ts"] < GPU_CACHE_SEC:
        return _GPU_CACHE["data"]
    out = shell("rocm-smi --showuse --showmeminfo vram --showtemp", timeout=8)
    cards = {}
    for line in out.splitlines():
        m = re.match(r"GPU\[(\d+)\]\s*:\s([^:]+?)\s*:\s*(.+)", line)
        if not m:
            continue
        idx = int(m.group(1))
        key = m.group(2).strip()
        val = m.group(3).strip()
        c = cards.setdefault(idx, {"index": idx, "use": None,
                                   "vram_used": None, "vram_total": None,
                                   "temp": None})
        if key == "GPU use (%)":
            c["use"] = int(float(val))
        elif key == "VRAM Total Used Memory (B)":
            c["vram_used"] = int(float(val.replace(",", "")))
        elif key == "VRAM Total Memory (B)":
            c["vram_total"] = int(float(val.replace(",", "")))
        elif "temperature" in key.lower() and "edge" in key.lower():
            # temperature line: "Temperature (Sensor edge) (C): 53.0"
            try:
                c["temp"] = float(val)
            except ValueError:
                pass
    data = [cards[i] for i in sorted(cards)]
    _GPU_CACHE.update(ts=now, data=data)
    return data


def service_rows():
    """Active state, PID and RSS for each systemd service."""
    rows = []
    for name, port in SERVICES:
        active = shell(f"systemctl is-active {name}")
        pid = shell(f"systemctl show -p MainPID --value {name}")
        rss = "-"
        if pid.isdigit():
            v = shell(f"grep VmRSS /proc/{pid}/status")
            m = re.search(r"(\d+)\s*kB", v)
            if m:
                rss = int(m.group(1)) * 1024
        rows.append({"name": name, "port": port, "active": active,
                     "pid": pid or "-", "rss": rss})
    return rows


def peer_host(ip):
    """Resolve an IP to a hostname (cached, tolerant)."""
    if ip in _RESOLVE_CACHE:
        return _RESOLVE_CACHE[ip]
    host = ip
    try:
        host = socket.gethostbyaddr(ip)[0]
    except Exception:
        pass
    _RESOLVE_CACHE[ip] = host
    return host


def local_port(addr):
    """Extract the port (last colon part) from an ip:port address."""
    return addr.rsplit(":", 1)[1]


def connections():
    """Parse ss -tnp; group TCP states by service/local port."""
    out = shell("ss -tnp")
    rows = []
    for line in out.splitlines():
        if not line or line.startswith("State") or len(line.split()) < 5:
            continue
        parts = line.split(None, 5)
        state, local, peer = parts[0], parts[3], parts[4]
        proc = ""
        if len(parts) == 6:
            m = re.search(r'users:\(\("([^"]+)"', parts[5])
            if m:
                proc = m.group(1)
        try:
            lport = local_port(local)
        except Exception:
            continue
        name, kind = PORT_MAP.get(int(lport), (f"port-{lport}", "other"))
        p_ip = "localhost"
        p_port = ""
        if peer and not peer.endswith("*"):
            p_ip, _, p_port = peer.rpartition(":")
            p_ip = p_ip.lstrip("[").rstrip("]")
        # skip loopback peers (internal service-to-service traffic is noise)
        if p_ip in ("127.0.0.1", "::1") or p_ip.startswith("127."):
            continue
        rows.append({
            "service": name, "kind": kind, "state": state,
            "local": local, "remote": p_ip, "remote_port": p_port,
            "remote_host": peer_host(p_ip), "proc": proc,
        })
    return rows


def ffmpeg_procs():
    """Running ffmpeg processes (count + pid + command line)."""
    out = shell("ps ax -o pid=,args= | grep '[f]fmpeg'")
    procs = []
    for line in out.splitlines():
        p = line.split(None, 1)
        if p:
            procs.append({"pid": p[0], "cmd": p[1] if len(p) > 1 else ""})
    return procs


def _llama_key():
    """Shared llama.cpp Bearer key (LLAMA_API_KEY=...) from /etc, cached once.

    Returns '' when the file is missing/unreadable so callers degrade to an
    unauthenticated best-effort probe instead of crashing.
    """
    global _LLAMA_KEY
    if _LLAMA_KEY is None:
        key = ""
        try:
            with open("/etc/llama-server/api-key") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("LLAMA_API_KEY="):
                        key = line.split("=", 1)[1].strip()
                        break
        except OSError:
            pass
        _LLAMA_KEY = key
    return _LLAMA_KEY


def llama_slots():
    """Active llama.cpp generation slots (best effort)."""
    try:
        req = urllib.request.Request("http://127.0.0.1:8080/slots")
        key = _llama_key()
        if key:
            req.add_header("Authorization", "Bearer " + key)
        with urllib.request.urlopen(req, timeout=2) as r:
            data = json.loads(r.read().decode("utf-8", "replace"))
        return [{"id": s.get("id", "-"), "state": s.get("state", "-"),
                 "n_past": s.get("n_past", 0),
                 "task_id": s.get("task_id", "-")} for s in data]
    except urllib.error.HTTPError as e:
        return [{"id": "-", "state": f"HTTP {e.code}", "n_past": 0, "task_id": "-"}]
    except Exception:
        return []


def comfy_queue():
    """ComfyUI queue depth (best effort)."""
    try:
        with urllib.request.urlopen("http://127.0.0.1:8188/queue", timeout=2) as r:
            q = json.loads(r.read().decode("utf-8", "replace"))
        return {"running": len(q.get("queue_running", [])),
                "pending": len(q.get("queue_pending", []))}
    except Exception:
        return {"running": "-", "pending": "-"}


def suspend_events():
    """Suspend/resume history from /var/log/compute-sleep.log (managed by the
    compute-gpu-services.sh system-sleep hook), newest first.

    As a fallback for the current boot (when the log file has no entries yet),
    the kernel dmesg PM entries are included. Their monotonic timestamps are
    converted to wall-clock using /proc/uptime.
    """
    now = time.time()
    try:
        uptime = float(open("/proc/uptime").read().split()[0])
    except Exception:
        uptime = 0.0

    seen = {}   # (wall_sec_rounded, kind) -> entry   (dedup log vs dmesg)
    rows = []

    def _add(wall_str, phase, mode):
        key = (wall_str[:16], phase)  # minute + phase
        if key in seen:
            return
        seen[key] = True
        rows.append({"ts": wall_str, "phase": phase, "mode": mode})

    # 1) from the persistent sleep-hook log file
    try:
        with open("/var/log/compute-sleep.log") as f:
            for line in f:
                p = line.split()
                if len(p) < 3:
                    continue
                _add(" ".join(p[:2]), p[2], p[3] if len(p) > 3 else "-")
    except OSError:
        pass

    # 2) fallback: dmesg PM suspend entry / exit  (relative monotonic -> wall clock)
    if uptime > 0:
        out = shell("dmesg 2>/dev/null")
        for line in out.splitlines():
            m = re.match(r"\[([0-9]+\.[0-9]+)\]\s+PM: suspend (entry|exit)", line)
            if not m:
                continue
            rel = float(m.group(1))
            wall = now - uptime + rel
            if wall < 0:
                continue
            phase = "pre" if m.group(2) == "entry" else "post"
            mode = "deep"
            ts = time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(wall))
            _add(ts, phase, mode)

    rows.sort(key=lambda e: e["ts"], reverse=True)
    return rows[:20]


def llama_requests():
    """Last llama.cpp request arrivals from journald INFO log lines.

    Requires llama-server to run with -lv 3 (INFO) so each request produces a
    'processing task'/'prompt processing' slot line with a journal timestamp.
    Only the most recent entries are read (journald reads are cheap).
    """

    def run(cmd, timeout=8):
        try:
            r = subprocess.run(cmd, shell=True, capture_output=True,
                               text=True, timeout=timeout)
            return r.stdout
        except Exception:
            return ""

    # -o short-iso: timestamps; grep the slot INFO lines that fire once per task
    out = run("journalctl -u llama-server -o short-iso --no-pager "
              "-n 4000 2>/dev/null | grep -aE 'processing task|prompt processing' | tail -20")
    rows = []
    for line in out.splitlines():
        m = re.match(r"(\S{20,})\s+\S+\s+llama-server\[\d+\]:\s+(.*)", line)
        if not m:
            continue
        ts = m.group(1)
        if " " not in ts:
            ts = ts.replace("T", " ")
        rows.append({"ts": ts, "what": m.group(2).strip()[:90]})
    rows.reverse()
    return rows[:20]


def gpu_pdev_map():
    """PCI id (drm-pdev) -> GPU index for VRAM attribution via fdinfo."""
    global _GPU_PDEV
    if _GPU_PDEV:
        return _GPU_PDEV
    _GPU_PDEV = {}
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*")):
        try:
            pdev = os.path.basename(os.readlink(card + "/device"))
            idx = int(card.rsplit("card", 1)[1])
            _GPU_PDEV[pdev] = idx
        except (OSError, ValueError):
            continue
    return _GPU_PDEV


def proc_vram(pid):
    """VRAM bytes held by a process per GPU index (amdgpu fdinfo, cached map)."""
    per = {}
    try:
        fds = os.listdir("/proc/%d/fdinfo" % pid)
    except OSError:
        return per
    gmap = gpu_pdev_map()
    for fd in fds:
        try:
            with open("/proc/%d/fdinfo/%s" % (pid, fd)) as f:
                pdev, kb = None, 0
                for line in f:
                    if line.startswith("drm-pdev:"):
                        pdev = line.split()[-1]
                    elif line.startswith("drm-memory-vram:"):
                        kb = int(line.split()[1])
                if pdev and kb and pdev in gmap:
                    per[gmap[pdev]] = per.get(gmap[pdev], 0) + kb * 1024
        except (OSError, ValueError):
            continue
    return per


def proc_snapshot():
    """One /proc scan: pid -> cpu ticks, io bytes, rss, comm, cmdline."""
    snap = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        p = "/proc/" + name
        try:
            with open(p + "/stat") as f:
                st = f.read()
            rp = st.rfind(")")
            core = st[rp + 2:].split()
            if len(core) < 13 or core[0] == "Z":
                continue
            comm = st[st.find("(") + 1:rp][:24]
            ticks = int(core[11]) + int(core[12])
            with open(p + "/statm") as f2:
                rss = int(f2.read().split()[1]) * PAGE_SIZE
        except (OSError, ValueError, IndexError):
            continue
        io = 0
        try:
            for line in open(p + "/io"):
                if line.startswith("read_bytes") or line.startswith("write_bytes"):
                    io += int(line.split()[-1])
        except (OSError, ValueError):
            pass
        cmd = ""
        try:
            cmd = open(p + "/cmdline").read().replace("\0", " ").strip()[:70]
        except OSError:
            pass
        snap[int(name)] = {"comm": comm, "ticks": ticks, "io": io,
                           "rss": rss, "cmd": cmd or comm}
    return snap


def top_procs():
    """Top processes: four separate rankings CPU / VRAM per GPU / RAM / I/O.

    One sampling pass feeds four independently sorted top-15 lists (momentary
    CPU %, per-GPU VRAM via amdgpu fdinfo, RSS and I/O read+write rate).
    """
    now = time.time()
    if _PROC_CACHE["data"] and now - _PROC_CACHE["ts"] < 2.5:
        return _PROC_CACHE["data"]
    s1 = proc_snapshot()
    time.sleep(PROC_SAMPLE_SEC)
    s2 = proc_snapshot()
    rows = []
    for pid, a in s1.items():
        b = s2.get(pid)
        if not b:
            continue
        cpu = 100.0 * (b["ticks"] - a["ticks"]) / CLK_TCK / PROC_SAMPLE_SEC
        io = (b["io"] - a["io"]) / PROC_SAMPLE_SEC
        rows.append({"pid": pid, "comm": a["comm"], "cmd": a["cmd"],
                     "cpu": round(cpu, 1), "rss": b["rss"], "io": int(io),
                     "vram": proc_vram(pid)})

    def vram_max(r):
        return max(r["vram"].values()) if r["vram"] else 0

    def rank(key, top=TOP_PROCS):
        return sorted(rows, key=key, reverse=True)[:top]

    out = {
        "cpu": rank(lambda r: r["cpu"]),
        "vram": rank(vram_max),
        "ram": rank(lambda r: r["rss"]),
        "io": rank(lambda r: r["io"]),
    }
    _PROC_CACHE.update(ts=now, data=out)
    return out


def gpu_pids():
    """Processes holding VRAM (KFD contexts) from 'rocm-smi --showpids'.

    Each row: pid, process name (as reported by rocm-smi), the real comm +
    cmdline from /proc, VRAM total and per-GPU VRAM (amdgpu fdinfo). Only
    processes with an active KFD context show up (cached, same intervall as
    gpu_stats).
    """
    now = time.time()
    if _SHOWPIDS_CACHE["data"] and now - _SHOWPIDS_CACHE["ts"] < GPU_CACHE_SEC:
        return _SHOWPIDS_CACHE["data"]
    out = shell("rocm-smi --showpids", timeout=8)
    rows = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 6 or not parts[0].strip().isdigit():
            continue
        pid = int(parts[0])
        name = parts[1].strip()
        comm = cmd = ""
        try:
            comm = open("/proc/%d/comm" % pid).read().strip()
            cmd = open("/proc/%d/cmdline" % pid).read().replace("\0", " ").strip()
            if len(cmd) > 80:
                cmd = cmd[:80]
        except OSError:
            pass
        try:
            vram = int(float(parts[3].strip().replace(",", "")))
        except ValueError:
            vram = 0
        try:
            ngpu = int(parts[2].strip())
        except ValueError:
            ngpu = 0
        rows.append({"pid": pid, "name": name or comm or "-",
                     "comm": comm or name or "-",
                     "cmd": cmd or comm or name or "-",
                     "gpus": ngpu, "vram": vram,
                     "vram_gpu": proc_vram(pid)})
    rows.sort(key=lambda r: r["vram"], reverse=True)
    _SHOWPIDS_CACHE.update(ts=now, data=rows)
    return rows


def temps():
    """CPU temp (k10temp) plus extra hwmon sensors (RAM/NVMe/NIC/board)."""
    cpu = None
    extras = []
    seen = {}
    friendly = {"spd5118": "RAM", "nvme": "NVMe", "r8169": "NIC",
                "asus": "Board"}
    for d in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        try:
            name = open(d + "/name").read().strip()
        except OSError:
            continue
        for tin in sorted(glob.glob(d + "/temp*_input")):
            try:
                v = float(open(tin).read()) / 1000.0
            except (OSError, ValueError):
                continue
            if not (1 <= v <= 110):
                continue
            if name == "k10temp":
                if cpu is None:
                    cpu = v
                continue
            if name == "amdgpu":  # GPU temps come from rocm-smi
                continue
            lbl = ""
            try:
                lbl = open(tin.replace("_input", "_label")).read().strip()
            except OSError:
                pass
            kind = friendly.get(name, lbl or name)
            seen[kind] = seen.get(kind, 0) + 1
            entry = kind if seen[kind] == 1 else "%s %d" % (kind, seen[kind])
            extras.append({"name": entry, "temp": round(v, 1)})
    extras.sort(key=lambda e: e["name"])
    return {"cpu": round(cpu, 1) if cpu is not None else None,
            "extras": extras[:5]}


def uptime_str():
    """Format /proc/uptime as days/hours/minutes."""
    try:
        secs = int(float(open("/proc/uptime").read().split()[0]))
    except Exception:
        return "-"
    return f"{secs // 86400}d {(secs % 86400) // 3600}h {(secs % 3600) // 60}m"


def collect():
    """Assemble the full JSON payload for /api."""
    return {
        "ts": time.strftime("%H:%M:%S"),
        "hostname": socket.gethostname(),
        "uptime": uptime_str(),
        "load": load_stats(),
        "cpu": cpu_usage(),
        "mem": mem_info(),
        "gpus": gpu_stats(),
        "services": service_rows(),
        "connections": connections(),
        "ffmpeg": ffmpeg_procs(),
        "llama_slots": llama_slots(),
        "comfy_queue": comfy_queue(),
        "procs": top_procs(),
        "gpu_pids": gpu_pids(),
        "temps": dict(temps(), gpu=[g.get("temp") for g in gpu_stats()]),
        "suspend": suspend_events(),
        "llama_requests": llama_requests(),
    }


class Handler(BaseHTTPRequestHandler):
    """Serve the HTML page and the JSON API."""

    def log_message(self, fmt, *args):
        pass  # keep journal quiet

    def do_GET(self):
        if self.path == "/api":
            body = json.dumps(collect()).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)


# --- static HTML page (JS polls /api every 3 s) -----------------------------
PAGE = """<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>compute.lan Overview</title>
<style>
  body { background:#0f1116; color:#d7dae0; font:14px/1.4 ui-monospace,Menlo,monospace;
         margin:0; padding:16px; }
  h1 { font-size:18px; margin:0 0 4px; color:#fff; }
  h2 { font-size:13px; margin:16px 0 6px; color:#8ab4f8; }
  h3 { font-size:12px; margin:12px 0 4px; color:#ffd28f; font-weight:normal; }
  .sub { color:#8a94a3; margin-bottom:12px; font-size:12px; }
  .cards { display:flex; gap:10px; flex-wrap:wrap; }
  .card { background:#171a21; border:1px solid #2a2f3a; border-radius:8px;
          padding:10px 12px; min-width:180px; }
  .card b { display:block; font-size:22px; }
  .bar { background:#232833; border-radius:4px; height:10px; margin-top:6px; }
  .bar > i { display:block; height:10px; border-radius:4px;
             background:#4f7dff; }
  .hot { color:#ff7d6b; }
  table { border-collapse:collapse; width:100%; font-size:12px; }
  th,td { text-align:left; padding:4px 8px; border-bottom:1px solid #222634; }
  th { color:#8a94a3; font-weight:normal; }
  .ok { color:#7ee787; } .down { color:#ff7d6b; } .idle { color:#a0a8b5; }
  .top { color:#ff7d6b; }
  .charts { display:flex; gap:16px; flex-wrap:wrap; }
  .panel { background:#171a21; border:1px solid #2a2f3a; border-radius:8px;
           padding:10px 12px; flex:1 1 420px; }
  .ptitle { margin-bottom:6px; }
  .ptitle b { color:#fff; }
  .ptitle span { color:#8a94a3; font-size:11px; float:right; }
  svg { width:100%; height:150px; display:block; }
  .cmd { color:#8a94a3; font-size:11px; }
</style>
</head>
<body>
<h1>compute.lan Overview</h1>
<div class="sub" id="meta">loading...</div>

<h2>Auslastung</h2>
<div class="cards" id="cards"></div>

<h2>Aktuelle Last: Top-Prozesse</h2>
<div class="sub">je Ranking separat (Top-15): CPU / VRAM pro GPU / RAM / I/O</div>
<h3>nach CPU</h3>
<table id="pcpu"><thead><tr><th>PID</th><th>CPU %</th><th>Prozess</th></tr></thead>
<tbody></tbody></table>
<h3>VRAM pro GPU</h3>
<table id="pvram"><thead></thead><tbody></tbody></table>
<h3>nach RAM</h3>
<table id="pram"><thead><tr><th>PID</th><th>RAM</th><th>Prozess</th></tr></thead>
<tbody></tbody></table>
<h3>I/O</h3>
<table id="pio"><thead><tr><th>PID</th><th>I/O</th><th>Prozess</th></tr></thead>
<tbody></tbody></table>

<h2>Verlauf (letzte 90 s)</h2>
<div class="charts">
  <div class="panel"><div class="ptitle"><b>VRAM pro GPU</b>
    <span id="leg-vram"></span></div>
    <svg id="sv-vram" viewBox="0 0 640 150" preserveAspectRatio="none"></svg></div>
  <div class="panel"><div class="ptitle"><b>Temperaturen</b>
    <span id="leg-temp"></span></div>
    <svg id="sv-temp" viewBox="0 0 640 150" preserveAspectRatio="none"></svg></div>
</div>

<h2>Dienste</h2>
<table id="svc"><thead><tr><th>Dienst</th><th>Port</th><th>Status</th>
<th>PID</th><th>RSS</th></tr></thead><tbody></tbody></table>

<h2>GPU-Prozesse (rocm-smi --showpids)</h2>
<div class="sub">Prozesse mit aktivem KFD-Kontext (VRAM-Nutzung), zugeordnet pro GPU</div>
<table id="gpids"><thead><tr><th>PID</th><th>Name</th><th>GPUs</th>
<th>VRAM gesamt</th><th>VRAM je GPU</th><th>Prozess</th></tr></thead>
<tbody></tbody></table>

<h2>llama.cpp Slots</h2>
<table id="slots"><thead><tr><th>#</th><th>State</th><th>Tokens</th>
<th>Task</th></tr></thead><tbody></tbody></table>

<h2>Suspend / Resume (Letzte Ereignisse)</h2>
<div class="sub">aus /var/log/compute-sleep.log vom systemd Sleep-Hook (pre=suspend eingeleitet, post=wieder wach)</div>
<table id="sleep"><thead><tr><th>Zeit</th><th>Phase</th><th>Modus</th>
</tr></thead><tbody></tbody></table>

<h2>Letzte llama.cpp-Anfragen</h2>
<div class="sub">aus journald (llama-server -lv 3: 'processing task'/'prompt processing' Slot-Logs)</div>
<table id="llreq"><thead><tr><th>Zeit</th><th>Task</th>
</tr></thead><tbody></tbody></table>

<h2>Aktive Verbindungen</h2>
<table id="conn"><thead><tr><th>Dienst</th><th>State</th><th>Lokal</th>
<th>Quelle/Client</th><th>Host</th><th>Prozess</th></tr></thead>
<tbody></tbody></table>

<script>
function el(t){return document.getElementById(t);}
function fmtB(n){if(n==null||n==="-"||n==="-")return n;
  if(n<0)return "-"; if(n>1073741824)return (n/1073741824).toFixed(1)+" GiB";
  if(n>1048576)return (n/1048576).toFixed(1)+" MiB";
  return (n/1024).toFixed(0)+" KiB";}
function fmtK(n){if(!n)return "-"; if(n>1048576)return (n/1048576).toFixed(1)+" MiB/s";
  return (n/1024).toFixed(0)+" KiB/s";}
function bar(pct,units){
  const p=Math.min(100,Math.max(0,pct));
  const style=p>90?"background:#ff6b57":(p>70?"background:#ffb84d":"background:#4f7dff");
  return '<div class="bar"><i style="width:'+p+'%;'+style+'">'+units+'</i></div>';}
function drawChart(svg, series, colors, ymax){
  svg.innerHTML="";
  const w=640,h=150,pad=6;
  let n=0;
  series.forEach(s=>{n=Math.max(n,(s||[]).length);});
  if(n<2||!ymax)return;
  let grid="";
  [0.25,0.5,0.75].forEach(f=>{
    const y=pad+(1-f)*(h-2*pad);
    grid+='<line x1="'+pad+'" y1="'+y+'" x2="'+(w-pad)+'" y2="'+y+
      '" stroke="#232833" stroke-width="1"/>';});
  let lines="";
  series.forEach((s,ci)=>{
    if(!s||s.length<2)return;
    const pts=s.map((v,i)=>[(pad+(i/(n-1))*(w-2*pad)).toFixed(1),
      (pad+(1-Math.min(1,Math.max(0,v)/ymax))*(h-2*pad)).toFixed(1)]);
    const poly=pts.map(p=>p[0]+","+p[1]).join(" ");
    lines+='<polyline points="'+poly+'" fill="none" stroke="'+colors[ci]+
      '" stroke-width="2"/>';});
  svg.innerHTML=grid+lines;
}
let hist=[];
function pushHist(d){
  const vr=(d.gpus||[]).map(g=>({used:g.vram_used||0,total:g.vram_total||0}));
  const tm={cpu:((d.temps||{}).cpu||null),
            gpu:(d.gpus||[]).map(g=>g.temp),
            extra:(d.temps||{}).extras?d.temps.extras.map(e=>e.temp):[]};
  hist.push({vr,tm});
  if(hist.length>90)hist.shift();
}
function maxUsed(){let m=0;(hist||[]).forEach(h=>h.vr.forEach(v=>m=Math.max(m,v.used)));return m;}
function maxTemp(){let m=0;(hist||[]).forEach(h=>{
  if(h.tm.cpu)m=Math.max(m,h.tm.cpu);
  h.tm.gpu.forEach(g=>{if(g)m=Math.max(m,g);});
  h.tm.extra.forEach(e=>m=Math.max(m,e));});
  return m;}
function drawCharts(){
  const seriesV=[hist.map(h=>h.vr[0]?h.vr[0].used:0),
                 hist.map(h=>h.vr[1]?h.vr[1].used:0)];
  drawChart(el("sv-vram"),seriesV,["#4f7dff","#ff9f43"],
    Math.max(25*1073741824,maxUsed()*1.2));
  const seriesT=[hist.map(h=>h.tm.cpu||0),
                 hist.map(h=>h.tm.gpu[0]||0),
                 hist.map(h=>h.tm.gpu[1]||0)];
  drawChart(el("sv-temp"),seriesT,["#7ee787","#4f7dff","#ff9f43"],
    Math.max(70,maxTemp()*1.1));
}
function load(){
  fetch("/api").then(r=>r.json()).then(d=>{
    el("meta").textContent=d.hostname+" | uptime "+d.uptime+
      " | load "+d.load.map(x=>x.toFixed(2)).join(" / ")+
      " | aktualisiert "+d.ts;

    const cpu=d.cpu, mem=d.mem;
    let h='<div class="card">Load (1/5/15) <b>'+d.load[0].toFixed(2)+"</b>"+
      '<div style="font-size:10px">'+d.load[1].toFixed(2)+" / "+d.load[2].toFixed(2)+
      "</div></div>";
    h+='<div class="card">CPU Kern <b>'+cpu.total+'%</b>'+
      bar(cpu.total," ")+'<div style="font-size:10px">'+
      cpu.cores.map((c,i)=>i+": "+c+"%").join("  ")+'</div></div>';
    h+='<div class="card">RAM <b>'+mem.pct+'%</b>'+
      bar(mem.pct," ")+'<div style="font-size:10px">'+
      fmtB(mem.used)+" von "+fmtB(mem.total)+
      (mem.swap_used>0?" | Swap "+fmtB(mem.swap_used):"")+'</div></div>';
    d.gpus.forEach(g=>{
      const up=g.vram_total?100*g.vram_used/g.vram_total:0;
      h+='<div class="card">GPU['+g.index+'] <b>'+
        (g.use==null?"-":g.use+"%")+'</b>'+bar(g.use||0," ")+
        '<div style="font-size:10px">'+(g.temp==null?"":g.temp+" C | ")+
        (g.vram_total?fmtB(g.vram_used)+" / "+fmtB(g.vram_total)+" ("+up.toFixed(0)+"%)":"")+
        '</div></div>';
    });
    if(d.llama_slots&&d.llama_slots.length){
      h+='<div class="card">llama Slots <b>'+d.llama_slots.length+'</b>'+
        '<div style="font-size:10px">'+d.llama_slots.map(s=>s.id+": "+s.state).
        join(" | ")+"</div></div>";}
    if(d.comfy_queue){
      h+='<div class="card">ComfyUI Queue <b>'+
        d.comfy_queue.running+'</b><div style="font-size:10px">'+d.comfy_queue.pending+
        " pending</div></div>";}
    if(d.ffmpeg && d.ffmpeg.length){
      const ft=d.ffmpeg.map(f=>f.pid).join(", ");
      h+='<div class="card ffmpegx">ffmpeg <b style="color:#ff7d6b">'+d.ffmpeg.length+
        '</b><div style="font-size:10px">PID '+ft+"</div></div>";}
    if(d.temps&&d.temps.cpu!=null){
      h+='<div class="card">CPU Temp <b>'+d.temps.cpu+'&deg;C</b></div>';}
    el("cards").innerHTML=h;

    const pc=d.procs||{};
    function procsTbl(tbl,list,colAn){
      const tb=tbl.querySelector("tbody");
      tb.innerHTML="";
      (list||[]).forEach(r=>{
        const tr=document.createElement("tr");
        tr.innerHTML="<td>"+r.pid+"</td>"+colAn(r)+
          "<td><span class='idle'>"+r.comm+"</span> <span class='cmd'>"+
          r.cmd+"</span></td>";
        tb.appendChild(tr);
      });
    }
    function procCell(v,mark){return "<td>"+(v==null?"-":v)+(mark||"")+"</td>";}
    procsTbl(el("pcpu"),pc.cpu,r=>procCell(
      "<span class='"+(r.cpu>=100?"hot":"")+"'>"+r.cpu.toFixed(1)+"</span>"));
    procsTbl(el("pram"),pc.ram,r=>procCell(fmtB(r.rss)));
    let mxI=0;(pc.io||[]).forEach(r=>mxI=Math.max(mxI,r.io));
    procsTbl(el("pio"),pc.io,r=>procCell(fmtK(r.io),
      r.io>=mxI&&r.io>0?"<span class='top'>&#9650;</span>":""));
    const gkeys=[...new Set((pc.vram||[]).flatMap(r=>Object.keys(r.vram||{})))].map(Number).sort((a,b)=>a-b);
    el("pvram").querySelector("thead").innerHTML="<tr><th>PID</th>"+
      gkeys.map(k=>"<th>GPU["+k+"]</th>").join("")+"<th>Prozess</th></tr>";
    const mxv={};gkeys.forEach(k=>mxv[k]=Math.max(0,...(pc.vram||[]).map(r=>r.vram[k]||0)));
    procsTbl(el("pvram"),pc.vram,r=>gkeys.map(k=>{
      const v=r.vram[k]||0;
      return procCell(fmtB(v),v>=mxv[k]&&v>0?"<span class='top'>&#9650;</span>":"");
    }).join(""));

    el("gpids").querySelector("tbody").innerHTML="";
    (d.gpu_pids||[]).forEach(r=>{
      const gk=Object.keys(r.vram_gpu||{}).map(Number).sort((a,b)=>a-b);
      const vstr=gk.length?gk.map(k=>"GPU["+k+"]="+fmtB(r.vram_gpu[k])).join(" "):"-";
      const tr=document.createElement("tr");
      tr.innerHTML="<td>"+r.pid+"</td><td>"+r.name+"</td><td>"+
        (r.gpus?r.gpus:"-")+"</td><td>"+(r.vram?fmtB(r.vram):"-")+
        "</td><td>"+vstr+"</td><td><span class='cmd'>"+r.cmd+
        "</span></td>";
      el("gpids").querySelector("tbody").appendChild(tr);
    });

    const tb=el("svc").querySelector("tbody");
    tb.innerHTML="";
    d.services.forEach(s=>{
      const cls=s.active==="active"?"ok":"down";
      const tr=document.createElement("tr");
      tr.innerHTML="<td>"+s.name+"</td><td>"+s.port+"</td>"+
        '<td class="'+cls+'">'+s.active+"</td><td>"+s.pid+"</td><td>"+
        fmtB(s.rss)+"</td>";
      tb.appendChild(tr);
    });

    const sb=el("slots").querySelector("tbody");
    sb.innerHTML="";
    d.llama_slots.forEach(s=>{
      const tr=document.createElement("tr");
      const cls=s.state==="idle"?"idle":"ok";
      tr.innerHTML="<td>"+s.id+"</td><td class='"+cls+"'>"+s.state+
        "</td><td>"+s.n_past+"</td><td>"+s.task_id+"</td>";
      sb.appendChild(tr);
    });

    const ep=el("sleep").querySelector("tbody");
    ep.innerHTML="";
    (d.suspend||[]).forEach(e=>{
      const tr=document.createElement("tr");
      const cls=e.phase==="post"?"ok":"top";
      tr.innerHTML="<td>"+e.ts+"</td><td class='"+cls+"'>"+e.phase+
        "</td><td>"+e.mode+"</td>";
      ep.appendChild(tr);
    });
    if(!(d.suspend||[]).length){
      const tr=document.createElement("tr");
      tr.innerHTML="<td colspan='3' class='idle'>noch keine Ereignisse</td>";
      ep.appendChild(tr);
    }

    const qb=el("llreq").querySelector("tbody");
    qb.innerHTML="";
    (d.llama_requests||[]).forEach(r=>{
      const tr=document.createElement("tr");
      tr.innerHTML="<td>"+r.ts+"</td><td><span class='cmd'>"+r.what+
        "</span></td>";
      qb.appendChild(tr);
    });
    if(!(d.llama_requests||[]).length){
      const tr=document.createElement("tr");
      tr.innerHTML="<td colspan='2' class='idle'>noch keine Anfragen erfasst</td>";
      qb.appendChild(tr);
    }

    const cb=el("conn").querySelector("tbody");
    cb.innerHTML="";
    d.connections.forEach(c=>{
      if(c.state==="LISTEN")return;
      const tr=document.createElement("tr");
      tr.innerHTML="<td>"+c.service+' <span style="color:#8a94a3">('+
        c.kind+")</span></td><td>"+c.state+"</td><td>"+c.local+"</td><td>"+
        (c.remote==="localhost"?c.remote:c.remote+":"+c.remote_port)+
        "</td><td>"+(c.remote==="localhost"?"-":c.remote_host)+
        "</td><td>"+c.proc+"</td>";
      cb.appendChild(tr);
    });

    pushHist(d);
    el("leg-vram").textContent=(d.gpus||[]).map(g=>
      "GPU["+g.index+"] "+fmtB(g.vram_used)+" / "+fmtB(g.vram_total)).join("   ");
    const t=d.temps||{};
    el("leg-temp").textContent="CPU "+(t.cpu!=null?t.cpu:"-")+" C"+
      (d.gpus||[]).map(g=>" | GPU["+g.index+"] "+(g.temp!=null?g.temp:"-")).join("")+
      (t.extras&&t.extras.length?
        " | "+t.extras.map(e=>e.name+" "+e.temp).join(" | "):"");
    drawCharts();
  }).catch(()=>{});
}
setInterval(load,3000);
load();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    # PORT_OPTION overrides: env wins over the compiled-in default
    if os.environ.get("PORT_OPTION"):
        PORT = int(os.environ["PORT_OPTION"])
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"compute-overview listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()