#!/bin/bash
# ==============================================================================
#  MacBoost - Uninstallation and System Restoration Script
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
echo "    MacBoost — Uninstaller and System State Restoration                   "
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
#  STEP 1: Remove LaunchDaemon and Helper Binaries
# ==============================================================================
echo -e "${YELLOW}[1/5] Removing MacBoost persistence daemons and binaries...${NC}"

launchctl bootout system/com.legacy.macboost 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.legacy.macboost.plist
rm -f /usr/local/bin/macboost_boot.sh
rm -f /usr/local/bin/macboost
rm -f /usr/local/bin/optimizemac
rm -f /var/log/macboost_boot.log

echo -e "    ${GREEN}[OK] Daemons and CLI utilities removed.${NC}"

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
#  STEP 4: Re-enable Core System and User Daemons
# ==============================================================================
echo -e "${YELLOW}[4/5] Restoring launchd services (System & GUI)...${NC}"

RESTORE_SYSTEM_SERVICES=(
    "com.apple.metadata.mds"
    "com.apple.coreduetd"
    "com.apple.duetexpertd"
    "com.apple.contextstored"
    "com.apple.analyticsd"
    "com.apple.symptomsd"
    "com.apple.ReportCrash.Root"
    "com.apple.powerlogHelperd"
    "com.apple.systemstatsd"
    "com.apple.triald.system"
    "com.apple.icloud.searchpartyd"
)

RESTORE_GUI_SERVICES=(
    "com.apple.spotlightknowledged"
    "com.apple.duetexpertd"
    "com.apple.coreduetd"
    "com.apple.ContextStoreAgent"
    "com.apple.bird"
    "com.apple.cloudd"
    "com.apple.itunescloudd"
    "com.apple.akd"
    "com.apple.amsaccountsd"
    "com.apple.sidecardisplayagent"
    "com.apple.sidecarrelay"
    "com.apple.universalcontrol"
    "com.apple.continuity"
    "com.apple.AirPlayXPCHelper"
    "com.apple.intelligenceplatformd"
    "com.apple.triald"
    "com.apple.suggestd"
    "com.apple.siriknowledged"
    "com.apple.corespeechd"
    "com.apple.assistantd"
    "com.apple.mediaanalysisd"
    "com.apple.photoanalysisd"
    "com.apple.ReportCrash"
)

for s_svc in "${RESTORE_SYSTEM_SERVICES[@]}"; do
    launchctl enable system/"$s_svc" 2>/dev/null || true
done

for g_svc in "${RESTORE_GUI_SERVICES[@]}"; do
    launchctl enable gui/"$CONSOLE_UID"/"$g_svc" 2>/dev/null || true
done

echo -e "    ${GREEN}[OK] Services re-enabled in launchd configuration.${NC}"

# ==============================================================================
#  STEP 5: Restore Default Power Management Settings
# ==============================================================================
echo -e "${YELLOW}[5/5] Restoring default macOS power management configuration...${NC}"

pmset -a hibernatemode 3
pmset -a standby 1
pmset -a autopoweroff 1
pmset -a powernap 1
pmset -a womp 1
pmset -a proximitywake 1

# Re-enable Handoff preferences
sudo -u "$CONSOLE_USER" defaults -currentHost delete com.apple.coreservices.useractivityd ActivityAdvertisingAllowed 2>/dev/null || true
sudo -u "$CONSOLE_USER" defaults -currentHost delete com.apple.coreservices.useractivityd ActivityReceivingAllowed 2>/dev/null || true
sudo -u "$CONSOLE_USER" defaults delete com.apple.CloudDocs enabled 2>/dev/null || true
sudo -u "$CONSOLE_USER" defaults write com.apple.universalaccess reduceMotion -bool false

echo -e "    ${GREEN}[OK] Power management and UI motion preferences restored.${NC}"

echo ""
echo -e "${GREEN}${BOLD}=========================================================================="
echo "    MACBOOST UNINSTALLATION COMPLETED                                     "
echo "==========================================================================${NC}"
echo ""
echo "Please reboot your MacBook Pro to reload all default system services:"
echo "sudo reboot"
echo ""

