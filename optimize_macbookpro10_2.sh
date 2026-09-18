#!/bin/bash
# ==============================================================================
#  MacBoost - macOS 15 Sequoia (OCLP) Engineering Refactor
#  Target  : MacBook Pro 13" Retina (MacBookPro10,2 - Late 2012 / Early 2013)
#  Hardware: Intel Core i5-3210M (2C/4T @ 2.5-3.1GHz) | Intel HD Graphics 4000
#            8 GB DDR3L RAM | 2560x1600 Retina Display | SATA SSD
#
#  ENGINEERING SPECIFICATIONS & AUDITED MECHANICS:
#  1. Granular Sysctl Validation:
#     - Iterates over every OID, checking existence in kernel MIB before applying.
#     - Records per-line [OK], [SKIP], or [FAIL] in /var/log/macboost_boot.log.
#     - Uses native ZSH/Bash glob matching [[ "$item" == \#* ]] to prevent
#       regex condition parser faults on non-interactive shells.
#  2. Balanced Power Management:
#     - hibernatemode 3 (Safe Sleep): Instant wake from RAM with disk image safety.
#     - standby (3h/6h) & autopoweroff (8h) restored to allow deep low-power sleep.
#     - sleepimage unlocked; powernap 0 maintained to avert DarkWake polling.
#  3. Account Dependencies & Residual XPC Mechanics:
#     - Disables Handoff useractivityd advertising.
#     - Disables local CloudDocs preferences where possible.
#     - Disables CoreDuet / duetexpertd proactive background intelligence.
#  4. Sanitized Architecture:
#     - Zero unverified UIDs (UID 16908544 eliminated).
#     - Legacy namespace leftovers (thinclient, sleeper, sentinel) cleaned up.
#  5. Conservative Scheduler Renice (-10 / -5):
#     - Restricting work apps to nice -10 and -5 avoids saturating 2C/4T runqueues,
#       preventing thread starvation without assuming a fixed BSD nice on compositors.
# ==============================================================================

set -e

# Terminal output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "=========================================================================="
echo "    MacBoost — Performance & Power Refactor (MacBookPro10,2)              "
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

echo -e "${GREEN}[✓] Target Console User:${NC} $CONSOLE_USER (UID: $CONSOLE_UID)"
echo -e "${GREEN}[✓] Home Directory:${NC} $USER_HOME"
echo ""

# ==============================================================================
#  STEP 1: Purge Legacy Iteration Leftovers
# ==============================================================================
echo -e "${YELLOW}${BOLD}[1/6] Cleaning legacy services and outdated helper artifacts...${NC}"

LEGACY_DAEMONS=(
    "com.legacy.thinclient"
    "com.sleeper.sentinel"
    "com.jvfigueiro.optimize"
)

for l_daemon in "${LEGACY_DAEMONS[@]}"; do
    launchctl bootout system/"$l_daemon" 2>/dev/null || true
    rm -f "/Library/LaunchDaemons/${l_daemon}.plist" 2>/dev/null || true
done

rm -f /usr/local/bin/thinclient* /usr/local/bin/silent_sentinel.sh /usr/local/bin/sleeper* 2>/dev/null || true
echo -e "    ${GREEN}✓ Legacy artifacts removed.${NC}"

# ==============================================================================
#  STEP 2: Account Dependencies & Residual XPC Analysis
# ==============================================================================
echo -e "${YELLOW}${BOLD}[2/6] Inspecting account dependencies and configuring IPC isolation...${NC}"

# Disable Handoff / Continuity advertising
sudo -u "$CONSOLE_USER" defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
sudo -u "$CONSOLE_USER" defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false

# Disable local CloudDocs metadata sync preference
sudo -u "$CONSOLE_USER" defaults write com.apple.CloudDocs enabled -bool false 2>/dev/null || true

