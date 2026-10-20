#!/usr/bin/env bash
# Ejecuta las pruebas de integración de QA en iOS y/o Android contra el
# Firebase Emulator Suite y conserva los resultados en docs/qa/results/<fecha>/.
#
# Uso: tool/qa/run_integration_tests.sh [ios|android|all] [archivo.dart ...]
#   IOS_DEVICE   UDID del simulador (por defecto: el booted o iPhone 18 Pro)
#   ANDROID_DEVICE id adb (por defecto: emulator-5554)
#   RESULTS_DIR  carpeta de resultados (por defecto docs/qa/results/<YYYY-MM-DD>)
#
# Requisitos: emuladores Firebase arrancados (ver SKILL.md §4) y semilla cargada.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export PATH="$PATH:$HOME/Development/flutter/bin:$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/emulator"

TARGET="${1:-all}"; shift || true
FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
  FILES=( $(ls integration_test/*_test.dart | sort) )
fi
STAMP="$(date +%Y-%m-%d)"
RESULTS_DIR="${RESULTS_DIR:-docs/qa/results/$STAMP}"
mkdir -p "$RESULTS_DIR"

# Simulador iOS: el booted, o el iPhone 18 Pro (iOS 27) por defecto (se arranca si hace falta).
DEFAULT_IOS_UDID="32BF98EC-C8B6-474F-92F4-486F20601D06"
IOS_DEVICE="${IOS_DEVICE:-$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F-]{36}' | head -1)}"
IOS_DEVICE="${IOS_DEVICE:-$DEFAULT_IOS_UDID}"
ensure_ios_booted() {
  if ! xcrun simctl list devices booted | grep -q "$IOS_DEVICE"; then
    echo "▶ Arrancando simulador $IOS_DEVICE"
    xcrun simctl boot "$IOS_DEVICE" 2>/dev/null || true
    xcrun simctl bootstatus "$IOS_DEVICE" -b >/dev/null 2>&1 || true
    open -a Simulator >/dev/null 2>&1 || true
    sleep 5
  fi
}
FAILURES=0
ANDROID_DEVICE="${ANDROID_DEVICE:-emulator-5554}"

# Comprueba que los emuladores de Firebase responden (Firestore 8080).
if ! curl -s -o /dev/null "http://127.0.0.1:8080/"; then
  echo "✖ El emulador de Firestore no responde en 127.0.0.1:8080. Arranca el Emulator Suite primero." >&2
  exit 2
fi

seed() {
  # Los archivos perf_* reciben además el historial masivo (--big).
  local extra=""
  case "$1" in *perf_*) extra="--big" ;; esac
  node tool/qa/seed_emulator.js $extra > "$RESULTS_DIR/seed-$1.log" 2>&1 || { echo "✖ seed falló (ver $RESULTS_DIR/seed-$1.log)"; return 1; }
}

run_platform() {
  local platform="$1" device="$2" host="$3"
  local summary="$RESULTS_DIR/summary-$platform.tsv"
  echo -e "archivo\tresultado\tduracion_s\tlog" > "$summary"
  for f in "${FILES[@]}"; do
    local name; name="$(basename "$f" .dart)"
    local log="$RESULTS_DIR/$platform-$name.log"
    echo "▶ [$platform] $name"
    seed "$platform-$name" || { echo -e "$name\tSEED_FAIL\t0\t$log" >> "$summary"; continue; }
    # Estado de permisos y ubicación deterministas. Los archivos cuyo nombre
    # contiene "_denied_" se ejecutan con el permiso de ubicación REVOCADO.
    if [[ "$name" == *_denied_* ]]; then
      if [ "$platform" = "android" ]; then
        adb -s "$device" shell pm revoke net.farmatime.app android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
        adb -s "$device" shell pm revoke net.farmatime.app android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
        # user-fixed = "no volver a preguntar": el SO responde denegado sin diálogo.
        adb -s "$device" shell pm set-permission-flags net.farmatime.app android.permission.ACCESS_FINE_LOCATION user-fixed 2>/dev/null || true
        adb -s "$device" shell pm set-permission-flags net.farmatime.app android.permission.ACCESS_COARSE_LOCATION user-fixed 2>/dev/null || true
      else
        xcrun simctl privacy "$device" revoke location net.farmatime.app 2>/dev/null || true
      fi
    else
      if [ "$platform" = "android" ]; then
        adb -s "$device" shell pm grant net.farmatime.app android.permission.POST_NOTIFICATIONS 2>/dev/null || true
        adb -s "$device" shell pm grant net.farmatime.app android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
        adb -s "$device" shell pm grant net.farmatime.app android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
        adb -s "$device" emu geo fix -3.7038 40.4168 2>/dev/null || true
      else
        xcrun simctl privacy "$device" grant location-always net.farmatime.app 2>/dev/null || true
        xcrun simctl location "$device" set 40.4168,-3.7038 2>/dev/null || true
      fi
    fi
    local start; start=$(date +%s)
    # Watchdog: un test colgado (p. ej. tearDownAll que nunca termina) no debe bloquear la auditoría.
    flutter test "$f" -d "$device" --dart-define=FIREBASE_EMULATOR_HOST="$host" --reporter expanded > "$log" 2>&1 &
    local tpid=$!
    local waited=0
    while kill -0 "$tpid" 2>/dev/null; do
      sleep 5; waited=$((waited+5))
      if [ "$waited" -ge "${FILE_TIMEOUT:-1500}" ]; then
        echo "   ✖ timeout (${FILE_TIMEOUT:-1500}s): matando el test" | tee -a "$log"
        pkill -P "$tpid" 2>/dev/null; kill "$tpid" 2>/dev/null; sleep 2; kill -9 "$tpid" 2>/dev/null
        break
      fi
    done
    wait "$tpid" 2>/dev/null
    local rc=$?
    local end; end=$(date +%s)
    local res="PASS"; if [ $rc -ne 0 ]; then res="FAIL"; FAILURES=$((FAILURES+1)); fi
    echo -e "$name\t$res\t$((end-start))\t$log" >> "$summary"
    echo "   → $res ($((end-start)) s) · $log"
  done
  echo "Resumen $platform: $summary"
  column -t -s $'\t' "$summary" || cat "$summary"
}

case "$TARGET" in
  ios)     ensure_ios_booted; run_platform ios "$IOS_DEVICE" localhost ;;
  android) run_platform android "$ANDROID_DEVICE" 10.0.2.2 ;;
  all)     ensure_ios_booted; run_platform ios "$IOS_DEVICE" localhost; run_platform android "$ANDROID_DEVICE" 10.0.2.2 ;;
  *) echo "uso: $0 [ios|android|all] [archivos...]"; exit 1 ;;
esac
echo "Pruebas fallidas: $FAILURES"
[ "$FAILURES" -eq 0 ]
