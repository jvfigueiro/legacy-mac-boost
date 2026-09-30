#!/bin/bash
# ==============================================================================
#  Legacy Mac Boost - Uninstallation and System Restoration Script
#  Target  : MacBook Pro 13" Retina (MacBookPro10,2 - Late 2012 / Early 2013)
#  Platform: macOS 15 Sequoia via OpenCore Legacy Patcher (OCLP)
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
echo "    Legacy Mac Boost — Uninstaller and System State Restoration           "
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
echo ""

# ==============================================================================
#  STEP 1: Remove LaunchDaemon, Helper Binaries, and Clear Environment
# ==============================================================================
echo -e "${YELLOW}[1/5] Removing MacBoost persistence daemons, binaries, and environment flags...${NC}"

launchctl bootout system/com.legacy.macboost 2>/dev/null || true
launchctl disable system/com.legacy.macboost 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.legacy.macboost.plist
rm -f /usr/local/bin/macboost_boot.sh
rm -f /usr/local/bin/macboost
rm -f /usr/local/bin/optimizemac
rm -f /usr/local/bin/optimize_macbookpro10_2.sh
rm -f /var/log/macboost_boot.log

# Clean up older iteration plists if still present
rm -f /Library/LaunchDaemons/com.legacy.thinclient.plist 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.sleeper.sentinel.plist 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.jvfigueiro.optimize.plist 2>/dev/null || true

# Unset launchd environment variables
launchctl unsetenv MTL_HUD_ENABLED 2>/dev/null || true
launchctl unsetenv MTL_COMPILER_LOG_LEVEL 2>/dev/null || true
launchctl unsetenv DYLD_PRINT_WARNINGS 2>/dev/null || true

# Restore default system logging level
/usr/bin/log config --mode "level:default" 2>/dev/null || true

echo -e "    ${GREEN}[OK] Daemons, CLI utilities, and environment flags reset.${NC}"

# ==============================================================================
#  STEP 2: Re-enable Gatekeeper and System Security
# ==============================================================================
echo -e "${YELLOW}[2/5] Restoring Gatekeeper and application quarantine...${NC}"

spctl --master-enable 2>/dev/null || true
sudo -u "$CONSOLE_USER" defaults write com.apple.LaunchServices LSQuarantine -bool true

echo -e "    ${GREEN}[OK] Gatekeeper and binary quarantine re-enabled.${NC}"

# ==============================================================================
#  STEP 3: Re-enable Spotlight Indexing
# ==============================================================================
echo -e "${YELLOW}[3/5] Re-enabling Spotlight indexing across all volumes...${NC}"

mdutil -a -i on 2>/dev/null || true

echo -e "    ${GREEN}[OK] Spotlight indexing enabled.${NC}"

# ==============================================================================
#  STEP 4: Re-enable Targeted Core System and User Daemons
#  Fully symmetric with all services unloaded in optimize.sh.
# ==============================================================================
echo -e "${YELLOW}[4/5] Restoring launchd services (System & GUI)...${NC}"

RESTORE_SYSTEM_SERVICES=(
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
    # Apple Intelligence & Silicon Daemons
    "com.apple.triald.system"
    "com.apple.aned"
    "com.apple.aneuserd"
    # Peripherals
    "com.apple.nfcd"
)

RESTORE_GUI_SERVICES=(
    # CoreDuet / Proactive Intelligence User Agents
    "com.apple.duetexpertd"
    "com.apple.coreduetd"
    "com.apple.ContextStoreAgent"
    # Spotlight GUI Knowledge Agents
    "com.apple.spotlightknowledged"
    "com.apple.spotlightknowledged.importer"
    "com.apple.spotlightknowledged.updater"
    # Touch Bar Server
    "com.apple.touchbarserver"
    # Secondary Display
    "com.apple.sidecardisplayagent"
    "com.apple.sidecarrelay"
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
)

for s_svc in "${RESTORE_SYSTEM_SERVICES[@]}"; do
    launchctl enable system/"$s_svc" 2>/dev/null || true
done

for g_svc in "${RESTORE_GUI_SERVICES[@]}"; do
    launchctl enable gui/"$CONSOLE_UID"/"$g_svc" 2>/dev/null || true
done

echo -e "    ${GREEN}[OK] All targeted services re-enabled in launchd configuration.${NC}"

# ==============================================================================
#  STEP 5: Restore Default Power Management Settings
# ==============================================================================
echo -e "${YELLOW}[5/5] Restoring default macOS power management configuration...${NC}"

# Restore standard Apple power defaults
pmset -a hibernatemode 3
pmset -a standby 1
pmset -a autopoweroff 1
pmset -a powernap 1
pmset -b powernap 1
pmset -c powernap 1
pmset -a tcpkeepalive 1
pmset -b tcpkeepalive 1
pmset -c tcpkeepalive 1
pmset -a womp 1
pmset -a proximitywake 1
pmset -a networkoversleep 1 2>/dev/null || true
pmset -a ttyskeepawake 1 2>/dev/null || true

echo -e "    ${GREEN}[OK] Power management (Power Nap, TCP keepalive, standby) restored.${NC}"

echo ""
echo -e "${GREEN}${BOLD}=========================================================================="
echo "    LEGACY MAC BOOST UNINSTALLATION COMPLETED                             "
echo "==========================================================================${NC}"
echo ""
echo "Please reboot your MacBook Pro to restore default kernel tunables and reload services:"
echo "sudo reboot"
echo ""