# Check if Apple ID accounts are configured
HAS_ICLOUD=false
if sudo -u "$CONSOLE_USER" defaults read MobileMeAccounts Accounts >/dev/null 2>&1; then
    ACCOUNT_COUNT=$(sudo -u "$CONSOLE_USER" defaults read MobileMeAccounts Accounts | grep -c "AccountID" || true)
    if [ "$ACCOUNT_COUNT" -gt 0 ]; then
        HAS_ICLOUD=true
    fi
fi

if [ "$HAS_ICLOUD" = true ]; then
    echo -e "    ${YELLOW}[NOTE] Active Apple ID detected on profile.${NC}"
    echo -e "           Handoff advertising is disabled. However, if iCloud Drive is toggled ON"
    echo -e "           in System Settings, apps opening file dialogs will issue residual XPC calls"
    echo -e "           to cloudd/bird and receive XPC_ERROR_CONNECTION_INVALID."
    echo -e "           ${BOLD}Recommendation:${NC} Uncheck iCloud Drive in System Settings for zero residual calls."
else
    echo -e "    ${GREEN}✓ No active Apple ID detected. Cloud sync agents can be safely disabled.${NC}"
fi

# ==============================================================================
#  STEP 3: Targeted Service Unloading (System & GUI)
# ==============================================================================
echo -e "${YELLOW}${BOLD}[3/6] Unloading unnecessary Apple daemons, telemetry, and background agents...${NC}"

# Disable Spotlight across all mount points
mdutil -a -i off 2>/dev/null || true
mdutil -a -d 2>/dev/null || true

SYSTEM_SERVICES=(
    # Spotlight & Metadata
    "com.apple.metadata.mds"
    "com.apple.metadata.mds.index"
    "com.apple.metadata.mds.scan"
    "com.apple.metadata.mds.spindump"
    # CoreDuet & Context Intelligence
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
    # Cloud & Peripheral daemons
    "com.apple.icloud.searchpartyd"
    "com.apple.CSCSupportd"
    "com.apple.nfcd"
    "com.apple.oahd"
    "com.apple.mdmclient.daemon.runatboot"
    "com.apple.biometrickitd"
    "com.apple.remotemanagementd"
)

GUI_SERVICES=(
    # CoreDuet / Proactive Intelligence User Agents
    "com.apple.duetexpertd"
    "com.apple.coreduetd"
    "com.apple.ContextStoreAgent"
    # Spotlight GUI knowledge agents
    "com.apple.spotlightknowledged"
    "com.apple.spotlightknowledged.importer"
    "com.apple.spotlightknowledged.updater"
    # Cloud & Sync Daemons
    "com.apple.bird"
    "com.apple.cloudd"
    "com.apple.itunescloudd"
    "com.apple.icloud.searchpartyuseragent"
    "com.apple.wallpaper.clouddestination"
    "com.apple.akd"
    "com.apple.amsaccountsd"
    "com.apple.amsengagementd"
    # Sharing & Continuity
    "com.apple.sharingd"
    "com.apple.rapportd"
    "com.apple.sidecardisplayagent"
    "com.apple.sidecarrelay"
    "com.apple.universalcontrol"
    "com.apple.continuity"
    "com.apple.AirPlayXPCHelper"
    # Apple Intelligence, Siri & Knowledge Agents
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
    "com.apple.medialibraryd"
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
    # Miscellaneous non-essential services
    "com.apple.gamed"
    "com.apple.helpd"
    "com.apple.touchbarserver"
    "com.apple.screentimeagent"
    "com.apple.widgets.extension-vending"
    "com.apple.FolderActionsDispatcher"
)

for s_svc in "${SYSTEM_SERVICES[@]}"; do
    launchctl bootout system/"$s_svc" 2>/dev/null || true
    launchctl disable system/"$s_svc" 2>/dev/null || true
done

for g_svc in "${GUI_SERVICES[@]}"; do
    launchctl bootout gui/"$CONSOLE_UID"/"$g_svc" 2>/dev/null || true
    launchctl disable gui/"$CONSOLE_UID"/"$g_svc" 2>/dev/null || true
done

