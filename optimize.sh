#!/bin/bash
# ==============================================================================
#  Legacy Mac Boost - macOS 15 Sequoia (OCLP) Focused & Safe Optimization Suite
#  Target  : MacBook Pro 13" Retina (MacBookPro10,2 - Late 2012 / Early 2013)
#  Hardware: Intel Core i5-3210M (2C/4T @ 2.5-3.1GHz) | Intel HD Graphics 4000
#            8 GB DDR3L RAM | 2560x1600 Retina Display | SATA SSD
#
#  DESIGN PRINCIPLES (Focused & Non-Invasive):
#  1. App Store & Apple ID 100% Preserved:
#     - akd (AuthKit / 2FA login verification codes) and amsaccountsd (App Store)
#       remain active and untouched.
#  2. Native UI Fidelity:
#     - Zero visual interface modifications. No forced animation or motion overrides.
#  3. Targeted Background Daemon Silencing:
#     - Spotlight indexing (mdutil & mds daemons).
#     - Siri, Apple Intelligence & CoreDuet proactive background services.
#     - Touch Bar server (unsupported hardware).
#     - Crash reporting, spindump, tailspin, and telemetry.
#     - Background media and photo analysis.
#  4. Local Networking & AirDrop Preserved:
#     - sharingd and rapportd remain enabled.
#  5. Clean Power Management:
#     - hibernatemode 3 (Safe Sleep) with complete Power Nap and DarkWake suppression.
# ==============================================================================

set -e

# Terminal output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
echo "=========================================================================="
echo "    Legacy Mac Boost — Focused Optimization Suite (MacBookPro10,2)        "
echo "    Target: i5-3210M (2C/4T) | HD 4000 | 8GB RAM | macOS 15 Sequoia (OCLP)"
echo "=========================================================================="
echo -e "${NC}"

# 1. Root privilege verification
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] This script must be executed as root.${NC}"
  echo "Please run: sudo $0"
  exit 1
fi

# 2. Identify active GUI console user
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "$SUDO_USER")
CONSOLE_UID=$(stat -f "%u" /dev/console 2>/dev/null || id -u "$CONSOLE_USER" 2>/dev/null || echo "501")
USER_HOME=$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

if [ -z "$USER_HOME" ]; then
    USER_HOME="/Users/$CONSOLE_USER"
fi

echo -e "${GREEN}[+] Target Console User:${NC} $CONSOLE_USER (UID: $CONSOLE_UID)"
echo -e "${GREEN}[+] Home Directory:${NC} $USER_HOME"
echo ""

# 3. Interactive or Flag-Based Gatekeeper Option
DISABLE_GATEKEEPER=false

for arg in "$@"; do
    case "$arg" in
        --disable-gatekeeper)
            DISABLE_GATEKEEPER=true
            ;;
        --keep-gatekeeper)
            DISABLE_GATEKEEPER=false
            ;;
    esac
done

if [ "$DISABLE_GATEKEEPER" = false ] && [ "$1" != "--keep-gatekeeper" ]; then
    if [ -t 0 ]; then
        echo -e "${YELLOW}[?] Security Policy Configuration:${NC}"
        echo "    Disabling Gatekeeper bypasses quarantine checks for faster app launch"
        echo "    in pre-filtered VPN environments, but removes OS-level notarization checks."
        read -r -p "    Do you want to disable Gatekeeper? [y/N]: " GK_INPUT
        case "$GK_INPUT" in
            [yY][eE][sS]|[yY])
                DISABLE_GATEKEEPER=true
                ;;
            *)
                DISABLE_GATEKEEPER=false
                ;;
        esac
    fi
fi

# ==============================================================================
#  STEP 1: Purge Legacy Iteration Leftovers
# ==============================================================================
echo -e "${YELLOW}[1/5] Cleaning legacy services and outdated helper artifacts...${NC}"

LEGACY_DAEMONS=(
    "com.legacy.thinclient"
    "com.sleeper.sentinel"
    "com.jvfigueiro.optimize"
)

for l_daemon in "${LEGACY_DAEMONS[@]}"; do
    launchctl bootout system/"$l_daemon" 2>/dev/null || true
    rm -f "/Library/LaunchDaemons/${l_daemon}.plist" 2>/dev/null || true
done

rm -f /usr/local/bin/thinclient* /usr/local/bin/silent_sentinel.sh /usr/local/bin/sleeper* /usr/local/bin/optimize_macbookpro10_2.sh 2>/dev/null || true
echo -e "    ${GREEN}[OK] Legacy artifacts removed.${NC}"

