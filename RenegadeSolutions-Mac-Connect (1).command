#!/bin/bash
# Renegade Solutions - macOS Device Onboarding
# Double-click to run. Enter your Mac password when prompted.
# Removes previous RMM agents, installs Renegade Solutions NinjaOne agent.

NINJA_PKG_URL="https://app.ninjarmm.com/agent/installer/0e21ad4c-b700-455a-941b-01ed8d309c6d/11.0.5635/NinjaOne-Agent_0e21ad4c-b700-455a-941b-01ed8d309c6d_RenegadeSolutionsMSP-MainOffice-Auto.pkg"
NINJA_PKG_NAME="NinjaOne-Agent-RenegadeSolutions.pkg"
LOG_DIR="/Library/Logs/RenegadeSolutions"
LOG_FILE="$LOG_DIR/migration.log"
TEMP_DIR="/tmp/RenegadeMigration"

# ── Escalate to root via osascript (GUI password prompt) ──────
if [ "$(id -u)" -ne 0 ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)/$(basename "$0")"
    osascript -e "do shell script \"bash '$SCRIPT_PATH'\" with administrator privileges"
    exit 0
fi

# ── Setup ─────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$TEMP_DIR"
clear

echo "============================================================"
echo "  Renegade Solutions - Device Onboarding"
echo "  Please wait - do not close this window"
echo "============================================================"
echo ""

log() {
    local level="${2:-INFO}"
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')][$level] $1"
    echo "  $msg"
    echo "$msg" >> "$LOG_FILE"
}

remove_folder()   { [ -e "$1" ] && { log "Removing: $1"; rm -rf "$1" 2>/dev/null; }; }
kill_proc()       { pgrep -f "$1" >/dev/null 2>&1 && { log "Killing: $1"; pkill -9 -f "$1" 2>/dev/null; sleep 1; }; }
unload_daemon()   { [ -f "$1" ] && { log "Unloading: $1"; launchctl unload "$1" 2>/dev/null; rm -f "$1"; }; }
run_uninstaller() { [ -f "$1" ] && { log "Running uninstaller: $1"; bash "$1" 2>/dev/null || true; }; }

log "========================================"
log "Renegade Solutions Mac RMM Migration - START"
log "Host: $(hostname) | macOS: $(sw_vers -productVersion)"
log "========================================"

# Always remove any existing NinjaOne installation before re-enrolling.
# This script is the authorization -- only Renegade Solutions distributes it.
remove_any_ninja() {
    log "Removing any existing NinjaOne installation..."
    launchctl unload /Library/LaunchDaemons/com.ninjarmm.ninjarmmagent.plist 2>/dev/null
    launchctl unload /Library/LaunchDaemons/com.ninjarmm.agent.plist 2>/dev/null
    pkill -9 -f "NinjaRMMAgent" 2>/dev/null
    pkill -9 -f "ninjarmm" 2>/dev/null
    [ -f "/usr/local/bin/ninjarmm-cli" ] && /usr/local/bin/ninjarmm-cli uninstall 2>/dev/null || true
    remove_folder "/Library/Application Support/NinjaRMM"
    remove_folder "/Library/NinjaRMMAgent"
    remove_folder "/opt/NinjaRMMAgent"
    rm -f /Library/LaunchDaemons/com.ninjarmm.*.plist 2>/dev/null
    sleep 3
}

remove_any_ninja

# ══════════════════════════════════════════════════════════════
# REMOVE ALL KNOWN MAC RMM AGENTS
# ══════════════════════════════════════════════════════════════
RMMS_REMOVED=0

# Datto RMM / CentraStage
log "--- Scanning: Datto RMM / CentraStage ---"
if [ -d "/usr/local/CentraStage" ] || pgrep -f "CentraStage" >/dev/null 2>&1; then
    log "[Datto] DETECTED - removing..."
    kill_proc "CentraStage"; kill_proc "AEMAgent"
    unload_daemon "/Library/LaunchDaemons/com.centrastage.agent.plist"
    unload_daemon "/Library/LaunchDaemons/com.datto.rmm.agent.plist"
    run_uninstaller "/usr/local/CentraStage/uninstall.sh"
    remove_folder "/usr/local/CentraStage"
    remove_folder "/Library/Application Support/CentraStage"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Datto] Not present."
fi

