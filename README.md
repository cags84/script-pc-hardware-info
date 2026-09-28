# Información del hardware

Tres scripts independientes para consultar el equipo sin instalar dependencias.
Muestran un informe en consola y permiten guardar la misma información en TXT.
No modifican la configuración ni elevan permisos automáticamente.

## Uso

Ejecuta desde la carpeta del repositorio.

**Windows** — Windows PowerShell 5.1 o PowerShell 7 en Windows:

```powershell
.\hardware-info.ps1
.\hardware-info.ps1 -OutputPath informe.txt
```

Si la política de ejecución bloquea el script, puedes autorizarlo solo para ese
proceso, después de revisar su contenido:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hardware-info.ps1 -OutputPath informe.txt
```

**Linux** — Bash:

```bash
bash hardware-info-linux.sh
bash hardware-info-linux.sh --output informe.txt
```

**macOS** — Bash incluido en el sistema; Intel y Apple Silicon:

```bash
bash hardware-info-macos.sh
bash hardware-info-macos.sh --output informe.txt
```

Las rutas con espacios deben ir entre comillas. La carpeta de destino debe
existir. Un archivo de salida existente se sobrescribe. Si no se puede guardar,
el informe sigue visible en consola y el script termina con error.

## Contenido y límites

- Equipo, sistema operativo, procesador, núcleos, hilos y frecuencias disponibles.
- Memoria total y módulos: capacidad, fabricante, tipo y velocidad disponibles.
- Discos, interfaces, particiones/volúmenes y espacio libre.
- Gráficos, placa base, firmware, red, audio y batería; USB en Linux y macOS.

Los títulos están en español; los campos y resultados nativos conservan el
idioma del sistema o de la herramienta. Las unidades se indican en el informe.
Campos vacíos, ceros o valores desconocidos pueden significar que el fabricante
no proporciona el dato, no que el componente carezca de esa característica.

En Linux se aprovechan `lscpu`, `lsblk`, `ip`, `lspci`, `lsusb` y `dmidecode`
solo si ya están disponibles. Los módulos RAM y ciertos números de serie pueden
requerir ejecutar manualmente con permisos de administrador. Sin esas
herramientas o permisos, se informa la limitación y continúa el resto del informe.

En Windows, la memoria de GPU publicada por CIM puede ser inexacta, especialmente
por encima de 4 GiB. En macOS, Apple no siempre expone modelo comercial de la
placa, frecuencias o módulos individuales de memoria unificada. Las consultas de
`system_profiler` pueden tardar; cada una tiene un límite de 30 segundos.

Máquinas virtuales y contenedores muestran el hardware que el entorno expone.
No se incluyen temperaturas, diagnóstico de salud ni pruebas de rendimiento.
Los informes pueden contener números de serie y direcciones de red: revísalos
antes de compartirlos.

## Validación

Comprobaciones de sintaxis Bash:

```bash
bash -n hardware-info-linux.sh
bash -n hardware-info-macos.sh
```

Para validar en cada sistema, ejecuta su script, comprueba los componentes frente
a las herramientas del sistema y prueba la exportación, una ruta inexistente y
la ejecución sin privilegios. La ausencia de un componente no debe interrumpir
las demás secciones. La validación en un sistema no sustituye la ejecución en los
otros dos.

Validación realizada: ejecución real en Windows PowerShell 5.1, exportación TXT
idéntica a la salida y error ante una ruta inexistente. Ambos scripts Bash pasan
`bash -n`; también se comprobó su exportación y manejo de rutas inválidas con el
sistema operativo simulado en Git Bash. Las consultas reales de hardware en
Linux y macOS quedan pendientes de probar en esos sistemas.
