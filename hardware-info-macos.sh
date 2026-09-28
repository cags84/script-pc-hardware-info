#!/usr/bin/env bash
# Compatible con el Bash incluido en macOS, Intel y Apple Silicon.
set -u

usage() { printf 'Uso: bash %s [--output informe.txt]\n' "$0"; }
output=''
case "$#" in
    0) ;;
    1) if [[ "$1" == '--help' || "$1" == '-h' ]]; then usage; exit 0; else usage >&2; exit 1; fi ;;
    2) if [[ "$1" == '--output' && -n "$2" ]]; then output=$2; else usage >&2; exit 1; fi ;;
    *) usage >&2; exit 1 ;;
esac
if [[ $(uname -s) != Darwin ]]; then
    printf 'Este script requiere macOS.\n' >&2
    exit 1
fi

section() { printf '\n=== %s ===\n' "$1"; }
run() {
    local result
    if command -v "$1" >/dev/null 2>&1; then
        if result=$("$@" 2>&1); then
            printf '%s\n' "${result:-No disponible: el sistema no devuelve datos.}"
        else
            printf '%s\nNo disponible: fallo la consulta o faltan permisos.\n' "$result"
        fi
    else
        printf 'No disponible: herramienta %s ausente.\n' "$1"
    fi
}
profile() { run system_profiler "$1" -detailLevel full -timeout 30; }

collect() {
    printf 'INFORME DE HARDWARE - MACOS\n'
    date '+Fecha: %Y-%m-%d %H:%M:%S %z'
    section 'Sistema operativo'
    run sw_vers
    run uname -m
    section 'Equipo, procesador, memoria total y firmware'
    profile SPHardwareDataType
    section 'Procesador y memoria: datos complementarios'
    local key
    for key in machdep.cpu.brand_string hw.model hw.physicalcpu hw.logicalcpu hw.memsize hw.cpufrequency hw.l2cachesize hw.l3cachesize; do
        run sysctl "$key"
    done
    printf 'hw.memsize y caches en bytes; hw.cpufrequency en Hz cuando este disponible.\n'
    section 'Memoria (modulos o memoria unificada segun el equipo)'
    profile SPMemoryDataType
    section 'Discos NVMe'
    profile SPNVMeDataType
    section 'Discos SATA'
    profile SPSerialATADataType
    section 'Almacenamiento y espacio libre'
    profile SPStorageDataType
    run diskutil list
    run df -h
    section 'Graficos y pantallas'
    profile SPDisplaysDataType
    section 'Tarjeta madre: identificadores expuestos por Apple'
    if command -v ioreg >/dev/null 2>&1; then
        local board
        if board=$(ioreg -rd1 -c IOPlatformExpertDevice 2>&1); then
            printf '%s\n' "$board" | grep -E '"(board-id|manufacturer|model|IOPlatformSerialNumber)"' ||
                printf 'No disponible: Apple no expone estos identificadores.\n'
        else
            printf '%s\nNo disponible: fallo la consulta de la placa.\n' "$board"
        fi
    else
        printf 'No disponible: herramienta ioreg ausente.\n'
    fi
    section 'Red'
    profile SPNetworkDataType
    section 'Audio'
    profile SPAudioDataType
    section 'USB'
    profile SPUSBDataType
    section 'Bateria y alimentacion'
    profile SPPowerDataType
}

report=$(collect)
printf '%s\n' "$report"
if [[ -n "$output" ]]; then
    if ! printf '%s\n' "$report" > "$output"; then
        printf 'No se pudo guardar el informe: %s\n' "$output" >&2
        exit 1
    fi
fi