# ConnectWise Automate
log "--- Scanning: ConnectWise Automate ---"
if [ -d "/usr/local/LTAgent" ] || pgrep -f "LTAgent" >/dev/null 2>&1; then
    log "[CW Automate] DETECTED - removing..."
    kill_proc "LTAgent"
    unload_daemon "/Library/LaunchDaemons/com.labtech.agent.plist"
    unload_daemon "/Library/LaunchDaemons/com.labtechsoftware.LTSvc.plist"
    run_uninstaller "/usr/local/LTAgent/uninstall.sh"
    remove_folder "/usr/local/LTAgent"
    remove_folder "/Library/Application Support/LabTech"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[CW Automate] Not present."
fi

# ConnectWise Control / ScreenConnect
log "--- Scanning: ConnectWise Control ---"
if ls /Applications/ConnectWiseControl*.app 2>/dev/null | grep -q .; then
    log "[ScreenConnect] DETECTED - removing..."
    kill_proc "ScreenConnect"; kill_proc "ConnectWiseControl"
    for app in /Applications/ConnectWiseControl*.app; do remove_folder "$app"; done
    unload_daemon "/Library/LaunchDaemons/com.screenconnect.agent.plist"
    remove_folder "/Library/Application Support/ScreenConnect"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[ScreenConnect] Not present."
fi

# Kaseya VSA
log "--- Scanning: Kaseya ---"
if [ -d "/Library/Kaseya" ] || pgrep -f "AgentMon" >/dev/null 2>&1; then
    log "[Kaseya] DETECTED - removing..."
    kill_proc "AgentMon"; kill_proc "KaseyaRemote"
    unload_daemon "/Library/LaunchDaemons/com.kaseya.agentmon.plist"
    run_uninstaller "/Library/Kaseya/uninstall.sh"
    remove_folder "/Library/Kaseya"
    remove_folder "/Library/Application Support/Kaseya"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Kaseya] Not present."
fi

# Atera
log "--- Scanning: Atera ---"
if [ -d "/Library/Atera Networks" ] || pgrep -f "AteraAgent" >/dev/null 2>&1; then
    log "[Atera] DETECTED - removing..."
    kill_proc "AteraAgent"
    unload_daemon "/Library/LaunchDaemons/com.atera.AteraAgent.plist"
    remove_folder "/Library/Atera Networks"
    remove_folder "/Library/Application Support/Atera Networks"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Atera] Not present."
fi

# SolarWinds / N-able
log "--- Scanning: SolarWinds ---"
if [ -d "/Library/Application Support/Advanced Monitoring Agent" ] || pgrep -f "Advanced Monitoring" >/dev/null 2>&1; then
    log "[SolarWinds] DETECTED - removing..."
    kill_proc "Advanced Monitoring Agent"
    unload_daemon "/Library/LaunchDaemons/com.solarwinds.agent.plist"
    unload_daemon "/Library/LaunchDaemons/com.n-able.agent.plist"
    remove_folder "/Library/Application Support/Advanced Monitoring Agent"
    remove_folder "/Library/Application Support/SolarWinds MSP"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[SolarWinds] Not present."
fi

# Syncro
log "--- Scanning: Syncro ---"
if [ -d "/Library/Syncro" ] || pgrep -f "SyncroLive" >/dev/null 2>&1; then
    log "[Syncro] DETECTED - removing..."
    kill_proc "SyncroLive"
    unload_daemon "/Library/LaunchDaemons/com.syncro.agent.plist"
    remove_folder "/Library/Syncro"
    remove_folder "/Library/Application Support/Syncro"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Syncro] Not present."
fi

# Pulseway
log "--- Scanning: Pulseway ---"
if [ -d "/Applications/Pulseway" ] || pgrep -f "Pulseway" >/dev/null 2>&1; then
    log "[Pulseway] DETECTED - removing..."
    kill_proc "Pulseway"
    unload_daemon "/Library/LaunchDaemons/com.pulseway.pulsewayagent.plist"
    remove_folder "/Applications/Pulseway"
    remove_folder "/Library/Application Support/Pulseway"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Pulseway] Not present."
fi

# ManageEngine
log "--- Scanning: ManageEngine ---"
if [ -d "/Library/Application Support/ManageEngine" ] || pgrep -f "UEMS_Agent" >/dev/null 2>&1; then
    log "[ManageEngine] DETECTED - removing..."
    kill_proc "UEMS_Agent"; kill_proc "dcagent"
    unload_daemon "/Library/LaunchDaemons/com.manageengine.agent.plist"
    remove_folder "/Library/Application Support/ManageEngine"
    remove_folder "/usr/local/ManageEngine"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[ManageEngine] Not present."