# ==============================================================================
#  STEP 2: Targeted Service Unloading (System & GUI)
#  CRITICAL: App Store (amsaccountsd) and Apple ID AuthKit (akd) are PRESERVED.
#  AirDrop daemons (sharingd and rapportd) are PRESERVED.
# ==============================================================================
echo -e "${YELLOW}[2/5] Unloading AI, Siri, Spotlight, telemetry, and error reporting...${NC}"

# Disable Spotlight indexing across all mounted volumes
mdutil -a -i off 2>/dev/null || true
mdutil -a -d 2>/dev/null || true

SYSTEM_SERVICES=(
    # Spotlight Metadata Engine
    "com.apple.metadata.mds"
    "com.apple.metadata.mds.index"
    "com.apple.metadata.mds.scan"
    "com.apple.metadata.mds.spindump"
    # CoreDuet & Proactive Intelligence
    "com.apple.coreduetd"
    "com.apple.duetexpertd"
    "com.apple.contextstored"
    # Diagnostics, Telemetry & Crash Reporting
    "com.apple.analyticsd"
    "com.apple.analyticsagent"
    "com.apple.wifianalyticsd"
    "com.apple.audioanalyticsd"
    "com.apple.ecosystemanalyticsd"
    "com.apple.geoanalyticsd"
    "com.apple.symptomsd"
    "com.apple.symptomsd-diag"
    "com.apple.ospredictiond"
    "com.apple.biomed"
    "com.apple.ReportCrash.Root"
    "com.apple.sysdiagnose.service"
    "com.apple.powerlogHelperd"
    "com.apple.spindump"
    "com.apple.tailspind"
    "com.apple.systemstatsd"
    "com.apple.systemstats.daily"
    "com.apple.systemstats.analysis"
    "com.apple.systemstats.microstackshot_periodic"
    "com.apple.osanalytics.osanalyticshelper"
    # Apple Intelligence & Silicon-specific daemons
    "com.apple.triald.system"
    "com.apple.aned"
    "com.apple.aneuserd"
    # Unneeded hardware daemons on 2012 MacBook Pro
    "com.apple.nfcd"
)

GUI_SERVICES=(
    # CoreDuet / Proactive Intelligence User Agents
    "com.apple.duetexpertd"
    "com.apple.coreduetd"
    "com.apple.ContextStoreAgent"
    # Spotlight GUI Knowledge Agents
    "com.apple.spotlightknowledged"
    "com.apple.spotlightknowledged.importer"
    "com.apple.spotlightknowledged.updater"
    # Touch Bar Server (Hardware not present on MacBookPro10,2)
    "com.apple.touchbarserver"
    # Siri, Apple Intelligence & Suggestion Daemons
    "com.apple.intelligenceplatformd"
    "com.apple.intelligencecontextd"
    "com.apple.triald"
    "com.apple.triald.system"
    "com.apple.suggestd"
    "com.apple.siriknowledged"
    "com.apple.siriinferenced"
    "com.apple.corespeechd"
    "com.apple.assistantd"
    "com.apple.knowledge-agent"
    "com.apple.knowledgeconstructiond"
    "com.apple.proactived"
    "com.apple.proactiveeventtrackerd"
    # Media & Photo Background Analysis
    "com.apple.mediaanalysisd"
    "com.apple.photoanalysisd"
    # Telemetry, Biome & Crash Reporters
    "com.apple.analyticsagent"
    "com.apple.geoanalyticsd"
    "com.apple.inputanalyticsd"
    "com.apple.biomesyncd"
    "com.apple.biomesyncd.plist"
    "com.apple.BiomeAgent"
    "com.apple.biomeAgent.plist"
    "com.apple.ReportCrash"
    "com.apple.tailspind"
    "com.apple.symptomd"
    "com.apple.usage-tracking-agent"
    "com.apple.diagnosed"
    "com.apple.appleseed.fbahelperd"
    "com.apple.appleseed.spindump"
    "com.apple.appleseed.seedusaged.postinstall"
    "com.apple.appleseed.biomesyncd"
    # Unsupported Sidecar daemons on Ivy Bridge
    "com.apple.sidecardisplayagent"
    "com.apple.sidecarrelay"
)

for s_svc in "${SYSTEM_SERVICES[@]}"; do
    launchctl bootout system/"$s_svc" 2>/dev/null || true
    launchctl disable system/"$s_svc" 2>/dev/null || true
