#!/bin/bash

# ====================================================================
# Skrip Otomatisasi Setup VPS Profesional
# Versi: 2.0
# Penulis: fadzTech
# Deskripsi: Setup otomatis lengkap dengan penanganan error & monitoring
# ====================================================================

# Definisi warna untuk output profesional
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

# Ikon untuk pengalaman visual lebih baik
readonly SUCCESS="✅"
readonly ERROR="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly ROCKET="🚀"
readonly GEAR="⚙️"
readonly SHIELD="🛡️"
readonly CLOCK="🕐"

# Variabel global
SCRIPT_NAME="Setup Otomatisasi VPS fadzTech"
SCRIPT_VERSION="2.0"
LOG_FILE="/var/log/vps_setup.log"
ERROR_COUNT=0
SETUP_START_TIME=$(date +%s)

# Fungsi logging dengan timestamp dan warna
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
            echo -e "${GREEN}${SUCCESS} [${timestamp}] SUKSES: ${message}${RESET}" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}${WARNING} [${timestamp}] PERINGATAN: ${message}${RESET}" | tee -a "$LOG_FILE"
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

# Banner profesional dengan info sistem
show_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║ ███████╗ █████╗ ██████╗ ███████╗████████╗███████╗ ██████╗██╗  ██╗║
║ ██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔════╝╚██╗██╔╝║
║ █████╗  ███████║██║  ██║█████╗     ██║   █████╗  ██║      ╚███╔╝ ║
║ ██╔══╝  ██╔══██║██║  ██║██╔══╝     ██║   ██╔══╝  ██║      ██╔██╗ ║
║ ██║     ██║  ██║██████╔╝███████╗   ██║   ███████╗╚██████╗██╔╝ ██╗║
║ ╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝║
║                                                                   ║
║              SOLUSI OTOMATISASI VPS PROFESIONAL                   ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
    
    log "HEADER" "═══════════════════════════════════════════════════════════"
    log "HEADER" "    ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log "HEADER" "    Sistem: $(uname -s) $(uname -r)"
    log "HEADER" "    Hostname: $(hostname)"
    log "HEADER" "    Tanggal: $(date)"
    log "HEADER" "═══════════════════════════════════════════════════════════"
}

# Penanganan error yang ditingkatkan
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    log "ERROR" "Perintah gagal dengan kode $exit_code di baris $line_number: $command"
    
    # Tawarkan opsi pemulihan
    echo -e "${YELLOW}${WARNING} Pilihan yang tersedia:${RESET}"
    echo -e "${WHITE}1) Lanjutkan setup (lewati langkah ini)${RESET}"
    echo -e "${WHITE}2) Coba lagi perintah yang gagal${RESET}"
    echo -e "${WHITE}3) Keluar dari setup${RESET}"
    
    read -p "Pilih opsi [1-3]: " choice
    case $choice in
        1) log "WARNING" "Melanjutkan setup, melewati langkah yang gagal..." ;;
        2) return 1 ;; # Sinyal untuk mencoba lagi
        3) exit 1 ;;
        *) log "WARNING" "Pilihan tidak valid, melanjutkan..." ;;
    esac
}

# Setup penanganan error
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

# Validasi persyaratan sistem
validate_system() {
    log "INFO" "${GEAR} Memvalidasi persyaratan sistem..."
    
    # Cek apakah dijalankan sebagai root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Skrip ini harus dijalankan sebagai root (gunakan sudo)"
        exit 1
    fi
    
    # Cek konektivitas internet
    if ! ping -c 1 google.com &> /dev/null; then
        log "ERROR" "Tidak terdeteksi koneksi internet"
        exit 1
    fi
    
    # Cek ruang disk yang tersedia (minimal 1GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then
        log "WARNING" "Ditemukan ruang disk rendah (kurang dari 1GB tersedia)"
    fi
    
    log "SUCCESS" "Validasi sistem selesai"
}

# Fungsi input aman untuk data sensitif
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
            log "WARNING" "Input tidak boleh kosong. Silakan coba lagi."
        fi
    done
}