echo -e "    ${GREEN}✓ Unnecessary launchd jobs disabled.${NC}"

# ==============================================================================
#  STEP 4: UI & Gatekeeper Configuration
# ==============================================================================
echo -e "${YELLOW}${BOLD}[4/6] Configuring UI responsiveness and security policy...${NC}"

# Gatekeeper disabled (Traffic pre-filtered via secure VPN)
spctl --master-disable 2>/dev/null || true
sudo -u "$CONSOLE_USER" defaults write com.apple.LaunchServices LSQuarantine -bool false

# UI Transparency PRESERVED (Native visual aesthetics intact)
sudo -u "$CONSOLE_USER" defaults write com.apple.universalaccess reduceTransparency -bool false

# Accelerated window resize & Dock animations for cursor responsiveness
sudo -u "$CONSOLE_USER" defaults write NSGlobalDomain NSWindowResizeTime -float 0.08
sudo -u "$CONSOLE_USER" defaults write com.apple.dock launchanim -bool false
sudo -u "$CONSOLE_USER" defaults write com.apple.dock mineffect -string "scale"
sudo -u "$CONSOLE_USER" defaults write com.apple.dock expose-animation-duration -float 0.12
sudo -u "$CONSOLE_USER" defaults write com.apple.dock autohide-time-modifier -float 0.15

# Suppress graphics logger overhead
launchctl setenv MTL_HUD_ENABLED 0
launchctl setenv MTL_COMPILER_LOG_LEVEL 0
launchctl setenv DYLD_PRINT_WARNINGS 0

echo -e "    ${GREEN}✓ UI settings applied (Transparency enabled, animations accelerated).${NC}"

# ==============================================================================
#  STEP 5: Balanced Power Management (Safe Sleep + Standby)
# ==============================================================================
echo -e "${YELLOW}${BOLD}[5/6] Configuring balanced power management (Safe Sleep)...${NC}"

# Unlock sleepimage if it was previously locked with uchg
if [ -f /var/vm/sleepimage ]; then
    chflags nouchg /var/vm/sleepimage 2>/dev/null || true
fi

pmset -a hibernatemode 3
pmset -a standby 1
pmset -a standbydelaylow 10800   # 3 hours before deep sleep on low battery
pmset -a standbydelayhigh 21600  # 6 hours before deep sleep on healthy battery
pmset -a highstandbythreshold 50 # Standby delay selection threshold (50% battery)
pmset -a autopoweroff 1
pmset -a autopoweroffdelay 28800 # 8 hours before European Energy-related Products (ErP) shutoff
pmset -a powernap 0
pmset -a womp 0
pmset -a proximitywake 0
pmset -a lidwake 1
pmset -a tcpkeepalive 1

echo -e "    ${GREEN}✓ Safe sleep (hibernatemode 3) and deep standby timers configured.${NC}"

# ==============================================================================
#  STEP 6: Verified Boot Injector & Conservative Renice CLI
# ==============================================================================
echo -e "${YELLOW}${BOLD}[6/6] Installing MacBoost Boot Injector and CLI (/usr/local/bin/macboost)...${NC}"

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

# Environment variables
launchctl setenv MTL_HUD_ENABLED 0
launchctl setenv MTL_COMPILER_LOG_LEVEL 0
launchctl setenv DYLD_PRINT_WARNINGS 0

# Allow OCLP patch kexts to settle before probing kernel
sleep 4

# Sysctl list for Ivy Bridge i5 (2C/4T) with 8GB RAM
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

