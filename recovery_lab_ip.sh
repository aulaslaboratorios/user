#!/bin/bash
# Recovery-friendly LAB IP chooser (ifconfig + route)
# Gateway fijo: 10.142.114.1
# Máscara: 255.255.254.0
set -u

MASK="255.255.254.0"
GATEWAY="10.142.114.1"

echo ""
echo "==================================="
echo "  UPC Recovery - Config Red por LAB"
echo "==================================="
echo ""

# ---------- IP helpers ----------
ip2int() { IFS='.' read -r a b c d <<<"$1"; echo $(( (a<<24)+(b<<16)+(c<<8)+d )); }
int2ip() { local ip=$1; echo "$((ip>>24&255)).$((ip>>16&255)).$((ip>>8&255)).$((ip&255))"; }

# ---------- Detect iface ----------
detect_iface() {
  if ifconfig en0 >/dev/null 2>&1; then
    echo "en0"; return
  fi
  local iface
  iface="$(ifconfig -l 2>/dev/null | tr " " "\n" | grep -E "^en[0-9]+$" | head -n 1)"
  if [ -n "${iface:-}" ]; then echo "$iface"; else echo "en0"; fi
}

# ---------- Menú tipo ----------
echo "Seleccione tipo de usuario:"
echo "1) Alumno  (LAB + Posición)"
echo "2) Docente (LAB -> SERV)"
printf "Opción (1/2): "
IFS= read -r TIPO || true
echo ""

# Validación tipo
if [ "${TIPO:-}" != "1" ] && [ "${TIPO:-}" != "2" ]; then
  echo "❌ Opción inválida: ${TIPO:-<vacio>}"
  exit 1
fi

# ---------- Menú LAB ----------
echo "Seleccione el laboratorio:"
echo " 1) SB409"
echo " 2) SB410"
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
printf "Número de laboratorio: "
IFS= read -r LABN || true
echo ""

case "${LABN:-}" in
  1) LAB="SB409" ;;
  2) LAB="SB410" ;;
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
  *) echo "❌ Laboratorio inválido: ${LABN:-<vacio>}"; exit 1 ;;
esac

# ---------- Rango alumnos ----------
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
    *) echo "" ;;
  esac
}

# ---------- IP SERV docentes ----------
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
    SB708) echo "10.142.114.131" ;;  # ✅ corregido
    SB801) echo "10.142.114.152" ;;
    SB802) echo "10.142.114.173" ;;
    *) echo "" ;;
  esac
}

# ---------- Calcular IP ----------
if [ "$TIPO" = "1" ]; then
  printf "Ingrese posición (1..N): "
  IFS= read -r POS || true
  echo ""

  if ! echo "${POS:-}" | grep -Eq "^[0-9]+$"; then
    echo "❌ Posición inválida: ${POS:-<vacio>}"
    exit 1
  fi
  if [ "$POS" -lt 1 ]; then
    echo "❌ Posición debe ser >= 1"
    exit 1
  fi

  RANGE="$(lab_range "$LAB")"
  START="$(echo "$RANGE" | awk "{print \$1}")"
  END="$(echo "$RANGE" | awk "{print \$2}")"
  if [ -z "${START:-}" ] || [ -z "${END:-}" ]; then
    echo "❌ No hay rango definido para $LAB"
    exit 1
  fi

  SI="$(ip2int "$START")"
  EI="$(ip2int "$END")"
  TOTAL=$((EI - SI + 1))

  if [ "$POS" -gt "$TOTAL" ]; then
    echo "❌ Posición fuera de rango para $LAB (máx $TOTAL)"
    exit 1
  fi

  IP="$(int2ip $((SI + POS - 1)))"
else
  IP="$(lab_serv_ip "$LAB")"
  if [ -z "${IP:-}" ]; then
    echo "❌ No hay IP SERV para $LAB"
    exit 1
  fi
fi

IFACE="$(detect_iface)"

echo "-----------------------------------"
echo "Tipo   : $([ "$TIPO" = "1" ] && echo Alumno || echo Docente)"
echo "LAB    : $LAB"
echo "IFACE  : $IFACE"
echo "IP     : $IP"
echo "MASK   : $MASK"
echo "GW     : $GATEWAY"
echo "-----------------------------------"
echo ""

# ---------- Aplicar (tu estructura ganadora) ----------
ifconfig "$IFACE" "$IP" netmask "$MASK" up
route delete default >/dev/null 2>&1 || true
route add default "$GATEWAY" >/dev/null 2>&1 || true

echo "✅ Aplicado."
echo ""
echo "---- ifconfig (resumen) ----"
ifconfig "$IFACE" | head -n 8
echo ""
echo "---- rutas (resumen) ----"
netstat -rn | head -n 15
echo ""