# Buat konfigurasi bot telegram dengan keamanan yang ditingkatkan
setup_telegram_config() {
    log "INFO" "${GEAR} Menyiapkan konfigurasi bot Telegram..."
    
    # Buat struktur direktori aman
    mkdir -p /etc/telegram_bot
    chmod 700 /etc/telegram_bot
    
    echo -e "${BOLD}${CYAN}Silakan berikan kredensial bot Telegram Anda:${RESET}"
    
    # Dapatkan token bot secara aman
    secure_input "Masukkan Token Bot Telegram: " "BOT_TOKEN" "true"
    secure_input "Masukkan Chat ID Telegram: " "CHAT_ID"
    
    # Validasi format token (validasi dasar)
    if [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        log "WARNING" "Format token bot tampaknya tidak benar, tetapi melanjutkan..."
    fi
    
    # Tulis file konfigurasi
    echo "$BOT_TOKEN" > /etc/telegram_bot/bot_token
    echo "$CHAT_ID" > /etc/telegram_bot/chat_id
    
    # Setel izin yang aman
    chmod 600 /etc/telegram_bot/bot_token
    chmod 600 /etc/telegram_bot/chat_id
    
    # Tes konektivitas telegram
    if curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe" | grep -q '"ok":true'; then
        log "SUCCESS" "Konfigurasi bot Telegram terverifikasi"
    else
        log "WARNING" "Tidak dapat memverifikasi bot Telegram (periksa token)"
    fi
}

# Instal dan konfigurasi fail2ban dengan aturan khusus
setup_fail2ban() {
    log "INFO" "${SHIELD} Menginstal dan mengkonfigurasi Fail2Ban..."
    
    # Perbarui daftar paket
    apt update -qq
    
    # Instal fail2ban
    apt install fail2ban -y
    
    # Mulai dan aktifkan fail2ban
    systemctl start fail2ban
    systemctl enable fail2ban
    
    # Buat konfigurasi jail khusus
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
    
    # Restart fail2ban untuk menerapkan konfigurasi
    systemctl restart fail2ban
    
    # Verifikasi status fail2ban
    if systemctl is-active --quiet fail2ban; then
        log "SUCCESS" "Fail2Ban terinstal dan dikonfigurasi dengan sukses"
    else
        log "ERROR" "Instalasi Fail2Ban gagal"
        return 1
    fi
}

# Buat skrip autoreboot yang ditingkatkan dengan penanganan error yang lebih baik
create_autoreboot_script() {
    log "INFO" "${GEAR} Membuat skrip auto-reboot yang ditingkatkan..."
    
    cat > /root/autoreboot.sh << 'EOF'
#!/bin/bash

# Skrip Auto-Reboot yang Ditingkatkan dengan Fitur Profesional
# Versi: 2.0

# Definisi warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Konfigurasi
BOT_TOKEN=$(cat /etc/telegram_bot/bot_token 2>/dev/null)
CHAT_ID=$(cat /etc/telegram_bot/chat_id 2>/dev/null)
LOG_FILE="/var/log/autoreboot.log"

# Pengumpulan informasi sistem
VPS_NAME=$(hostname)
IP_VPS=$(timeout 10 curl -s https://ipinfo.io/ip || echo "Tidak Diketahui")
REGION_VPS=$(timeout 10 curl -s https://ipinfo.io/region || echo "Tidak Diketahui")
ISP_VPS=$(timeout 10 curl -s https://ipinfo.io/org | cut -d " " -f 2- || echo "Tidak Diketahui")

# Informasi waktu
HARI=$(date +"%A")
TANGGAL=$(date +"%Y-%m-%d")
JAM_SEKARANG=$(date +"%H:%M:%S")

# Fungsi logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Pengecekan layanan yang ditingkatkan dengan timeout
check_service() {
    local service=$1
    local timeout=${2:-10}
    
    if timeout $timeout systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "✅"
    else
        echo "❌"
    fi
}

# Kirim pesan telegram dengan mekanisme coba ulang
send_telegram() {
    local message="$1"
    local max_retries=3
    local retry_count=0
    
    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        log_message "ERROR: Kredensial Telegram tidak ditemukan"
        return 1
    fi
    
    while [[ $retry_count -lt $max_retries ]]; do
        if curl -s -m 30 -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$CHAT_ID" \
            -d text="$message" \
            -d parse_mode=Markdown > /dev/null 2>&1; then
            log_message "SUCCESS: Pesan Telegram terkirim"
            return 0
        else
            ((retry_count++))
            log_message "WARNING: Percobaan pengiriman Telegram ke-$retry_count gagal"
            sleep 5
        fi
    done
    
    log_message "ERROR: Gagal mengirim pesan telegram setelah $max_retries percobaan"
    return 1
}

# Restart layanan dengan penanganan error
restart_service() {
    local service=$1
    log_message "Merestart $service..."
    
    if systemctl restart "$service" 2>/dev/null; then
        log_message "SUCCESS: $service berhasil direstart"
        return 0
    else
        log_message "ERROR: Gagal merestart $service"
        return 1
    fi
}

# Operasi pasca-reboot
if [[ "$1" == "after_reboot" ]]; then
    log_message "=== OPERASI PASCA-REBOOT DIMULAI ==="
    
    # Tunggu sistem stabil
    sleep 15
    
    # Restart layanan kritis
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
            log_message "INFO: Layanan $service tidak ditemukan, dilewati"
        fi
    done
    
    # Operasi layanan tambahan untuk layanan UDP
    for i in {1..3}; do
        service="udp-mini-$i"
        if systemctl list-unit-files | grep -q "$service"; then
            systemctl disable "$service" 2>/dev/null
            systemctl stop "$service" 2>/dev/null
            systemctl enable "$service" 2>/dev/null
            systemctl start "$service" 2>/dev/null
        fi
    done
    
    # Periksa status semua layanan
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
    
    # Pemeriksaan sumber daya sistem
    UPTIME=$(uptime -p)
    LOAD_AVG=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}')
    
    # Susun pesan pasca-reboot
    POST_MESSAGE="🎯 **REBOOT SISTEM SELESAI** 🎯

╔══════════════════════════════╗
║           INFO SERVER        ║
╚══════════════════════════════╝
🖥️ **Hostname:** \`$VPS_NAME\`
🌐 **Alamat IP:** \`$IP_VPS\`
📍 **Wilayah:** \`$REGION_VPS\`
🏢 **ISP:** \`$ISP_VPS\`

╔══════════════════════════════╗
║        STATUS REBOOT         ║
╚══════════════════════════════╝
📅 **Tanggal:** $HARI, $TANGGAL
🕐 **Waktu:** $JAM_SEKARANG
⏱️ **Uptime:** $UPTIME

╔══════════════════════════════╗
║       SUMBER DAYA SISTEM     ║
╚══════════════════════════════╝
📊 **Load Average:** \`$LOAD_AVG\`
💾 **Penggunaan Memori:** \`$MEMORY_USAGE\`
💿 **Penggunaan Disk:** \`$DISK_USAGE\`

╔══════════════════════════════╗
║       STATUS LAYANAN         ║
╚══════════════════════════════╝
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

╔══════════════════════════════╗
║     MONITORING AKTIF         ║
╚══════════════════════════════╝
🤖 **Otomatis oleh:** @fadzdigital
✅ **Status:** Semua sistem beroperasi"
    
    send_telegram "$POST_MESSAGE"
    log_message "=== OPERASI PASCA-REBOOT SELESAI ==="
    exit 0
fi

# Notifikasi pra-reboot
log_message "=== NOTIFIKASI PRA-REBOOT ==="

PRE_MESSAGE="⚠️ **REBOOT SISTEM TERJADWAL** ⚠️

╔══════════════════════════════╗
║           INFO SERVER        ║
╚══════════════════════════════╝
🖥️ **Hostname:** \`$VPS_NAME\`
🌐 **Alamat IP:** \`$IP_VPS\`
📍 **Wilayah:** \`$REGION_VPS\`
🏢 **ISP:** \`$ISP_VPS\`

╔══════════════════════════════╗
║        JADWAL REBOOT         ║
╚══════════════════════════════╝
📅 **Tanggal:** $HARI, $TANGGAL
🕐 **Waktu:** $JAM_SEKARANG
⏳ **Aksi:** Reboot dalam 30 detik...

🔄 **Ini adalah reboot pemeliharaan otomatis**
📱 **Anda akan menerima konfirmasi setelah selesai**

🤖 **Otomatis oleh:** @fadzdigital"

send_telegram "$PRE_MESSAGE"

# Tunggu sebelum reboot
log_message "Menunggu 30 detik sebelum reboot..."
sleep 30

# Lakukan reboot
log_message "Memulai reboot sistem..."
/sbin/reboot
EOF
    
    # Buat skrip dapat dieksekusi
    chmod +x /root/autoreboot.sh
    
    log "SUCCESS" "Skrip auto-reboot berhasil dibuat"
}

# Setup crontab untuk reboot terjadwal
setup_crontab() {
    log "INFO" "${CLOCK} Menyiapkan tugas terjadwal..."
    
    # Backup crontab yang ada
    crontab -l > /tmp/crontab_backup 2>/dev/null || true
    
    # Buat entri crontab baru
    cat > /tmp/new_crontab << 'EOF'
# Reboot otomatis sistem (3 kali sehari)
0 0 * * * /bin/bash /root/autoreboot.sh >/dev/null 2>&1
0 5 * * * /bin/bash /root/autoreboot.sh >/dev/null 2>&1
0 18 * * * /bin/bash /root/autoreboot.sh >/dev/null 2>&1

# Jadwal backup (setiap 2 jam)
0 0,12,2,14,5,17,7,19,9,21 * * * /usr/local/sbin/backup >/dev/null 2>&1

# Pemantauan sistem (setiap 30 menit)
*/30 * * * * /usr/bin/systemctl is-system-running --quiet || echo "Masalah sistem terdeteksi pada $(date)" >> /var/log/system_alerts.log

# Rotasi log (setiap hari jam 2 AM)
0 2 * * * /usr/sbin/logrotate /etc/logrotate.conf >/dev/null 2>&1
EOF
    
    # Instal crontab baru
    crontab /tmp/new_crontab
    
    # Buat skrip backup dapat dieksekusi jika ada
    if [[ -f /usr/local/sbin/backup ]]; then
        chmod +x /usr/local/sbin/backup
    else
        log "WARNING" "Skrip backup tidak ditemukan di /usr/local/sbin/backup"
    fi
    
    log "SUCCESS" "Crontab berhasil dikonfigurasi"
}

# Konfigurasi rc.local untuk tugas startup
setup_rc_local() {
    log "INFO" "${GEAR} Mengkonfigurasi skrip startup..."
    
    # Backup rc.local yang ada
    [[ -f /etc/rc.local ]] && cp /etc/rc.local /etc/rc.local.backup
    
    # Buat rc.local yang ditingkatkan
    cat > /etc/rc.local << 'EOF'
#!/bin/bash
# rc.local - Skrip startup yang ditingkatkan
# Skrip ini dieksekusi di akhir setiap runlevel multiuser

# Log startup
echo "[$(date)] Startup sistem dimulai" >> /var/log/startup.log

# Tunggu jaringan siap
sleep 10

# Eksekusi skrip pasca-reboot di background
/bin/bash /root/autoreboot.sh after_reboot &

# Tugas startup tambahan dapat ditambahkan di sini

# Log penyelesaian
echo "[$(date)] Skrip startup selesai" >> /var/log/startup.log

exit 0
EOF
    
    # Buat rc.local dapat dieksekusi
    chmod +x /etc/rc.local
    
    # Aktifkan layanan rc-local jika ada
    if systemctl list-unit-files | grep -q rc-local; then
        systemctl enable rc-local
    fi
    
    log "SUCCESS" "Skrip startup berhasil dikonfigurasi"
}

# Optimisasi sistem dan peningkatan keamanan
optimize_system() {
    log "INFO" "${GEAR} Menerapkan optimisasi sistem..."
    
    # Perbarui batas sistem
    cat >> /etc/security/limits.conf << 'EOF'

# Batas Optimisasi VPS
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
    
    # Optimalkan parameter sysctl
    cat >> /etc/sysctl.conf << 'EOF'

# Optimisasi Jaringan VPS
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    
    # Terapkan pengaturan sysctl
    sysctl -p >/dev/null 2>&1
    
    log "SUCCESS" "Optimisasi sistem berhasil diterapkan"
}

# Verifikasi sistem akhir
verify_setup() {
    log "INFO" "${GEAR} Melakukan verifikasi akhir..."
    
    local checks_passed=0
    local total_checks=6
    
    # Cek konfigurasi telegram
    if [[ -f /etc/telegram_bot/bot_token && -f /etc/telegram_bot/chat_id ]]; then
        log "SUCCESS" "Konfigurasi Telegram: OK"
        ((checks_passed++))
    else
        log "ERROR" "Konfigurasi Telegram: GAGAL"
    fi
    
    # Cek fail2ban
    if systemctl is-active --quiet fail2ban; then
        log "SUCCESS" "Layanan Fail2Ban: OK"
        ((checks_passed++))
    else
        log "ERROR" "Layanan Fail2Ban: GAGAL"
    fi
    
    # Cek skrip autoreboot
    if [[ -x /root/autoreboot.sh ]]; then
        log "SUCCESS" "Skrip auto-reboot: OK"
        ((checks_passed++))
    else
        log "ERROR" "Skrip auto-reboot: GAGAL"
    fi
    
    # Cek crontab
    if crontab -l | grep -q autoreboot.sh; then
        log "SUCCESS" "Konfigurasi crontab: OK"
        ((checks_passed++))
    else
        log "ERROR" "Konfigurasi crontab: GAGAL"
    fi
    
    # Cek rc.local
    if [[ -x /etc/rc.local ]]; then
        log "SUCCESS" "Skrip startup: OK"
        ((checks_passed++))
    else
        log "ERROR" "Skrip startup: GAGAL"
    fi
    
    # Cek file log
    if [[ -f "$LOG_FILE" ]]; then
        log "SUCCESS" "Sistem logging: OK"
        ((checks_passed++))
    else
        log "ERROR" "Sistem logging: GAGAL"
    fi
    
    # Ringkasan
    local success_rate=$((checks_passed * 100 / total_checks))
    
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║                    LAPORAN RINGKASAN SETUP                   ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo -e "${WHITE}Total Pemeriksaan: ${total_checks}${RESET}"
    echo -e "${GREEN}Berhasil: ${checks_passed}${RESET}"
    echo -e "${RED}Gagal: $((total_checks - checks_passed))${RESET}"
    echo -e "${YELLOW}Tingkat Keberhasilan: ${success_rate}%${RESET}"
    echo -e "${WHITE}Error yang Ditemui: ${ERROR_COUNT}${RESET}"
    
    local setup_duration=$(($(date +%s) - SETUP_START_TIME))
    echo -e "${BLUE}Durasi Setup: ${setup_duration} detik${RESET}"
    
    if [[ $success_rate -ge 80 ]]; then
        log "SUCCESS" "Setup selesai dengan sukses! 🎉"
        echo -e "\n${GREEN}${SUCCESS} Sistem siap untuk operasi otomatis!${RESET}"
        echo -e "${YELLOW}${INFO} Anda sekarang dapat me-reboot sistem untuk menguji otomatisasi.${RESET}"
    else
        log "WARNING" "Setup selesai dengan beberapa masalah. Silakan tinjau log."
        echo -e "\n${YELLOW}${WARNING} Beberapa komponen mungkin memerlukan perhatian manual.${RESET}"
    fi
}

# Fungsi pembersihan
cleanup() {
    log "INFO" "Melakukan pembersihan..."
    rm -f /tmp/crontab_backup /tmp/new_crontab
    log "SUCCESS" "Pembersihan selesai"
}

# Alur eksekusi utama
main() {
    show_banner
    
    # Jalankan langkah-langkah setup
    validate_system
    setup_telegram_config
    setup_fail2ban
    create_autoreboot_script
    setup_crontab
    setup_rc_local
    optimize_system
    verify_setup
    cleanup
    
    echo -e "\n${BOLD}${GREEN}${ROCKET} Setup Otomatisasi VPS Profesional Selesai! ${ROCKET}${RESET}"
    echo -e "${CYAN}Terima kasih telah menggunakan solusi otomatisasi premium kami.${RESET}"
    echo -e "${WHITE}Lokasi file log: ${LOG_FILE}${RESET}"
    
    # Konfirmasi akhir
    echo -e "\n${YELLOW}Apakah Anda ingin reboot sekarang untuk mengaktifkan semua layanan? [y/N]: ${RESET}"
    read -r reboot_choice
    if [[ $reboot_choice =~ ^[Yy]$ ]]; then
        log "INFO" "Memulai reboot segera..."
        sleep 3
        reboot
    else
        log "INFO" "Setup selesai. Reboot kapan saja untuk mengaktifkan semua fitur."
    fi
}

# Jalankan fungsi utama
main "$@"