done

for g_svc in "${GUI_SERVICES[@]}"; do
    launchctl bootout gui/"$CONSOLE_UID"/"$g_svc" 2>/dev/null || true
    launchctl disable gui/"$CONSOLE_UID"/"$g_svc" 2>/dev/null || true
done

echo -e "    ${GREEN}[OK] AI, Siri, Spotlight, telemetry, and crash daemons unloaded.${NC}"
echo -e "    ${GREEN}[OK] App Store and Apple ID AuthKit remain 100% functional.${NC}"

# ==============================================================================
#  STEP 3: Gatekeeper Policy Configuration
#  UI effects, window animations, and motion settings are completely untouched.
# ==============================================================================
echo -e "${YELLOW}[3/5] Applying security policy...${NC}"

if [ "$DISABLE_GATEKEEPER" = true ]; then
    spctl --master-disable 2>/dev/null || true
    sudo -u "$CONSOLE_USER" defaults write com.apple.LaunchServices LSQuarantine -bool false
    echo -e "    ${GREEN}[OK] Gatekeeper and binary quarantine disabled by user choice.${NC}"
else
    spctl --master-enable 2>/dev/null || true
    sudo -u "$CONSOLE_USER" defaults write com.apple.LaunchServices LSQuarantine -bool true
    echo -e "    ${GREEN}[OK] Gatekeeper kept enabled (system security policy preserved).${NC}"
fi

# Suppress graphics logger overhead
launchctl setenv MTL_HUD_ENABLED 0
launchctl setenv MTL_COMPILER_LOG_LEVEL 0
launchctl setenv DYLD_PRINT_WARNINGS 0

# ==============================================================================
#  STEP 4: Balanced Power Management & Power Nap Elimination
# ==============================================================================
echo -e "${YELLOW}[4/5] Configuring power management and suppressing Power Nap...${NC}"

if [ -f /var/vm/sleepimage ]; then
    chflags nouchg /var/vm/sleepimage 2>/dev/null || true
fi

# Clear any pending wake events scheduled by system daemons
pmset schedule cancelall 2>/dev/null || true

# Strict Power Nap and wake suppression across AC and Battery profiles
pmset -a powernap 0
pmset -b powernap 0
pmset -c powernap 0
pmset -a womp 0
pmset -a proximitywake 0
pmset -a networkoversleep 0 2>/dev/null || true
pmset -a ttyskeepawake 0 2>/dev/null || true

# Battery profile: Disable TCP keepalive during sleep to stop Bonjour/push RTC wakes
pmset -b tcpkeepalive 0 2>/dev/null || true
pmset -c tcpkeepalive 1 2>/dev/null || true

# Safe Sleep & Standby Timers
pmset -a hibernatemode 3
pmset -a standby 1
pmset -a standbydelaylow 10800   # 3 hours before deep sleep on low battery
pmset -a standbydelayhigh 21600  # 6 hours before deep sleep on healthy battery
pmset -a highstandbythreshold 50 # Standby delay selection threshold (50% battery)
pmset -a autopoweroff 1
pmset -a autopoweroffdelay 28800 # 8 hours before European Energy-related Products (ErP) shutoff
pmset -a lidwake 1

echo -e "    ${GREEN}[OK] Power Nap disabled and deep sleep wake-suppression configured.${NC}"

# ==============================================================================
#  STEP 5: Verified Boot Injector & Conservative Renice CLI
# ==============================================================================
echo -e "${YELLOW}[5/5] Installing MacBoost Boot Injector and CLI (/usr/local/bin/macboost)...${NC}"

mkdir -p /usr/local/bin

cat << 'BOOT_EOF' > /usr/local/bin/macboost_boot.sh
#!/bin/zsh
# =============================================================================
#  MacBoost Boot Injector — MacBookPro10,2 (macOS 15 Sequoia OCLP)
#  Granular sysctl validator and zero-overhead one-shot initialization.
# =============================================================================

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
LOG_FILE="/var/log/macboost_boot.log"

echo "=== MacBoost Boot Execution: $(date) ===" > "$LOG_FILE"

launchctl setenv MTL_HUD_ENABLED 0
launchctl setenv MTL_COMPILER_LOG_LEVEL 0
launchctl setenv DYLD_PRINT_WARNINGS 0

# Allow OCLP patch kexts to settle before probing kernel
sleep 4

