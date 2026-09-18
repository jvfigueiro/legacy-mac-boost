# MacBoost: System Optimization Suite for MacBookPro10,2

Target Platform: macOS 15 Sequoia via OpenCore Legacy Patcher (OCLP)  
Target Hardware: MacBook Pro 13" Retina (Late 2012 / Early 2013 - MacBookPro10,2)  
Specifications: Intel Core i5-3210M (Ivy Bridge 2C/4T @ 2.5-3.1 GHz), 8 GB DDR3L RAM, Intel HD Graphics 4000, 2560x1600 Retina Display  

---

## Disclaimer and Liability

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

EXECUTION OF THIS SCRIPT MODIFIES SYSTEM-LEVEL DAEMONS, KERNEL PARAMETERS, POWER SETTINGS, AND SECURITY SUBSYSTEMS. IT IS PROVIDED WITHOUT ANY GUARANTEE OF STABILITY AND MUST BE USED ENTIRELY AT YOUR OWN RISK.

---

## Attribution and Acknowledgements

This project is directly inspired by and builds upon the research, testing, and methodology shared by Reddit user **TeckFire** for optimizing 2012 Retina MacBook Pros running modern macOS releases:

* Reference Resource: [TeckFire's Configuration & Scripts (Pastebin)](https://pastebin.com/UY2012cH)

While TeckFire's original work targeted a 15" quad-core Core i7 model with 16 GB of RAM, dedicated Nvidia graphics, and active continuous background polling scripts, **MacBoost** refactors those concepts specifically for the 13" dual-core Core i5 model. Key architectural adaptations include:
* Eliminating continuous polling loops in favor of a zero-overhead one-shot boot injector.
* Sizing network and virtual memory structures strictly for an 8 GB RAM constraint.
* Implementing granular runtime sysctl validation with logging.
* Using conservative scheduler renice values (-10 / -5) to prevent thread starvation on a 2C/4T CPU.

---

## Intended Operational Environment

MacBoost is designed specifically for **controlled, secure networking environments**. It is tailored for machines functioning primarily as thin clients, remote administration workstations (RDP, SSH, AnyDesk), and light browsing terminals where all internet traffic is routed through a monitored, pre-filtered private VPN (such as Tailscale or an internal WireGuard/IPsec gateway).

It is **not** recommended for general-purpose, casual consumer use on untrusted public Wi-Fi networks without an upstream filtering layer, due to the disabled security features described below.

---

## Explicit Operational Risks and Disabled Features

Executing this script disables numerous native macOS subsystems to conserve CPU cycles and RAM. You must be aware of the following consequences before running it:

### 1. Gatekeeper and Binary Quarantine are Disabled
* The script executes `spctl --master-disable` and sets `LSQuarantine` to `false`.
* **Consequence:** macOS will no longer perform online notarization verification, certificate trust checks, or display the standard "Downloaded from the Internet" quarantine prompt when opening new executables. Malicious binaries will run without OS-level Gatekeeper interception.

### 2. Spotlight and Metadata Indexing are Permanently Disabled
* All indexing is disabled across all mounted volumes via `mdutil -a -i off` and `mdutil -a -d`.
* **Consequence:** System-wide file searches in Finder, Spotlight search shortcuts, and metadata queries will not return file results. Files must be located manually or via command-line utilities (`find`, `fd`).

### 3. Apple Cloud and Synchronization Services are Disabled
* Launchd jobs for `com.apple.bird` (iCloud Drive), `com.apple.cloudd` (CloudKit), and related account synchronization daemons are booted out and disabled.
* **Consequence:** iCloud Drive file synchronization, desktop/documents sync, iCloud Photos, and CloudKit-dependent application sync will cease to function.
* **Important IPC Note:** If an Apple ID remains logged in under System Settings with iCloud Drive toggled on, client applications (such as file open/save dialogs in Finder) may continue attempting Mach message lookups, receiving `XPC_ERROR_CONNECTION_INVALID`. To achieve zero residual IPC calls, manually uncheck iCloud Drive in System Settings > Apple ID.

### 4. Apple Continuity and Device Integration are Disabled
* Daemons for AirDrop, Handoff, Universal Control, and Sidecar (`com.apple.sharingd`, `com.apple.rapportd`, `com.apple.sidecardisplayagent`, etc.) are unloaded.
* **Consequence:** You will not be able to send or receive AirDrop files, share clipboards across devices, use an iPad as an external display, or utilize Universal Control.

### 5. Siri, Apple Intelligence, and Proactive Daemons are Disabled
* Daemons including `intelligenceplatformd`, `triald`, `suggestd`, `siriknowledged`, `duetexpertd`, `coreduetd`, and `contextstored` are unloaded.
* **Consequence:** Siri voice input, proactive search suggestions, and background machine-learning context tracking are eliminated.

### 6. Telemetry and Diagnostics Reporting are Disabled
* Diagnostic daemons including `analyticsd`, `symptomsd`, `spindump`, `tailspind`, and `ReportCrash` are unloaded.
* **Consequence:** Crash reports will not be generated or submitted to Apple.

---

## Technical Architecture and Mechanisms

### 1. Granular Runtime Sysctl Validation
Rather than piping all parameters blindly into `sysctl -f` (which silences failures or halts on unrecognized keys), the boot injector iterates through each parameter:
* Probes the kernel Management Information Base (MIB) via `/usr/sbin/sysctl "$key"`.
* Logs `[SKIP]` if the OID is not supported by the running XNU build.
* Attempts write via `/usr/sbin/sysctl -w "$item"` and captures stdout/stderr.
* Records individual `[OK]` or `[FAIL]` status to `/var/log/macboost_boot.log`.

### 2. Balanced Power Management (Safe Sleep)
* **hibernatemode 3:** Configures Safe Sleep instead of pure RAM sleep (mode 0). RAM remains energized for sub-second wake times when opening the lid. Simultaneously, an image is maintained in `/var/vm/sleepimage`. If the battery discharges completely during extended standby, the system restores from disk rather than losing state.
* **standby and autopoweroff:** Restored with sensible delays (3 hours on battery below 50%, 6 hours on healthy battery, 8 hours for autopoweroff) to allow the SMC to transition into deep low-power states during prolonged inactivity.
* **powernap 0:** Maintained to prevent DarkWake background polling cycles from draining battery or heating the chassis when the lid is closed.

### 3. Preserved UI Transparency
Native macOS window blur and vibrancy remain enabled (`reduceTransparency -bool false`) to preserve visual fidelity. Responsiveness gains are achieved by accelerating window resize intervals and disabling artificial Dock animation delays, rather than degrading interface aesthetics.

### 4. Conservative Mach Scheduler Priorities
The `macboost` utility applies conservative nice values:
* **Tier 1 (-10):** Windows App (RDP), AnyDesk, Tailscale. Prioritizes real-time remote frame rendering and network packet handling.
* **Tier 2 (-5):** Google Chrome, VS Code, WhatsApp, Terminal. Elevates interactive applications above default processes (nice 0).
* **Rationale:** On a 2-core / 4-thread processor, pushing multiple user applications to near-realtime priorities (-18 to -14) saturates Mach runqueues, leading to thread contention against the `WindowServer` compositor and input drivers (`hidd`). Restricting work apps to -10 and -5 ensures responsiveness without starving the display server.

### 5. Zero-Overhead Persistence (One-Shot Boot Injector)
MacBoost does not run persistent background polling daemons. Its LaunchDaemon (`com.legacy.macboost.plist`) executes `/usr/local/bin/macboost_boot.sh` once at system boot (`RunAtLoad=true`, `KeepAlive=false`), applies the validated kernel parameters, silences verbose disk logging, and terminates immediately (`exit 0`). It consumes 0.00% CPU during daily operation.

---

## Installation and Usage

### Applying the Configuration

1. Clone or download this repository.
2. Grant execution permissions:
   ```bash
   chmod +x optimize.sh
   ```
3. Run the installer as root:
   ```bash
   sudo ./optimize.sh
   ```
4. **Reboot the machine** to ensure all disabled services are completely cleared from memory and to allow the LaunchDaemon to perform initial boot-time kernel injection.

### CLI Management: `macboost`

A unified command-line tool is installed at `/usr/local/bin/macboost` (aliased to `optimizemac`):

* **`macboost`**: Applies scheduler priorities to running target applications and displays real-time system metrics.
* **`macboost boost`**: Re-applies scheduler priorities (-10 / -5) on demand.
* **`macboost status`**: Displays system 1-minute load average, CPU thermal throttling status, direct free memory, and top active processes.
* **`macboost log`**: Displays the exact per-line sysctl validation log recorded by the boot injector (`/var/log/macboost_boot.log`).

---

## OpenCore Legacy Patcher Boot-Args (Optional)

In your OpenCore `config.plist`, the following boot arguments may be utilized to further reduce kernel overhead by disabling legacy hardware mitigations in a controlled environment:

```xml
<dict>
    <key>boot-args</key>
    <string>keepsyms=1 debug=0x100 -lilubetaall ipc_control_port_options=0 -nokcmismatchpanic amfi=0x80 vm_compressor_mode=1 ncl=131072 amfi_get_out_of_my_way=1 kpti=0 alcid=1 spectre=0 mds=0 l1tf=0 mitigations=0 cwae=0 apple-panic-no-check=1 no_vhentropy=1 -no_auto_rebuild</string>
    <key>csr-active-config</key>
    <data>fwg=</data>
</dict>
```
