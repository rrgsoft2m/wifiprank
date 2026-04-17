#!/bin/bash

# ============================================
# 🔥 WiFi Prank Portal - macOS Setup
# ============================================
# Bu skript macOS da captive portal o'rnatadi
# Foydalanuvchilar WiFi ga ulanganda hazil sahifa ochiladi

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
echo -e "${RED}║   ${BOLD}🔥 WiFi Prank Portal Setup 🔥${NC}${RED}       ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  Bu skript sudo bilan ishga tushirilishi kerak${NC}"
  echo -e "${CYAN}   Qayta ishga tushiring: ${BOLD}sudo bash setup.sh${NC}"
  exit 1
fi

echo -e "${CYAN}📋 Qo'llanma:${NC}"
echo ""
echo -e "   ${BOLD}1-qadam:${NC} macOS hotspot yoqing"
echo -e "   ${GREEN}→${NC} System Settings → General → Sharing → Internet Sharing"
echo -e "   ${GREEN}→${NC} 'Share your connection from' — Ethernet yoki USB/Thunderbolt"  
echo -e "   ${GREEN}→${NC} 'To computers using' — Wi-Fi ✅"
echo -e "   ${GREEN}→${NC} Wi-Fi Options → Nom: o'zingiz tanlang, Parol: o'rnating"
echo -e "   ${GREEN}→${NC} Internet Sharing — ON"
echo ""
echo -e "   ${BOLD}2-qadam:${NC} Terminal da bu skriptni ishga tushiring"
echo -e "   ${GREEN}→${NC} sudo bash setup.sh"
echo ""
echo -e "   ${BOLD}3-qadam:${NC} Do'stingiz WiFi ga ulanadi va qo'rqadi 😈"
echo ""

# Get the hotspot interface (usually bridge100 for Internet Sharing)
echo -e "${CYAN}🔍 Tarmoq interfeyslari tekshirilmoqda...${NC}"

# Find bridge interface (created by Internet Sharing)
BRIDGE_IF=$(ifconfig -l | tr ' ' '\n' | grep bridge | head -1)

if [ -z "$BRIDGE_IF" ]; then
    echo -e "${YELLOW}⚠️  Bridge interfeysi topilmadi.${NC}"
    echo -e "${YELLOW}   Internet Sharing yoqilganligiga ishonch hosil qiling.${NC}"
    echo -e "${YELLOW}   bridge100 ishlatiladi...${NC}"
    BRIDGE_IF="bridge100"
fi

echo -e "${GREEN}✅ Interfeys: ${BOLD}$BRIDGE_IF${NC}"

# Get the IP of bridge interface
BRIDGE_IP=$(ifconfig $BRIDGE_IF 2>/dev/null | grep 'inet ' | awk '{print $2}')

if [ -z "$BRIDGE_IP" ]; then
    BRIDGE_IP="192.168.2.1"
    echo -e "${YELLOW}⚠️  IP aniqlanmadi, standart ishlatiladi: $BRIDGE_IP${NC}"
else
    echo -e "${GREEN}✅ IP manzil: ${BOLD}$BRIDGE_IP${NC}"
fi

echo ""
echo -e "${CYAN}🚀 DNS va firewall sozlanmoqda...${NC}"

# Create a custom DNS resolver using pf (packet filter)
# Step 1: Configure pf to redirect DNS and HTTP traffic

PF_CONF="/tmp/prank_pf.conf"
cat > $PF_CONF << EOF
# WiFi Prank Portal - pf rules
# Redirect all HTTP traffic from bridge to our portal server

rdr on $BRIDGE_IF proto tcp from any to any port 80 -> $BRIDGE_IP port 3000
rdr on $BRIDGE_IF proto tcp from any to any port 443 -> $BRIDGE_IP port 3000
EOF

echo -e "${GREEN}✅ pf qoidalari yaratildi${NC}"

# Step 2: Setup DNS redirection using a simple DNS resolver
# Install dnsmasq if not present
if ! command -v dnsmasq &> /dev/null; then
    echo -e "${YELLOW}📦 dnsmasq o'rnatilmoqda (brew orqali)...${NC}"
    brew install dnsmasq
fi

# Configure dnsmasq
DNSMASQ_CONF="/tmp/prank_dnsmasq.conf"
cat > $DNSMASQ_CONF << EOF
# WiFi Prank - DNS Configuration
# Barcha DNS so'rovlarni portal serverga yo'naltirish
address=/#/$BRIDGE_IP
interface=$BRIDGE_IF
listen-address=$BRIDGE_IP
bind-interfaces
no-resolv
no-hosts
log-queries
EOF

echo -e "${GREEN}✅ DNS sozlamalari yaratildi${NC}"

# Step 3: Load pf rules
pfctl -f $PF_CONF -e 2>/dev/null
echo -e "${GREEN}✅ Firewall qoidalari yuklandi${NC}"

# Step 4: Kill existing dnsmasq and start new one
killall dnsmasq 2>/dev/null
dnsmasq --conf-file=$DNSMASQ_CONF &
DNSMASQ_PID=$!
echo -e "${GREEN}✅ DNS server ishga tushdi (PID: $DNSMASQ_PID)${NC}"

# Step 5: Start our Node.js server on port 3000
echo ""
echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
echo -e "${RED}║   ${GREEN}${BOLD}✅ Hammasi tayyor!${NC}${RED}                   ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📡 Portal manzili: ${BOLD}http://$BRIDGE_IP:3000${NC}"
echo -e "${CYAN}🌐 Do'stingiz WiFi ga ulanganda sahifa avtomatik ochiladi${NC}"
echo ""
echo -e "${YELLOW}⚡ Ctrl+C bosib to'xtatishingiz mumkin${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${CYAN}🧹 Tozalash...${NC}"
    killall dnsmasq 2>/dev/null
    pfctl -d 2>/dev/null
    rm -f $PF_CONF $DNSMASQ_CONF 2>/dev/null
    echo -e "${GREEN}✅ Hammasi tozalandi. WiFi normal ishlaydi.${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start node server on port 3000 (no root needed for 3000)
cd "$(dirname "$0")"
PORT=3000 node server.js
