#!/usr/bin/env bash
# Sin instalaciones ni elevacion automatica de privilegios.
set -u

usage() { printf 'Uso: bash %s [--output informe.txt]\n' "$0"; }
output=''
case "$#" in
    0) ;;
    1) if [[ "$1" == '--help' || "$1" == '-h' ]]; then usage; exit 0; else usage >&2; exit 1; fi ;;
    2) if [[ "$1" == '--output' && -n "$2" ]]; then output=$2; else usage >&2; exit 1; fi ;;
    *) usage >&2; exit 1 ;;
esac
if [[ $(uname -s) != Linux ]]; then
    printf 'Este script requiere Linux.\n' >&2
    exit 1
fi

section() { printf '\n=== %s ===\n' "$1"; }
run() {
    if command -v "$1" >/dev/null 2>&1; then
        "$@" 2>&1 || printf 'No disponible: fallo la consulta o faltan permisos.\n'
    else
        printf 'No disponible: herramienta %s ausente.\n' "$1"
    fi
}
read_value() {
    local value
    if [[ -r "$2" ]] && value=$(cat "$2" 2>/dev/null); then
        printf '%s: %s\n' "$1" "${value:-No disponible}"
    else
        printf '%s: No disponible (archivo ausente o sin permisos).\n' "$1"
    fi
}

collect() {
    printf 'INFORME DE HARDWARE - LINUX\n'
    date '+Fecha: %Y-%m-%d %H:%M:%S %z'
    section 'Sistema operativo y arquitectura'
    run cat /etc/os-release
    run uname -srmo

    section 'Equipo, tarjeta madre y BIOS / firmware'
    local field
    for field in sys_vendor product_name product_version product_serial board_vendor board_name board_version board_serial bios_vendor bios_version bios_date; do
        read_value "$field" "/sys/class/dmi/id/$field"
    done
    if [[ -r /proc/device-tree/model ]]; then
        printf 'Modelo (device tree): '
        tr -d '\000' < /proc/device-tree/model
        printf '\n'
    fi

    section 'Procesador'
    if command -v lscpu >/dev/null 2>&1; then run lscpu; else run cat /proc/cpuinfo; fi
    section 'Memoria total y disponible (kB segun el kernel)'
    run cat /proc/meminfo
    section 'Modulos de memoria (puede requerir root y dmidecode)'
    run dmidecode --type memory

    section 'Discos, particiones y puntos de montaje (SIZE en bytes; ROTA: 1 rotacional, 0 no rotacional)'
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -b -o NAME,TYPE,SIZE,ROTA,TRAN,MODEL,SERIAL,FSTYPE,MOUNTPOINT 2>&1 || run lsblk
    else
        printf 'No disponible: herramienta lsblk ausente.\n'
        run cat /proc/partitions
    fi
    section 'Espacio de sistemas de archivos montados'
    run df -hP

    section 'Graficos, audio, red y otros dispositivos PCI con controladores'
    run lspci -nnk
    section 'Graficos: identificadores y memoria dedicada si el controlador la expone (bytes)'
    local device found=0
    for device in /sys/class/drm/card[0-9]*; do
        [[ $(basename "$device") =~ ^card[0-9]+$ && -d "$device/device" ]] || continue
        found=1
        printf '\n%s\n' "$(basename "$device")"
        for field in vendor device mem_info_vram_total; do
            read_value "$field" "$device/device/$field"
        done
    done
    [[ "$found" == 1 ]] || printf 'No disponible: no hay dispositivos DRM expuestos.\n'

    section 'Interfaces de red (incluye virtuales)'
    run ip -brief link
    for device in /sys/class/net/*; do
        [[ -d "$device" ]] || continue
        printf '\n%s\n' "$(basename "$device")"
        read_value 'Direccion MAC' "$device/address"
        read_value 'Estado' "$device/operstate"
        read_value 'Velocidad (Mbps)' "$device/speed"
    done
    section 'USB'
    run lsusb
    section 'Baterias'
    found=0
    for device in /sys/class/power_supply/*; do
        [[ -r "$device/type" ]] || continue
        [[ $(cat "$device/type") == Battery ]] || continue
        found=1
        for field in manufacturer model_name serial_number status capacity cycle_count energy_full_design energy_full charge_full_design charge_full voltage_now; do
            read_value "$field" "$device/$field"
        done
    done
    [[ "$found" == 1 ]] || printf 'No disponible: no se detectaron baterias.\n'
    printf '\nUnidades de bateria: capacity en %%; energy_* en uWh; charge_* en uAh; voltage_now en uV.\n'
}

report=$(collect)
printf '%s\n' "$report"
if [[ -n "$output" ]]; then
    if ! printf '%s\n' "$report" > "$output"; then
        printf 'No se pudo guardar el informe: %s\n' "$output" >&2
        exit 1
    fi
fi
