#!/bin/bash
# macOS Recovery - Config IP por LAB (Alumno/Docente)
# Método: ifconfig + route (Recovery-friendly)
# Datos/IPs: tomados del script que pegaste (SB408..SB802)

MASK="255.255.254.0"
GATEWAY="10.142.114.1"
DNS1="10.147.8.12"
DNS2="10.147.8.101"

# ---------- Helpers IP ----------
ip2int() {
  local IFS='.'
  local a b c d
  read -r a b c d <<< "$1"
  echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

int2ip() {
  local ip="$1"
  echo "$(( (ip>>24)&255 )).$(( (ip>>16)&255 )).$(( (ip>>8)&255 )).$(( ip&255 ))"
}

detect_iface() {
  if ifconfig en0 >/dev/null 2>&1; then
    echo "en0"
    return
  fi
  # primera enX disponible
  local iface
  iface="$(ifconfig -l 2>/dev/null | tr " " "\n" | grep -E '^en[0-9]+$' | head -n 1)"
  if [ -n "${iface:-}" ]; then
    echo "$iface"
  else
    echo "en0"
  fi
}

# ---------- Tablas (según tu data) ----------
# Rango ALUMNOS por LAB
lab_range() {
  case "$1" in
    SB408) echo "10.142.114.195 10.142.114.214" ;;
    SB409) echo "10.142.114.6   10.142.114.25"  ;;
    SB502) echo "10.142.116.72  10.142.116.78"  ;;
    SB509) echo "10.142.114.27  10.142.114.46"  ;;
    SB510) echo "10.142.114.48  10.142.114.67"  ;;
    SB603) echo "10.142.114.69  10.142.114.88"  ;;
    SB703) echo "10.142.115.8   10.142.115.27"  ;;  # ✅ tu nuevo rango
    SB704) echo "10.142.114.90  10.142.114.109" ;;
    SB707) echo "10.142.114.111 10.142.114.130" ;;
    SB708) echo "10.142.114.132 10.142.114.151" ;;
    SB801) echo "10.142.114.153 10.142.114.172" ;;
    SB802) echo "10.142.114.174 10.142.114.193" ;;
    *) echo "" ;;
  esac
}

# IP DOCENTE (SERV) por LAB
lab_serv_ip() {
  case "$1" in
    SB408) echo "10.142.114.194" ;;
    SB409) echo "10.142.114.5"   ;;
    SB502) echo "10.142.116.71"  ;;
    SB509) echo "10.142.114.26"  ;;
    SB510) echo "10.142.114.47"  ;;
    SB603) echo "10.142.114.68"  ;;
    SB703) echo "10.142.115.7"   ;;  # ✅ tu nuevo SERV
    SB704) echo "10.142.114.89"  ;;
    SB707) echo "10.142.114.110" ;;
    SB708) echo "10.142.114.131" ;;
    SB801) echo "10.142.114.152" ;;
    SB802) echo "10.142.114.173" ;;
    *) echo "" ;;
  esac
}

# Excepciones (posiciones con IP fija) según tu script
fixed_ip_for_pos() {
  local lab="$1"
  local pos="$2"

  case "$pos" in
    8)
      case "$lab" in
        SB408) echo "10.142.114.202" ;;
        SB409) echo "10.142.114.13" ;;
        SB509) echo "10.142.114.34" ;;
        SB510) echo "10.142.114.55" ;;
        SB603) echo "10.142.114.76" ;;
        SB703) echo "10.142.115.15" ;;
        SB704) echo "10.142.114.97" ;;
        SB707) echo "10.142.114.118" ;;
        SB708) echo "10.142.114.139" ;;
        SB801) echo "10.142.114.160" ;;
        SB802) echo "10.142.114.181" ;;
        *) echo "" ;;
      esac
      ;;
    9)
      case "$lab" in
        SB408) echo "10.142.114.203" ;;
        SB409) echo "10.142.114.14" ;;
        SB509) echo "10.142.114.35" ;;
        SB510) echo "10.142.114.56" ;;
        SB603) echo "10.142.114.77" ;;
        SB703) echo "10.142.115.16" ;;
        SB704) echo "10.142.114.98" ;;
        SB707) echo "10.142.114.119" ;;
        SB708) echo "10.142.114.140" ;;
        SB801) echo "10.142.114.161" ;;
        SB802) echo "10.142.114.182" ;;
        *) echo "" ;;
      esac
      ;;
    18)
      case "$lab" in
        SB408) echo "10.142.114.212" ;;
        SB409) echo "10.142.114.23" ;;
        SB509) echo "10.142.114.44" ;;
        SB510) echo "10.142.114.65" ;;
        SB603) echo "10.142.114.86" ;;
        SB703) echo "10.142.115.25" ;;
        SB704) echo "10.142.114.107" ;;
        SB707) echo "10.142.114.128" ;;
        SB708) echo "10.142.114.149" ;;
        SB801) echo "10.142.114.170" ;;
        SB802) echo "10.142.114.191" ;;
        *) echo "" ;;
      esac
      ;;
    19)
      case "$lab" in
        SB408) echo "10.142.114.213" ;;
        SB409) echo "10.142.114.24" ;;
        SB509) echo "10.142.114.45" ;;
        SB510) echo "10.142.114.66" ;;
        SB603) echo "10.142.114.87" ;;
        SB703) echo "10.142.115.26" ;;
        SB704) echo "10.142.114.108" ;;
        SB707) echo "10.142.114.129" ;;
        SB708) echo "10.142.114.150" ;;
        SB801) echo "10.142.114.171" ;;
        SB802) echo "10.142.114.192" ;;
        *) echo "" ;;
      esac
      ;;
    *)
      echo ""
      ;;
  esac
}

