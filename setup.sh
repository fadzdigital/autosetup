#!/bin/bash

# ====================================================================
# VPS Automation Setup Script
# Version: 1.0
# Author: MikkuChan
# Description: Complete automation setup with error handling & monitoring
# ====================================================================

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly UNDERLINE='\033[4m'
readonly RESET='\033[0m'

# Icons for better visual experience
readonly SUCCESS="✅"
readonly ERROR="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly ROCKET="🚀"
readonly GEAR="⚙️"
readonly SHIELD="🛡️"
readonly CLOCK="🕐"

# Global variables
SCRIPT_NAME="VPS Automation Setup"
SCRIPT_VERSION="1.0"
LOG_FILE="/var/log/vps_setup.log"
ERROR_COUNT=0
SETUP_START_TIME=$(date +%s)

# Logging function with timestamp and colors
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${CYAN}${INFO} [${timestamp}] INFO: ${message}${RESET}" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}${SUCCESS} [${timestamp}] SUCCESS: ${message}${RESET}" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}${WARNING} [${timestamp}] WARNING: ${message}${RESET}" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}${ERROR} [${timestamp}] ERROR: ${message}${RESET}" | tee -a "$LOG_FILE"
            ((ERROR_COUNT++))
            ;;
        "HEADER")
            echo -e "${BOLD}${MAGENTA}${message}${RESET}" | tee -a "$LOG_FILE"
            ;;
    esac
}

#  banner with system info
show_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║  ██╗   ██╗██████╗ ███████╗     █████╗ ██╗   ██╗████████╗ ██████╗  ║
║  ██║   ██║██╔══██╗██╔════╝    ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗ ║
║  ██║   ██║██████╔╝███████╗    ███████║██║   ██║   ██║   ██║   ██║ ║
║  ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██╔══██║██║   ██║   ██║   ██║   ██║ ║
║   ╚████╔╝ ██║     ███████║    ██║  ██║╚██████╔╝   ██║   ╚██████╔╝ ║
║    ╚═══╝  ╚═╝     ╚══════╝    ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝  ║
║                                                                   ║
║               AUTOMATION SETUP SCRIPT                             ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
    
    log "HEADER" "═══════════════════════════════════════════════════════════"
    log "HEADER" "    ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log "HEADER" "    System: $(uname -s) $(uname -r)"
    log "HEADER" "    Hostname: $(hostname)"
    log "HEADER" "    Date: $(date)"
    log "HEADER" "═══════════════════════════════════════════════════════════"
}

#  error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    log "ERROR" "Command failed with exit code $exit_code at line $line_number: $command"
    
    # Offer recovery options
    echo -e "${YELLOW}${WARNING} Would you like to:${RESET}"
    echo -e "${WHITE}1) Continue with setup (skip this step)${RESET}"
    echo -e "${WHITE}2) Retry the failed command${RESET}"
    echo -e "${WHITE}3) Exit setup${RESET}"
    
    read -p "Choose option [1-3]: " choice
    case $choice in
        1) log "WARNING" "Continuing setup, skipping failed step..." ;;
        2) return 1 ;; # Signal to retry
        3) exit 1 ;;
        *) log "WARNING" "Invalid choice, continuing..." ;;
    esac
}

# Set up error trapping
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

# Validate system requirements
validate_system() {
    log "INFO" "${GEAR} Validating system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log "ERROR" "No internet connection detected"
        exit 1
    fi
    
    # Check available disk space (minimum 1GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then
        log "WARNING" "Low disk space detected (less than 1GB available)"
    fi
    
    log "SUCCESS" "System validation completed"
}

# Secure input function for sensitive data
secure_input() {
    local prompt="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    
    while true; do
        if [[ "$is_secret" == "true" ]]; then
            read -s -p "$prompt" input
            echo
        else
            read -p "$prompt" input
        fi
        
        if [[ -n "$input" ]]; then
            declare -g "$var_name=$input"
            break
        else
            log "WARNING" "Input cannot be empty. Please try again."
        fi
    done
}

