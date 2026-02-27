#!/bin/bash
set -euo pipefail

# ============================
# CONFIG GLOBAL
# ============================
MASK="255.255.254.0"
GATEWAY="10.142.114.1"

LABS=(SB409 SB410 SB502 SB509 SB510 SB603 SB703 SB704 SB707 SB708 SB801 SB802)

# ============================
# FUNCIONES IP
# ============================
ip2int() {
  local IFS='.'
  read -r a b c d <<<"$1"
  echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

int2ip() {
  local ip=$1
  echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))"
}

# ============================
# RANGO ALUMNOS
# ============================
lab_range() {
  case "$1" in
    SB409) echo "10.142.114.195 10.142.114.214" ;;
    SB410) echo "10.142.114.6   10.142.114.25" ;;
    SB502) echo "10.142.116.72  10.142.116.78" ;;
    SB509) echo "10.142.114.27  10.142.114.46" ;;
    SB510) echo "10.142.114.48  10.142.114.67" ;;
    SB603) echo "10.142.114.69  10.142.114.88" ;;
    SB703) echo "10.142.115.7   10.142.115.26" ;;
    SB704) echo "10.142.114.90  10.142.114.109" ;;
    SB707) echo "10.142.114.111 10.142.114.130" ;;
    SB708) echo "10.142.114.132 10.142.114.151" ;;
    SB801) echo "10.142.114.153 10.142.114.172" ;;
    SB802) echo "10.142.114.174 10.142.114.193" ;;
    *) echo ""; return 1 ;;
  esac
}

# ============================
# IP DOCENTE (SERV)
# ============================
lab_serv_ip() {
  case "$1" in
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
    *) echo ""; return 1 ;;
  esac
}

# ============================
# SELECCIÓN LAB POR NÚMERO
# ============================
choose_lab() {
  echo ""
  echo "Seleccione el laboratorio:"
  local i=1
  for lab in "${LABS[@]}"; do
    echo "$i) $lab"
    i=$((i+1))
  done

  read -rp "Número de laboratorio: " n

  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "❌ Opción inválida"
    exit 1
  fi

  if (( n < 1 || n > ${#LABS[@]} )); then
    echo "❌ Número fuera de rango"
    exit 1
  fi

  echo "${LABS[$((n-1))]}"
}

# ============================
# CALCULAR IP ALUMNO
# ============================
calc_student_ip() {
  local lab="$1"
  local pos="$2"

  read -r start end <<<"$(lab_range "$lab")"

  if [[ -z "${start:-}" || -z "${end:-}" ]]; then
    echo "❌ LAB inválido"
    exit 1
  fi

  if ! [[ "$pos" =~ ^[0-9]+$ ]]; then
    echo "❌ Posición inválida"
    exit 1
  fi

  if (( pos < 1 )); then
    echo "❌ Posición debe ser >= 1"
    exit 1
  fi

  si=$(ip2int "$start")
  ei=$(ip2int "$end")
  total=$((ei - si + 1))

  if (( pos > total )); then
    echo "❌ Posición fuera de rango (máx $total)"
    exit 1
  fi

  int2ip $((si + pos - 1))
}

# ============================
# DETECTAR INTERFAZ
# ============================
detect_iface() {
  if ifconfig en0 >/dev/null 2>&1; then
    echo "en0"
    return
  fi

  iface=$(ifconfig -l | tr " " "\n" | grep "^en" | head -n1)
  echo "${iface:-en0}"
}

# ============================
# APLICAR CONFIGURACIÓN
# ============================
apply_config() {
  local iface="$1"
  local ip="$2"

  echo ""
  echo "Aplicando configuración..."
  echo "Interfaz: $iface"
  echo "IP: $ip"
  echo "Mask: $MASK"
  echo "Gateway: $GATEWAY"
  echo ""

  ifconfig "$iface" "$ip" netmask "$MASK" up
  route delete default >/dev/null 2>&1 || true
  route add default "$GATEWAY"

  echo ""
  echo "---- Verificación ----"
  ifconfig "$iface" | head -n 5
  echo ""
  netstat -rn | head -n 10
  echo ""
  echo "✅ Configuración aplicada correctamente."
}

# ============================
# MAIN
# ============================
echo "==================================="
echo " Configurar Red - macOS Recovery"
echo "==================================="
echo ""
echo "1) Alumno"
echo "2) Docente"
read -rp "Seleccione tipo: " tipo

lab=$(choose_lab)
iface=$(detect_iface)

case "$tipo" in
  1)
    read -rp "Posición del alumno: " pos
    ip=$(calc_student_ip "$lab" "$pos")
    ;;
  2)
    ip=$(lab_serv_ip "$lab")
    if [[ -z "${ip:-}" ]]; then
      echo "❌ LAB inválido"
      exit 1
    fi
    ;;
  *)
    echo "❌ Opción inválida"
    exit 1
    ;;
esac

apply_config "$iface" "$ip"