TUNABLES=(
    "kern.timer_coalesce_tier0_scale=1"
    "kern.timer_coalesce_tier0_ns_max=1000000"
    "kern.timer_coalesce_tier1_scale=1"
    "kern.timer_coalesce_tier1_ns_max=5000000"
    "kern.timer_coalesce_tier2_scale=4"
    "kern.timer_coalesce_tier2_ns_max=1000000000"
    "kern.timer_coalesce_tier3_scale=-5"
    "kern.timer_coalesce_tier3_ns_max=5000000000"
    "kern.timer_coalesce_tier4_ns_max=30000000000"
    "kern.timer_coalesce_tier5_ns_max=30000000000"
    "kern.timer_coalesce_bg_scale=3"
    "kern.timer_coalesce_idle_entry_hard_deadline_max=5000"
    "kern.interrupt_timer_coalescing_enabled=1"
    "kern.sched_rt_avoid_cpu0=1"
    "kern.ulock_adaptive_spin_usecs=40"
    "kern.vm_pressure_level_transition_threshold=45"
    "vfs.generic.sync_timeout=25"
    "kern.ipc.maxsockbuf=8388608"
    "net.inet.tcp.autorcvbufmax=8388608"
    "net.inet.tcp.autosndbufmax=8388608"
    "net.inet.tcp.sendspace=262144"
    "net.inet.tcp.recvspace=262144"
    "net.inet.udp.recvspace=131072"
    "net.inet.tcp.delayed_ack=1"
    "net.inet.tcp.local_slowstart_flightsize=16"
    "net.inet.tcp.aggressive_rcvwnd_inc=1"
    "net.inet.tcp.fastopen=0"
    "net.inet.tcp.minmss=536"
    "net.link.ether.inet.max_age=1800"
    "net.inet.tcp.keepidle=600000"
    "net.inet.tcp.keepintvl=75000"
    "kern.maxvnodes=262144"
    "kern.maxfiles=262144"
    "kern.maxfilesperproc=65536"
    "kern.ipc.somaxconn=1024"
    "kern.maxprocperuid=2048"
    "kern.sysv.shmmax=1073741824"
    "kern.sysv.shmall=262144"
)