# Create telegram bot configuration with  security
setup_telegram_config() {
    log "INFO" "${GEAR} Setting up Telegram bot configuration..."
    
    # Create secure directory structure
    mkdir -p /etc/telegram_bot
    chmod 700 /etc/telegram_bot
    
    echo -e "${BOLD}${CYAN}Please provide your Telegram bot credentials:${RESET}"
    
    # Get bot token securely
    secure_input "Enter your Telegram Bot Token: " "BOT_TOKEN" "true"
    secure_input "Enter your Telegram Chat ID (for personal logs): " "CHAT_ID"
    secure_input "Enter your Telegram Chat ID for reboot notification (channel): " "CHAT_ID_NOTIF_REBOOT"

    # Validate token format (basic validation)
    if [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        log "WARNING" "Bot token format seems incorrect, but proceeding..."
    fi
    
    # Write configuration files
    echo "$BOT_TOKEN" > /etc/telegram_bot/bot_token
    echo "$CHAT_ID" > /etc/telegram_bot/chat_id
    echo "$CHAT_ID_NOTIF_REBOOT" > /etc/telegram_bot/chat_id_notifreboot

    # Set secure permissions
    chmod 600 /etc/telegram_bot/bot_token
    chmod 600 /etc/telegram_bot/chat_id
    chmod 600 /etc/telegram_bot/chat_id_notifreboot

    # Test telegram connectivity
    if curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe" | grep -q '"ok":true'; then
        log "SUCCESS" "Telegram bot configuration verified"
    else
        log "WARNING" "Could not verify Telegram bot (check token)"
    fi
}

# Install and configure fail2ban with custom rules
setup_fail2ban() {
    log "INFO" "${SHIELD} Installing and configuring Fail2Ban..."
    
    # Update package list
    apt update -qq
    
    # Install fail2ban
    apt install fail2ban -y
    
    # Start and enable fail2ban
    systemctl start fail2ban
    systemctl enable fail2ban
    
    # Create custom jail configuration
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = true
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
logpath = /var/log/nginx/access.log
maxretry = 6
EOF
    
    # Restart fail2ban to apply configuration
    systemctl restart fail2ban
    
    # Verify fail2ban status
    if systemctl is-active --quiet fail2ban; then
        log "SUCCESS" "Fail2Ban installed and configured successfully"
    else
        log "ERROR" "Fail2Ban installation failed"
        return 1
    fi
}

# Create  autoreboot script with better error handling
create_autoreboot_script() {
    log "INFO" "${GEAR} Creating  auto-reboot script..."
    
    cat > /root/autoreboot.sh << 'EOF'
#!/bin/bash

#  Auto-Reboot Script with Channel Notification
# Version: 1.0

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Configuration
BOT_TOKEN=$(cat /etc/telegram_bot/bot_token 2>/dev/null)
CHAT_ID_NOTIF_REBOOT=$(cat /etc/telegram_bot/chat_id_notifreboot 2>/dev/null)
LOG_FILE="/var/log/autoreboot.log"

# System information gathering
VPS_NAME=$(hostname)
IP_VPS=$(timeout 10 curl -s https://ipinfo.io/ip || echo "Unknown")
REGION_VPS=$(timeout 10 curl -s https://ipinfo.io/region || echo "Unknown")
ISP_VPS=$(timeout 10 curl -s https://ipinfo.io/org | cut -d " " -f 2- || echo "Unknown")

# Time information
HARI=$(date +"%A")
TANGGAL=$(date +"%Y-%m-%d")
JAM_SEKARANG=$(date +"%H:%M:%S")

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Service check with timeout
check_service() {
    local service=$1
    local timeout=${2:-10}
    if timeout $timeout systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "✅"
    else
        echo "❌"
    fi
}

# Send telegram message with retry mechanism
send_telegram() {
    local message="$1"
    local chat_id="$2"
    local max_retries=3
    local retry_count=0

    if [[ -z "$BOT_TOKEN" || -z "$chat_id" ]]; then
        log_message "ERROR: Telegram credentials not found"
        return 1
    fi

    while [[ $retry_count -lt $max_retries ]]; do
        if curl -s -m 30 -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$chat_id" \
            -d text="$message" \
            -d parse_mode=Markdown > /dev/null 2>&1; then
            log_message "SUCCESS: Telegram message sent"
            return 0
        else
            ((retry_count++))
            log_message "WARNING: Telegram send attempt $retry_count failed"
            sleep 5
        fi
    done

    log_message "ERROR: Failed to send telegram message after $max_retries attempts"
    return 1
}

# Service restart with error handling
restart_service() {
    local service=$1
    log_message "Restarting $service..."
    if systemctl restart "$service" 2>/dev/null; then
        log_message "SUCCESS: $service restarted"
        return 0
    else
        log_message "ERROR: Failed to restart $service"
        return 1
    fi
}

# Post-reboot operations
if [[ "$1" == "after_reboot" ]]; then
    log_message "=== POST-REBOOT OPERATIONS STARTED ==="
    sleep 15

    # Restart critical services
    services=(
        "ssh"
        "nginx"
        "haproxy"
        "xray"
        "openvpn"
        "dropbear"
        "fail2ban"
        "ws"
        "udp-mini-1"
        "udp-mini-2"
        "udp-mini-3"
    )

    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            restart_service "$service"
        else
            log_message "INFO: Service $service not found, skipping"
        fi
    done

    # Additional operations for UDP services
    for i in {1..3}; do
        service="udp-mini-$i"
        if systemctl list-unit-files | grep -q "$service"; then
            systemctl disable "$service" 2>/dev/null
            systemctl stop "$service" 2>/dev/null
            systemctl enable "$service" 2>/dev/null
            systemctl start "$service" 2>/dev/null
        fi
    done

    # Check all service statuses
    STATUS_SSH=$(check_service ssh)
    STATUS_NGINX=$(check_service nginx)
    STATUS_HAPROXY=$(check_service haproxy)
    STATUS_XRAY=$(check_service xray)
    STATUS_OPENVPN=$(check_service openvpn)
    STATUS_DROPBEAR=$(check_service dropbear)
    STATUS_FAIL2BAN=$(check_service fail2ban)
    STATUS_WS=$(check_service ws)
    STATUS_UDP1=$(check_service udp-mini-1)
    STATUS_UDP2=$(check_service udp-mini-2)
    STATUS_UDP3=$(check_service udp-mini-3)

    # System resource check
    UPTIME=$(uptime -p)
    LOAD_AVG=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}')

    # Compose post-reboot message
    POST_MESSAGE="🎯 **SYSTEM REBOOT COMPLETED** 🎯

╔═══════════════╗
║           SERVER INFO       ║
╚═══════════════╝
🖥️ **Hostname:** \`$VPS_NAME\`
🌐 **IP Address:** \`$IP_VPS\`
📍 **Region:** \`$REGION_VPS\`
🏢 **ISP:** \`$ISP_VPS\`

╔═══════════════╗
║      REBOOT STATUS      ║
╚═══════════════╝
📅 **Date:** $HARI, $TANGGAL
🕐 **Time:** $JAM_SEKARANG
⏱️ **Uptime:** $UPTIME

╔═════════════════╗
║    SYSTEM RESOURCE        ║
╚═════════════════╝
📊 **Load Average:** \`$LOAD_AVG\`
💾 **Memory Usage:** \`$MEMORY_USAGE\`
💿 **Disk Usage:** \`$DISK_USAGE\`

╔═══════════════╗
║     SERVICES STATUS    ║
╚═══════════════╝
🔐 **SSH:** $STATUS_SSH
🌐 **Nginx:** $STATUS_NGINX
⚖️ **HAProxy:** $STATUS_HAPROXY
🔀 **Xray:** $STATUS_XRAY
🔒 **OpenVPN:** $STATUS_OPENVPN
📡 **Dropbear:** $STATUS_DROPBEAR
🛡️ **Fail2Ban:** $STATUS_FAIL2BAN
🔌 **WebSocket:** $STATUS_WS
🎯 **UDP Mini 1:** $STATUS_UDP1
🎯 **UDP Mini 2:** $STATUS_UDP2
🎯 **UDP Mini 3:** $STATUS_UDP3

╔══════════════════╗
║     MONITORING ACTIVE       ║
╚══════════════════╝
🤖 **Automated by:** @fadzdigital
✅ **Status:** All systems operational"

    send_telegram "$POST_MESSAGE" "$CHAT_ID_NOTIF_REBOOT"
    log_message "=== POST-REBOOT OPERATIONS COMPLETED ==="
    exit 0
fi

# Pre-reboot notification
log_message "=== PRE-REBOOT NOTIFICATION ==="

PRE_MESSAGE="⚠️ **SCHEDULED SYSTEM REBOOT** ⚠️

╔═══════════════╗
║           SERVER INFO       ║
╚═══════════════╝
🖥️ **Hostname:** \`$VPS_NAME\`
🌐 **IP Address:** \`$IP_VPS\`
📍 **Region:** \`$REGION_VPS\`
🏢 **ISP:** \`$ISP_VPS\`

╔══════════════════╗
║        REBOOT SCHEDULE       ║
╚══════════════════╝
📅 **Date:** $HARI, $TANGGAL
🕐 **Time:** $JAM_SEKARANG
⏳ **Action:** Rebooting in 30 seconds...

🔄 **This is an automated maintenance reboot**
📱 **You will receive confirmation once completed**

🤖 **Automated by:** @fadzdigital"

send_telegram "$PRE_MESSAGE" "$CHAT_ID_NOTIF_REBOOT"

# Wait before rebooting
log_message "Waiting 30 seconds before reboot..."
sleep 30

# Perform reboot
log_message "Initiating system reboot..."
/sbin/reboot
EOF
    
    # Make the script executable
    chmod +x /root/autoreboot.sh
    
    log "SUCCESS" "Auto-reboot script created successfully"
}

# Setup crontab for scheduled reboots
setup_crontab() {
    log "INFO" "${CLOCK} Setting up scheduled tasks..."
    
    # Backup existing crontab
    crontab -l > /tmp/crontab_backup 2>/dev/null || true
    
    # Create new crontab entries
    cat > /tmp/new_crontab << 'EOF'
# Automated system reboots (3 times daily)
0 0 * * * /bin/bash /root/autoreboot.sh >/dev/null 2>&1
0 5 * * * /bin/bash /root/autoreboot.sh >/dev/null 2>&1
0 18 * * * /bin/bash /root/autoreboot.sh >/dev/null 2>&1

# Backup schedule (every 2 hours)
0 0,12,2,14,5,17,7,19,9,21 * * * /usr/local/sbin/backup >/dev/null 2>&1

# System monitoring (every 30 minutes)
*/30 * * * * /usr/bin/systemctl is-system-running --quiet || echo "System issues detected at $(date)" >> /var/log/system_alerts.log

# Log rotation (daily at 2 AM)
0 2 * * * /usr/sbin/logrotate /etc/logrotate.conf >/dev/null 2>&1
EOF
    
    # Install new crontab
    crontab /tmp/new_crontab
    
    # Make backup script executable if it exists
    if [[ -f /usr/local/sbin/backup ]]; then
        chmod +x /usr/local/sbin/backup
    else
        log "WARNING" "Backup script not found at /usr/local/sbin/backup"
    fi
    
    log "SUCCESS" "Crontab configured successfully"
}

# Configure rc.local for startup tasks
setup_rc_local() {
    log "INFO" "${GEAR} Configuring startup script..."
    
    # Backup existing rc.local
    [[ -f /etc/rc.local ]] && cp /etc/rc.local /etc/rc.local.backup
    
    # Create  rc.local
    cat > /etc/rc.local << 'EOF'
#!/bin/bash
# rc.local -  startup script
# This script is executed at the end of each multiuser runlevel

# Log startup
echo "[$(date)] System startup initiated" >> /var/log/startup.log

# Wait for network to be ready
sleep 10

# Execute post-reboot script in background
/bin/bash /root/autoreboot.sh after_reboot &

# Additional startup tasks can be added here

# Log completion
echo "[$(date)] Startup script completed" >> /var/log/startup.log

exit 0
EOF
    
    # Make rc.local executable
    chmod +x /etc/rc.local
    
    # Enable rc-local service if it exists
    if systemctl list-unit-files | grep -q rc-local; then
        systemctl enable rc-local
    fi
    
    log "SUCCESS" "Startup script configured successfully"
}

# System optimization and security hardening
optimize_system() {
    log "INFO" "${GEAR} Applying system optimizations..."
    
    # Update system limits
    cat >> /etc/security/limits.conf << 'EOF'

# VPS Optimization Limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
    
    # Optimize sysctl parameters
    cat >> /etc/sysctl.conf << 'EOF'

# VPS Network Optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    
    # Apply sysctl settings
    sysctl -p >/dev/null 2>&1
    
    log "SUCCESS" "System optimizations applied"
}

# Final system verification
verify_setup() {
    log "INFO" "${GEAR} Performing final verification..."
    
    local checks_passed=0
    local total_checks=6
    
    # Check telegram config
    if [[ -f /etc/telegram_bot/bot_token && -f /etc/telegram_bot/chat_id ]]; then
        log "SUCCESS" "Telegram configuration: OK"
        ((checks_passed++))
    else
        log "ERROR" "Telegram configuration: FAILED"
    fi
    
    # Check fail2ban
    if systemctl is-active --quiet fail2ban; then
        log "SUCCESS" "Fail2Ban service: OK"
        ((checks_passed++))
    else
        log "ERROR" "Fail2Ban service: FAILED"
    fi
    
    # Check autoreboot script
    if [[ -x /root/autoreboot.sh ]]; then
        log "SUCCESS" "Auto-reboot script: OK"
        ((checks_passed++))
    else
        log "ERROR" "Auto-reboot script: FAILED"
    fi
    
    # Check crontab
    if crontab -l | grep -q autoreboot.sh; then
        log "SUCCESS" "Crontab configuration: OK"
        ((checks_passed++))
    else
        log "ERROR" "Crontab configuration: FAILED"
    fi
    
    # Check rc.local
    if [[ -x /etc/rc.local ]]; then
        log "SUCCESS" "Startup script: OK"
        ((checks_passed++))
    else
        log "ERROR" "Startup script: FAILED"
    fi
    
    # Check log files
    if [[ -f "$LOG_FILE" ]]; then
        log "SUCCESS" "Logging system: OK"
        ((checks_passed++))
    else
        log "ERROR" "Logging system: FAILED"
    fi
    
    # Summary
    local success_rate=$((checks_passed * 100 / total_checks))
    
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║                    SETUP SUMMARY REPORT                                 ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo -e "${WHITE}Total Checks: ${total_checks}${RESET}"
    echo -e "${GREEN}Passed: ${checks_passed}${RESET}"
    echo -e "${RED}Failed: $((total_checks - checks_passed))${RESET}"
    echo -e "${YELLOW}Success Rate: ${success_rate}%${RESET}"
    echo -e "${WHITE}Errors Encountered: ${ERROR_COUNT}${RESET}"
    
    local setup_duration=$(($(date +%s) - SETUP_START_TIME))
    echo -e "${BLUE}Setup Duration: ${setup_duration} seconds${RESET}"
    
    if [[ $success_rate -ge 80 ]]; then
        log "SUCCESS" "Setup completed successfully! 🎉"
        echo -e "\n${GREEN}${SUCCESS} System is ready for automated operations!${RESET}"
        echo -e "${YELLOW}${INFO} You can now reboot the system to test the automation.${RESET}"
    else
        log "WARNING" "Setup completed with some issues. Please review the logs."
        echo -e "\n${YELLOW}${WARNING} Some components may need manual attention.${RESET}"
    fi
}

# Cleanup function
cleanup() {
    log "INFO" "Performing cleanup..."
    rm -f /tmp/crontab_backup /tmp/new_crontab
    log "SUCCESS" "Cleanup completed"
}

# Main execution flow
main() {
    show_banner
    
    # Execute setup steps
    validate_system
    setup_telegram_config
    setup_fail2ban
    create_autoreboot_script
    setup_crontab
    setup_rc_local
    optimize_system
    verify_setup
    cleanup
    
    echo -e "\n${BOLD}${GREEN}${ROCKET} VPS Automation Setup Complete! ${ROCKET}${RESET}"
    echo -e "${CYAN}Thank you for using our premium automation solution.${RESET}"
    echo -e "${WHITE}Log file location: ${LOG_FILE}${RESET}"
    
    # Final confirmation
    echo -e "\n${YELLOW}Would you like to reboot now to activate all services? [y/N]: ${RESET}"
    read -r reboot_choice
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        log "INFO" "Initiating immediate reboot..."
        sleep 3
        reboot
    else
        log "INFO" "Setup complete. Reboot when convenient to activate all features."
    fi
}

# Execute main function
main "$@"

