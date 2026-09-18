# MacBoost — Engineering Refactor & Performance Architecture
### Target: MacBook Pro 13" Retina (MacBookPro10,2 - Late 2012 / Early 2013)
**macOS 15 Sequoia via OpenCore Legacy Patcher (OCLP)**

---

## 🔬 Deep Technical Mechanism: Cause & Effect Analysis

Every modification in this refactor is backed by exact kernel, scheduler, and IPC mechanics:

### 1. Granular Runtime Sysctl Validation (Replacing blind `sysctl -f`)
* **Problem in Prior Iteration:** Using `sysctl -f /dev/stdin` with silent redirects (`>/dev/null 2>&1`) hid fatal execution errors. In BSD/XNU, unknown OIDs or parameters that are read-only at runtime fail silently, while some sysctl tools halt processing on the first error if `-e` is absent.
* **Mechanism & Solution:** We iterate through each `key=value` pair:
  1. `sysctl "$key"` probes the XNU Management Information Base (MIB). If the OID does not exist in the current kernel build, it is logged as `[SKIP]` without raising an error.
  2. `sysctl -w "$key=$value"` applies the value. If rejected (e.g., read-only runtime tunable), the exact kernel error string is recorded in `/var/log/macboost_boot.log` as `[FAIL]`.
  3. Validated OIDs are logged as `[OK]`.
* **Kernel Effect:** Zero unrecognized parameter faults during boot; complete visibility via `macboost log`.

### 2. Balanced Power Management: Safe Sleep (`hibernatemode 3`) vs Pure RAM (`0`)
* **Problem in Prior Iteration:** Setting `hibernatemode 0` and locking `/var/vm/sleepimage` meant the machine resided purely in S3 sleep. If battery power drained completely during transport or a disconnected weekend, system memory contents were irrevocably lost, resulting in ungraceful shutdown, lost app states, and risk of APFS filesystem corruption. Furthermore, `autopoweroff 0` and `standby 0` prevented the SMC from entering deeper hardware low-power states.
* **Mechanism & Solution:**
  * **`hibernatemode 3` (Safe Sleep):** The kernel keeps RAM powered for instantaneous wake (<1s) upon opening the lid, while writing a memory snapshot to `/var/vm/sleepimage`. If battery power remains nominal, the disk image is never read. If power is exhausted, the EFI bootloader seamlessly restores the session from disk.
  * **`standby 1` & `autopoweroff 1` with Delays:** Configured `standbydelaylow 10800` (3 hours) and `standbydelayhigh 21600` (6 hours). When the laptop is left sleeping on battery, it remains in fast-wake RAM sleep for the first 3 to 6 hours. If unused beyond that window, it transitions into deep standby, cutting idle battery consumption significantly.
  * **`powernap 0` Maintained:** Prevents periodic DarkWake cycles (polling email, iCloud, backups) that spin up CPU frequencies and generate heat inside a closed laptop bag.

### 3. Account Dependencies & IPC Spin Prevention
* **Problem in Prior Iteration:** Forcefully disabling `cloudd`, `bird`, and `sharingd` while an iCloud account or Handoff is enabled in user preferences causes client processes (Finder, System Settings, Open/Save dialogs, third-party apps) to issue continuous Mach messages / XPC requests via `libxpc`. When `launchd` returns `XPC_ERROR_CONNECTION_INVALID`, poorly guarded client frameworks enter aggressive retry spin loops, burning CPU cycles and thrashing `os_log`.
* **Mechanism & Solution:** The script checks `MobileMeAccounts` for active Apple IDs. It programmatically sets:
  ```bash
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
  defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
  ```
  This signals the local Cocoa user activity frameworks to cease broadcasting and probing for Handoff/Continuity peers, avoiding client-side IPC retry loops.

### 4. Removal of Unverified Artifacts (UID 16908544)
* **Problem in Prior Iteration:** `launchctl bootout user/16908544` was copied from unverified community pastebins claiming an "OCLP phantom context". In macOS launchd architecture, system UIDs are <500, and user consoles start at 501. UID 16908544 (`0x01020300`) has no documented existence in Apple XNU or OCLP source code.
* **Solution:** Completely eliminated from codebase.

### 5. Sanitization of Legacy Iteration Leftovers
* All references to `com.legacy.thinclient`, `com.sleeper.sentinel`, `thinclient-boost`, and `thinclient-status` have been excised and replaced by the unified **`macboost`** architecture.

### 6. Conservative Mach Scheduler Renice (`-10` and `-5`)
* **Problem in Prior Iteration:** Pushing user applications (RDP, AnyDesk, Tailscale, Chrome) to nice `-18` and `-14` on a dual-core (2 physical cores / 4 threads) Ivy Bridge CPU creates severe thread contention with system-critical services.
* **Mechanism & Solution:**
  * In the Mach scheduler, `WindowServer` (the display compositor) runs around priority 49–51 (equivalent to nice -18/interactive), and `hidd` (human interface device daemon) handles real-time mouse/keyboard events.
  * If multi-threaded Electron/Chromium apps (Chrome, VS Code) and remote streaming pipelines (RDP, AnyDesk) are all forced to nice -18/-14, their worker threads flood the same priority runqueues. This causes **priority inversion** and **starvation** of the `WindowServer`, producing cursor micro-stutters and dropped frames.
  * **New Levels:**
    * **Tier 1 (-10):** Windows App (RDP), AnyDesk, Tailscale. Fast packet routing and remote rendering without preempting the desktop compositor.
    * **Tier 2 (-5):** Google Chrome, VS Code, WhatsApp, Terminal. Modest boost over standard nice (0), cleanly yielding to UI events.

---

## 🚀 Usage

Execute as root:

```bash
chmod +x optimize.sh
sudo ./optimize.sh
```

### Management Commands

* **`macboost`**: Applies conservative priorities to running work apps and prints real-time diagnostics.
* **`macboost boost`**: Re-applies priorities (-10 / -5) on demand.
* **`macboost status`**: Shows 1-minute load average, CPU thermal throttling percentage, free memory, and top CPU processes.
* **`macboost log`**: Displays the exact per-line sysctl validation log recorded at boot.