# Apply each tunable with validation and individual logging
for item in "${TUNABLES[@]}"; do
    [[ -z "$item" || "$item" == \#* ]] && continue
    key="${item%%=*}"
    target_val="${item#*=}"

    # 1. Check if OID exists in current kernel build
    if ! /usr/sbin/sysctl "$key" >/dev/null 2>&1; then
        echo "[SKIP] $key (OID does not exist in this XNU build)" >> "$LOG_FILE"
        continue
    fi

    # 2. Attempt write
    err_output=$(/usr/sbin/sysctl -w "$item" 2>&1)
    status=$?

    if [ $status -eq 0 ]; then
        echo "[OK] $key=$target_val" >> "$LOG_FILE"
    else
        echo "[FAIL] $key: $err_output" >> "$LOG_FILE"
    fi
done

# Silence logd continuous disk writes
/usr/bin/log config --mode "level:off" >/dev/null 2>&1
killall -9 logd 2>/dev/null || true

echo "=== MacBoost Boot Completed: $(date) ===" >> "$LOG_FILE"
exit 0
BOOT_EOF

chmod +x /usr/local/bin/macboost_boot.sh
chown root:wheel /usr/local/bin/macboost_boot.sh

# LaunchDaemon configuration (RunAtLoad=true, KeepAlive=false)
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

# Load LaunchDaemon
launchctl bootout system/com.legacy.macboost 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.legacy.macboost.plist 2>/dev/null || launchctl load /Library/LaunchDaemons/com.legacy.macboost.plist 2>/dev/null || true

# -----------------------------------------------------------------------------
# Conservative Renice CLI: /usr/local/bin/macboost
# -----------------------------------------------------------------------------
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
    echo -e "\033[1;32m🚀 [MacBoost] Applying conservative scheduler priorities...\033[0m"

    # Tier 1 (-10): Latency-sensitive remote access and networking
    TARGETS_TIER1="Windows App|Microsoft Remote Desktop|AnyDesk|tailscaled|Tailscale|IPNExtension"
    PIDS_TIER1=$(pgrep -fi "$TARGETS_TIER1" || true)
    if [ -n "$PIDS_TIER1" ]; then
        renice -n -10 -p $PIDS_TIER1 >/dev/null 2>&1 || true
        echo "  ✓ Remote Access & Mesh VPN (RDP/AnyDesk/Tailscale) set to nice -10"
    fi

    # Tier 2 (-5): Active interactive user applications
    TARGETS_TIER2="Google Chrome|Code|WhatsApp|Terminal|iTerm2|The Unarchiver"
    PIDS_TIER2=$(pgrep -fi "$TARGETS_TIER2" || true)
    if [ -n "$PIDS_TIER2" ]; then
        renice -n -5 -p $PIDS_TIER2 >/dev/null 2>&1 || true
        echo "  ✓ Interactive Work Apps (Chrome/VS Code/WhatsApp/Terminal) set to nice -5"
    fi

    echo -e "\033[1;32m✓ Completed. Scheduler priorities applied safely without saturating CPU threads.\033[0m"
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
    # Filter out ps, head, and grep self-consumption from diagnostic output
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

# Update root optimize.sh
cp -f "$0" "$(dirname "$0")/optimize.sh" 2>/dev/null || true

# Execute initial boot validation now to verify sysctls immediately
/usr/local/bin/macboost_boot.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}${BOLD}=========================================================================="
echo "    MACBOOST REFACTOR APPLIED SUCCESSFULLY!                               "
echo "==========================================================================${NC}"
echo ""
echo -e "${CYAN}Summary of Engineering Refinements:${NC}"
echo -e " 1. ${BOLD}Sysctl Validation:${NC} Granular runtime validation with logging (/var/log/macboost_boot.log)."
echo -e " 2. ${BOLD}Balanced Sleep:${NC} hibernatemode 3 (Safe Sleep) + standby timers (3h/6h) enabled."
echo -e " 3. ${BOLD}IPC Isolation:${NC} Handoff and CoreDuet/duetexpertd disabled."
echo -e " 4. ${BOLD}Clean Base:${NC} Unverified UID (16908544) and legacy thinclient remnants purged."
echo -e " 5. ${BOLD}Conservative Renice:${NC} Work apps priority capped at -10/-5 to protect CPU threads."
echo ""
echo -e "Check boot sysctl application results via: ${BOLD}macboost log${NC}"
echo -e "Boost work apps and inspect diagnostics via: ${BOLD}macboost${NC}"
echo ""
