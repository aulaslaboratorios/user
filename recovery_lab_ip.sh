#!/bin/bash

MASK="255.255.254.0"
GATEWAY="10.142.114.1"

ip2int() {
  IFS='.' read -r a b c d <<EOF
$1
EOF
  echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

int2ip() {
  ip=$1
  echo "$(( (ip>>24)&255 )).$(( (ip>>16)&255 )).$(( (ip>>8)&255 )).$(( ip&255 ))"
}

detect_iface() {
  if ifconfig en0 >/dev/null 2>&1; then
    echo "en0"
    return
  fi
  iface="$(ifconfig -l 2>/dev/null | tr " " "\n" | grep -E "^en[0-9]+$" | head -n 1)"
  if [ -n "$iface" ]; then
    echo "$iface"
  else
    echo "en0"
  fi
}

choose_tipo() {
  echo "==================================="
  echo " Configurar Red - macOS Recovery"
  echo "==================================="
  echo ""
  echo "Seleccione tipo de usuario:"
  echo "1) Alumno"
  echo "2) Docente"
  echo ""
  printf "Opción (1/2): "
  read tipo
  echo "$tipo"
}

choose_lab() {
  echo ""
  echo "Seleccione el laboratorio:"
  echo "1) SB409"
  echo "2) SB410"
  echo "3) SB502"
  echo "4) SB509"
  echo "5) SB510"
  echo "6) SB603"
  echo "7) SB703"
  echo "8) SB704"
  echo "9) SB707"
  echo "10) SB708"
  echo "11) SB801"
  echo "12) SB802"
  echo ""
  printf "Número de laboratorio: "
  read labn

  case "$labn" in
    1)  echo "SB409" ;;
    2)  echo "SB410" ;;
    3)  echo "SB502" ;;
    4)  echo "SB509" ;;
    5)  echo "SB510" ;;
    6)  echo "SB603" ;;
    7)  echo "SB703" ;;
    8)  echo "SB704" ;;
    9)  echo "SB707" ;;
    10) echo "SB708" ;;
    11) echo "SB801" ;;
    12) echo "SB802" ;;
    *)  echo "INVALID" ;;
  esac
}

lab_range() {
  lab="$1"
  case "$lab" in
    SB409) echo "10.142.114.195 10.142.114.214" ;;
    SB410) echo "10.142.114.6 10.142.114.25" ;;
    SB502) echo "10.142.116.72 10.142.116.78" ;;
    SB509) echo "10.142.114.27 10.142.114.46" ;;
    SB510) echo "10.142.114.48 10.142.114.67" ;;
    SB603) echo "10.142.114.69 10.142.114.88" ;;
    SB703) echo "10.142.115.7 10.142.115.26" ;;
    SB704) echo "10.142.114.90 10.142.114.109" ;;
    SB707) echo "10.142.114.111 10.142.114.130" ;;
    SB708) echo "10.142.114.132 10.142.114.151" ;;
    SB801) echo "10.142.114.153 10.142.114.172" ;;
    SB802) echo "10.142.114.174 10.142.114.193" ;;
    *) echo "" ;;
  esac
}

lab_serv_ip() {
  lab="$1"
  case "$lab" in
    SB409) echo "10.142.114.194" ;;
    SB410) echo "10.142.114.5" ;;
    SB502) echo "10.142.116.71" ;;
    SB509) echo "10.142.114.26" ;;
    SB510) echo "10.142.114.47" ;;
    SB603) echo "10.142.114.68" ;;
    SB703) echo "10.142.115.6" ;;
    SB704) echo "10.142.114.89" ;;
    SB707) echo "10.142.114.110" ;;
    SB708) echo "10.142.114.131" ;;  # corregido
    SB801) echo "10.142.114.152" ;;
    SB802) echo "10.142.114.173" ;;
    *) echo "" ;;
  esac
}

calc_student_ip() {
  lab="$1"
  pos="$2"

  if ! echo "$pos" | grep -Eq '^[0-9]+$'; then
    echo "INVALID"
    return
  fi
  if [ "$pos" -lt 1 ]; then
    echo "INVALID"
    return
  fi

  range="$(lab_range "$lab")"
  start="$(echo "$range" | awk "{print \$1}")"
  end="$(echo "$range" | awk "{print \$2}")"

  if [ -z "$start" ] || [ -z "$end" ]; then
    echo "INVALID"
    return
  fi

  si="$(ip2int "$start")"
  ei="$(ip2int "$end")"
  total=$((ei - si + 1))

  if [ "$pos" -gt "$total" ]; then
    echo "OUT"
    return
  fi

  sel=$((si + pos - 1))
  int2ip "$sel"
}

apply_config() {
  iface="$1"
  ip="$2"

  echo ""
  echo "Aplicando..."
  echo "IFACE : $iface"
  echo "IP    : $ip"
  echo "MASK  : $MASK"
  echo "GW    : $GATEWAY"
  echo ""

  ifconfig "$iface" "$ip" netmask "$MASK" up
  route delete default >/dev/null 2>&1
  route add default "$GATEWAY" >/dev/null 2>&1

  echo "---- Verificación ----"
  ifconfig "$iface" | head -n 8
  echo ""
  netstat -rn | head -n 15
  echo ""
  echo "✅ Listo."
}

# ================= MAIN =================
tipo="$(choose_tipo)"
lab="$(choose_lab)"

if [ "$lab" = "INVALID" ]; then
  echo "❌ Laboratorio inválido."
  exit 1
fi

iface="$(detect_iface)"

if [ "$tipo" = "1" ]; then
  echo ""
  printf "Posición del alumno: "
  read pos
  ip="$(calc_student_ip "$lab" "$pos")"

  if [ "$ip" = "INVALID" ]; then
    echo "❌ Posición inválida o LAB inválido."
    exit 1
  fi
  if [ "$ip" = "OUT" ]; then
    echo "❌ Posición fuera del rango para $lab."
    exit 1
  fi

  apply_config "$iface" "$ip"

elif [ "$tipo" = "2" ]; then
  ip="$(lab_serv_ip "$lab")"
  if [ -z "$ip" ]; then
    echo "❌ No hay IP SERV para $lab."
    exit 1
  fi

  apply_config "$iface" "$ip"
else
  echo "❌ Opción inválida."
  exit 1
fi