fi

# Tactical RMM / MeshCentral
log "--- Scanning: Tactical / MeshCentral ---"
if [ -d "/usr/local/mesh_agent" ] || pgrep -f "meshagent" >/dev/null 2>&1; then
    log "[Tactical/Mesh] DETECTED - removing..."
    kill_proc "meshagent"
    unload_daemon "/Library/LaunchDaemons/meshagent.plist"
    [ -f "/usr/local/mesh_agent/meshagent" ] && /usr/local/mesh_agent/meshagent -fulluninstall 2>/dev/null || true
    remove_folder "/usr/local/mesh_agent"
    remove_folder "/Library/Application Support/TacticalRMM"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Tactical/Mesh] Not present."
fi

# Action1
log "--- Scanning: Action1 ---"
if [ -d "/Library/Action1" ] || pgrep -f "action1" >/dev/null 2>&1; then
    log "[Action1] DETECTED - removing..."
    kill_proc "action1"
    unload_daemon "/Library/LaunchDaemons/com.action1.agent.plist"
    remove_folder "/Library/Action1"
    RMMS_REMOVED=$((RMMS_REMOVED+1))
else
    log "[Action1] Not present."
fi

log "RMM scan complete. $RMMS_REMOVED agent(s) removed."
sleep 3

# ── Download NinjaOne PKG ─────────────────────────────────────
log "Downloading Renegade Solutions NinjaOne agent (macOS PKG)..."
PKG_PATH="$TEMP_DIR/$NINJA_PKG_NAME"
echo ""
echo "  Downloading... (may take 30-60 seconds)"

curl -fL --progress-bar "$NINJA_PKG_URL" -o "$PKG_PATH" 2>&1
if [ $? -ne 0 ] || [ ! -f "$PKG_PATH" ]; then
    log "DOWNLOAD FAILED." "ERROR"
    echo ""
    echo "  ============================================================"
    echo "    ERROR: Download failed."
    echo "    Check your internet connection and try again."
    echo "    Contact support@renegadesolutions.com if issue persists."
    echo "  ============================================================"
    sleep 10
    exit 1
fi
log "Download complete: $PKG_PATH ($(du -k "$PKG_PATH" | cut -f1) KB)"

# ── Install PKG silently ──────────────────────────────────────
echo ""
echo "  Installing Renegade Solutions agent..."
log "Installing NinjaOne PKG silently..."
installer -pkg "$PKG_PATH" -target / >> "$LOG_FILE" 2>&1
INSTALL_EXIT=$?
rm -f "$PKG_PATH"
log "PKG installer exit code: $INSTALL_EXIT"

if [ $INSTALL_EXIT -ne 0 ]; then
    log "INSTALL FAILED with exit code $INSTALL_EXIT." "ERROR"
    echo ""
    echo "  ============================================================"
    echo "    ERROR: Installation failed (code $INSTALL_EXIT)."
    echo "    Log: $LOG_FILE"
    echo "    Contact support@renegadesolutions.com"
    echo "  ============================================================"
    sleep 10
    exit 1
fi

# ── Verify agent running ──────────────────────────────────────
log "Verifying NinjaOne agent..."
echo "  Verifying connection..."
VERIFIED=0
for i in $(seq 1 10); do
    sleep 10
    if pgrep -f "NinjaRMMAgent" >/dev/null 2>&1; then
        log "NinjaRMMAgent confirmed running (check $i/10)"
        VERIFIED=1; break
    else
        log "Not yet running (check $i/10)..."
    fi
done

echo ""
if [ $VERIFIED -eq 1 ]; then
    log "=== MIGRATION COMPLETE - Renegade Solutions NinjaOne agent running. $RMMS_REMOVED prior RMM(s) removed. ==="
    echo "  ============================================================"
    echo "    SUCCESS"
    echo "    Your device is now connected to Renegade Solutions."
    echo "    You may close this window."
    echo "  ============================================================"
    sleep 8
    exit 0
else
    log "=== WARNING - NinjaOne agent not confirmed running. ===" "WARN"
    echo "  ============================================================"
    echo "    ACTION NEEDED"
    echo "    Setup encountered an issue. Please contact:"
    echo "    support@renegadesolutions.com"
    echo "    Log: $LOG_FILE"
    echo "  ============================================================"
    sleep 10
    exit 1
fi