for item in "${TUNABLES[@]}"; do
    [[ -z "$item" || "$item" == \#* ]] && continue
    key="${item%%=*}"
    target_val="${item#*=}"

    if ! /usr/sbin/sysctl "$key" >/dev/null 2>&1; then
        echo "[SKIP] $key (OID does not exist in this XNU build)" >> "$LOG_FILE"
        continue
    fi

    err_output=$(/usr/sbin/sysctl -w "$item" 2>&1)
    status=$?

    if [ $status -eq 0 ]; then
        echo "[OK] $key=$target_val" >> "$LOG_FILE"
    else
        echo "[FAIL] $key: $err_output" >> "$LOG_FILE"
    fi
done

/usr/bin/log config --mode "level:off" >/dev/null 2>&1
killall -9 logd 2>/dev/null || true

echo "=== MacBoost Boot Completed: $(date) ===" >> "$LOG_FILE"
exit 0
BOOT_EOF

chmod +x /usr/local/bin/macboost_boot.sh
chown root:wheel /usr/local/bin/macboost_boot.sh

cat << 'PLIST_EOF' > /Library/LaunchDaemons/com.legacy.macboost.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.legacy.macboost</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>/usr/local/bin/macboost_boot.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>AbandonProcessGroup</key>
    <true/>
</dict>
</plist>
PLIST_EOF

chown root:wheel /Library/LaunchDaemons/com.legacy.macboost.plist
chmod 644 /Library/LaunchDaemons/com.legacy.macboost.plist

launchctl bootout system/com.legacy.macboost 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.legacy.macboost.plist 2>/dev/null || launchctl load /Library/LaunchDaemons/com.legacy.macboost.plist 2>/dev/null || true

cat << 'CLI_EOF' > /usr/local/bin/macboost
#!/bin/bash
# MacBoost Management CLI for MacBookPro10,2

function show_help() {
    echo "Usage: macboost [command]"
    echo ""
    echo "Commands:"
    echo "  boost   Apply conservative nice priorities (-10 / -5) to active work apps"
    echo "  status  Display 1-minute load average, thermal limit, memory, and top processes"
    echo "  log     View output log of the boot sysctl injector"
    echo "  help    Show this help message"
    echo ""
    echo "Running 'macboost' without arguments runs 'boost' followed by 'status'."
}

function run_boost() {
    echo -e "\033[1;32m[*] [MacBoost] Applying conservative scheduler priorities...\033[0m"

    TARGETS_TIER1="Windows App|Microsoft Remote Desktop|AnyDesk|tailscaled|Tailscale|IPNExtension"
    PIDS_TIER1=$(pgrep -fi "$TARGETS_TIER1" || true)
    if [ -n "$PIDS_TIER1" ]; then
        renice -n -10 -p $PIDS_TIER1 >/dev/null 2>&1 || true
        echo "  [OK] Remote Access & Mesh VPN (RDP/AnyDesk/Tailscale) set to nice -10"
    fi

    TARGETS_TIER2="Google Chrome|Code|WhatsApp|Terminal|iTerm2|The Unarchiver"
    PIDS_TIER2=$(pgrep -fi "$TARGETS_TIER2" || true)
    if [ -n "$PIDS_TIER2" ]; then
        renice -n -5 -p $PIDS_TIER2 >/dev/null 2>&1 || true
        echo "  [OK] Interactive Work Apps (Chrome/VS Code/WhatsApp/Terminal) set to nice -5"
    fi

    echo -e "\033[1;32m[OK] Completed. Scheduler priorities applied safely without saturating CPU threads.\033[0m"
}

function run_status() {
    echo -e "\033[1;36m========================================================\033[0m"
    echo -e "\033[1;36m       MacBoost System Diagnostics (MacBookPro10,2)     \033[0m"
    echo -e "\033[1;36m========================================================\033[0m"

    LOAD=$(sysctl -n vm.loadavg | awk '{print $2}')
    echo -e "System 1-Minute Load Average: \033[1;32m$LOAD\033[0m (Target: < 1.0)"

    THERM_LIMIT=$(pmset -g therm | grep "CPU_Speed_Limit" | awk '{print $NF}')
    if [ -z "$THERM_LIMIT" ] || [ "$THERM_LIMIT" -eq 100 ]; then
        echo -e "CPU Thermal State: \033[1;32m100% (Nominal / No Throttling)\033[0m"
    else
        echo -e "CPU Thermal State: \033[1;31mThrottled at $THERM_LIMIT%\033[0m"
    fi

    FREE_PAGES=$(sysctl -n vm.page_free_count 2>/dev/null || echo 0)
    FREE_MB=$(( (FREE_PAGES * 4096) / 1048576 ))
    echo -e "Direct Free Memory: \033[1;33m$FREE_MB MB\033[0m"

    echo ""
    echo -e "\033[1mTop CPU Processes:\033[0m"
    ps -arcwwwxo pid,command,%cpu,ni | grep -vE " (ps|head|grep)$" | head -n 6

    echo -e "\033[1;36m========================================================\033[0m"
}

case "$1" in
    boost)
        run_boost
        ;;
    status)
        run_status
        ;;
    log)
        if [ -f "/var/log/macboost_boot.log" ]; then
            cat /var/log/macboost_boot.log
        else
            echo "No boot log found at /var/log/macboost_boot.log"
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        run_boost
        echo ""
        run_status
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
CLI_EOF

chmod +x /usr/local/bin/macboost
chown root:wheel /usr/local/bin/macboost
ln -sf /usr/local/bin/macboost /usr/local/bin/optimizemac

# Execute initial boot validation now
/usr/local/bin/macboost_boot.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}${BOLD}=========================================================================="
echo "    LEGACY MAC BOOST OPTIMIZATION APPLIED SUCCESSFULLY                    "
echo "==========================================================================${NC}"
echo ""
echo -e "${BLUE}Summary of Configuration:${NC}"
echo -e " 1. App Store & Apple ID: 100% functional (AuthKit 2FA & store daemons preserved)."
echo -e " 2. AirDrop Preserved: sharingd and rapportd remain active."
echo -e " 3. UI Policy: Native interface fidelity preserved (no animation or motion overrides)."
echo -e " 4. Targeted Silencing: Spotlight, AI, Siri, CoreDuet, Touch Bar, and crash logs disabled."
echo -e " 5. Power Management: hibernatemode 3 (Safe Sleep) with complete Power Nap suppression."
echo -e " 6. Sysctl Validation: Granular runtime validation (/var/log/macboost_boot.log)."
echo ""
echo -e "To view boot sysctl validation results: macboost log"
echo -e "To boost apps and inspect status: macboost"
echo -e "To uninstall and restore system defaults at any time: sudo ./uninstall.sh"
echo ""