calc_student_ip_by_range() {
  local lab="$1"
  local pos="$2"

  [[ "$pos" =~ ^[0-9]+$ ]] || { echo "INVALID"; return; }
  (( pos >= 1 )) || { echo "INVALID"; return; }

  local range start end
  range="$(lab_range "$lab")"
  start="${range%% *}"
  end="${range#* }"

  [ -n "$start" ] && [ -n "$end" ] || { echo "INVALID"; return; }

  local si ei total
  si="$(ip2int "$start")"
  ei="$(ip2int "$end")"
  total=$((ei - si + 1))

  (( pos <= total )) || { echo "OUT"; return; }

  int2ip $((si + pos - 1))
}

apply_config() {
  local iface="$1"
  local ip="$2"

  echo ""
  echo "Aplicando..."
  echo "IFACE: $iface"
  echo "IP   : $ip"
  echo "MASK : $MASK"
  echo "GW   : $GATEWAY"
  echo ""

  ifconfig "$iface" "$ip" netmask "$MASK" up
  route delete default >/dev/null 2>&1 || true
  route add default "$GATEWAY" >/dev/null 2>&1 || true

  # DNS best-effort (en Recovery puede no persistir, pero ayuda en la sesión)
  printf "nameserver %s\nnameserver %s\n" "$DNS1" "$DNS2" > /etc/resolv.conf 2>/dev/null || true

  echo "✅ Listo."
  echo "---- ifconfig (resumen) ----"
  ifconfig "$iface" | head -n 8
  echo ""
  echo "---- rutas (resumen) ----"
  netstat -rn | head -n 15
  echo ""
}

# ---------- Menús (prompts visibles) ----------
echo ""
echo "==================================="
echo "  UPC Recovery - Config Red por LAB"
echo "==================================="
echo ""

echo "Seleccione tipo de usuario:"
echo "1) Alumno (LAB + Posición)"
echo "2) Docente (LAB -> SERV)"
echo ""
printf "Ingrese 1 o 2 y Enter:\n> "
read -r TIPO

echo ""
echo "Seleccione el laboratorio:"
echo " 1) SB408"
echo " 2) SB409"
echo " 3) SB502"
echo " 4) SB509"
echo " 5) SB510"
echo " 6) SB603"
echo " 7) SB703"
echo " 8) SB704"
echo " 9) SB707"
echo "10) SB708"
echo "11) SB801"
echo "12) SB802"
echo ""
printf "Ingrese el número de LAB y Enter:\n> "
read -r LABN

case "$LABN" in
  1) LAB="SB408" ;;
  2) LAB="SB409" ;;
  3) LAB="SB502" ;;
  4) LAB="SB509" ;;
  5) LAB="SB510" ;;
  6) LAB="SB603" ;;
  7) LAB="SB703" ;;
  8) LAB="SB704" ;;
  9) LAB="SB707" ;;
  10) LAB="SB708" ;;
  11) LAB="SB801" ;;
  12) LAB="SB802" ;;
  *) echo "❌ LAB inválido"; exit 1 ;;
esac

IFACE="$(detect_iface)"

if [ "$TIPO" = "1" ]; then
  echo ""
  printf "Ingrese POSICIÓN (ej 8, 9, 18, 19 o cualquier número válido) y Enter:\n> "
  read -r POS

  # 1) Si es una posición con IP fija, úsala
  IP_FIXED="$(fixed_ip_for_pos "$LAB" "$POS")"
  if [ -n "$IP_FIXED" ]; then
    IP="$IP_FIXED"
  else
    # 2) Si no, calcula por rango
    IP="$(calc_student_ip_by_range "$LAB" "$POS")"
    [ "$IP" != "INVALID" ] || { echo "❌ POS inválida"; exit 1; }
    [ "$IP" != "OUT" ] || { echo "❌ POS fuera de rango"; exit 1; }
  fi

elif [ "$TIPO" = "2" ]; then
  IP="$(lab_serv_ip "$LAB")"
  [ -n "$IP" ] || { echo "❌ No hay IP SERV para $LAB"; exit 1; }
else
  echo "❌ Tipo inválido"
  exit 1
fi

apply_config "$IFACE" "$IP"
