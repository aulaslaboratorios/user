#!/bin/bash
set -euo pipefail

# ============================================
# macOS Recovery - Configurar IP por LAB
# - Docente: LAB -> LAB-SERV (IP fija por lab)
# - Alumno : LAB + POS -> LAB-XX (IP por rango)
# Basado en tus rangos y reglas
# ============================================

MASK="255.255.254.0"
GATEWAY="10.142.114.1"
DNS1="10.147.8.12"
DNS2="10.147.8.101"

# ---------- Utilidades IP ----------
ip2int() {
  local IFS='.'
  read -r -a o <<<"$1"
  echo "$(( (o[0] << 24) + (o[1] << 16) + (o[2] << 8) + o[3] ))"
}

int2ip() {
  local ip=$1
  echo "$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$(( ip & 255 ))"
}

# ---------- Rango por LAB (alumnos) ----------
lab_range() {
  local lab="$1"
  case "$lab" in
    SB409) echo "10.142.114.195 10.142.114.214" ;;
    SB410) echo "10.142.114.6   10.142.114.25"  ;;
    SB502) echo "10.142.116.72  10.142.116.78"  ;;
    SB509) echo "10.142.114.27  10.142.114.46"  ;;
    SB510) echo "10.142.114.48  10.142.114.67"  ;;
    SB603) echo "10.142.114.69  10.142.114.88"  ;;
    SB703) echo "10.142.115.7   10.142.115.26"  ;;
    SB704) echo "10.142.114.90  10.142.114.109" ;;
    SB707) echo "10.142.114.111 10.142.114.130" ;;
    SB708) echo "10.142.114.132 10.142.114.151" ;;
    SB801) echo "10.142.114.153 10.142.114.172" ;;
    SB802) echo "10.142.114.174 10.142.114.193" ;;
    *) return 1 ;;
  esac
}

# ---------- IP fija docente (LAB-SERV) ----------
lab_serv_ip() {
  local lab="$1"
  case "$lab" in
    SB409) echo "10.142.114.194" ;;
    SB410) echo "10.142.114.5"   ;;
    SB502) echo "10.142.116.71"  ;;
    SB509) echo "10.142.114.26"  ;;
    SB510) echo "10.142.114.47"  ;;
    SB603) echo "10.142.114.68"  ;;
    SB703) echo "10.142.115.6"   ;;
    SB704) echo "10.142.114.89"  ;;
    SB707) echo "10.142.114.110" ;;
    SB708) echo "10.142.114.131" ;;  
    SB801) echo "10.142.114.152" ;;
    SB802) echo "10.142.114.173" ;;
    *) return 1 ;;
  esac
}

# ---------- Calcular IP alumno por rango ----------
calc_student_ip() {
  local lab="$1"
  local pos="$2"

  local r
  if ! r="$(lab_range "$lab")"; then
    echo "Laboratorio no válido: $lab" >&2
    return 1
  fi

  local start end
  read -r start end <<<"$r"

  if ! [[ "$pos" =~ ^[0-9]+$ ]]; then
    echo "Posición inválida: $pos" >&2
    return 1
  fi
  if (( pos < 1 )); then
    echo "La posición debe ser >= 1" >&2
    return 1
  fi

  local start_i end_i total selected_i
  start_i="$(ip2int "$start")"
  end_i="$(ip2int "$end")"
  total=$((end_i - start_i + 1))

  if (( pos > total )); then
    echo "Posición fuera de rango para $lab. Máx: $total" >&2
    return 1
  fi

  selected_i=$((start_i + pos - 1))
  int2ip "$selected_i"
}

# ---------- Seleccionar servicio de red en Recovery ----------
choose_service() {
  if ! command -v networksetup >/dev/null 2>&1; then
    echo ""
    echo "❌ No existe 'networksetup' en este entorno Recovery."
    echo "   En ese caso habría que usar ifconfig/route (otro script)."
    exit 1
  fi

  local services
  services="$(networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | sed 's/^\*//')"

  # Preferencias típicas
  local preferred=("Ethernet" "USB 10/100/1000 LAN" "USB 10/100 LAN" "Thunderbolt Ethernet" "Wi-Fi")
  for p in "${preferred[@]}"; do
    if echo "$services" | grep -Fxq "$p"; then
      echo "$p"
      return 0
    fi
  done

  # Si no encuentra, usa el primero
  echo "$services" | head -n 1
}

# ---------- Aplicar config ----------
apply_config() {
  local service="$1"
  local host="$2"
  local ip="$3"

  echo ""
  echo "Servicio : $service"
  echo "Hostname : $host"
  echo "IP       : $ip"
  echo "Mask     : $MASK"
  echo "Gateway  : $GATEWAY"
  echo "DNS      : $DNS1, $DNS2"
  echo ""

  # Hostname
  scutil --set ComputerName "$host" 2>/dev/null || true
  scutil --set LocalHostName "$host" 2>/dev/null || true
  scutil --set HostName "$host" 2>/dev/null || true

  # Red
  networksetup -setmanual "$service" "$ip" "$MASK" "$GATEWAY"
  networksetup -setdnsservers "$service" "$DNS1" "$DNS2" || true

  echo "✅ Configuración aplicada."
  echo ""
  networksetup -getinfo "$service" || true
}

# ---------- UI ----------
echo "============================================"
echo " Configurar red (macOS Recovery)"
echo "============================================"
echo ""
echo "Tipo de usuario:"
echo "1) Alumno (LAB + POS)"
echo "2) Docente (LAB -> LAB-SERV automático)"
read -rp "Elige 1 o 2: " choice

read -rp "LAB (SB409, SB410, SB502, SB509, SB510, SB603, SB703, SB704, SB707, SB708, SB801, SB802): " lab
lab="$(echo "$lab" | tr '[:lower:]' '[:upper:]' | tr -d ' ')"

service="$(choose_service)"
if [[ -z "$service" ]]; then
  echo "❌ No se pudo detectar servicio de red."
  exit 1
fi

case "$choice" in
  1)
    read -rp "Posición (1..N): " pos
    ip="$(calc_student_ip "$lab" "$pos")"

    # Hostname con 2 dígitos (01, 02, ... 18)
    pos2="$(printf "%02d" "$pos")"
    host="${lab}-${pos2}"

    apply_config "$service" "$host" "$ip"
    ;;
  2)
    ip="$(lab_serv_ip "$lab")"
    host="${lab}-SERV"
    apply_config "$service" "$host" "$ip"
    ;;
  *)
    echo "❌ Opción inválida."
    exit 1
    ;;
esac

echo ""
echo "MACs detectadas:"
ifconfig -a | awk '
  /^[a-z]/ {iface=$1; gsub(":","",iface)}
  /ether / {print " - " iface " -> " $2}
' || true
echo ""
echo ""