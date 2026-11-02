#!/bin/bash
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 2
cd -- "$root" || exit 2
mode=${1:-play}
case "$mode" in play|--check) ;; *) echo 'Uso: FIFA 14.sh [--check]';exit 2;;esac
source compat/portcompat.sh
portcompat_detect
if [[ -n $PORTLANDIA_CONTROL_DIR ]];then
 controlfolder=$PORTLANDIA_CONTROL_DIR
 set +u;source "$controlfolder/control.txt";export PORT_32BIT=Y
 case "${CFW_NAME:-}" in muOS|knulli|ROCKNIX|TrimUI|AmberELEC|Batocera.linux|REGLinux) [[ ! -r $controlfolder/mod_$CFW_NAME.txt ]] || source "$controlfolder/mod_$CFW_NAME.txt";;esac
 if declare -F get_controls >/dev/null;then get_controls;fi
 set -u
fi
portcompat_detect;portcompat_controls "$root/gamecontrollerdb.txt"
case $(uname -m) in aarch64|armv7l|armv8l) ;; *) echo 'Este cargador requiere ARM con soporte de 32 bits.';exit 8;;esac
mkdir -p reports userdata shaders
stamp=$(date -u +%Y%m%d-%H%M%S)-$$;report="$root/reports/run-$stamp";mkdir -p "$report"
printf '%s\n' "$report" >latest-report
exec >"$report/launcher.log" 2>&1
portcompat_report;portcompat_write_context "$report/environment.sh"
exec 9>/tmp/ports-android-display.lock
flock -n 9 || exit 3
if command -v python3 >/dev/null;then python3 verify-runtime.py >"$report/integrity.log" || exit 5
else sha256sum -c runtime.sha256 >"$report/integrity.log" || exit 5;fi
profile=${PORTLANDIA_PROFILE:-auto}
if [[ $profile == auto ]];then
 profile=firmware
 compatible=$(tr '\0' '\n' </proc/device-tree/compatible 2>/dev/null || true)
 if [[ $compatible == *rockchip,rk3326* && $(uname -r) == 4.4.* && -c /dev/mali0 ]];then
  case "$PORTLANDIA_FIRMWARE" in ArkOS|dArkOS|dArkOSRE) profile=r36;;esac
 fi
fi
[[ $profile == r36 || $profile == firmware ]] || exit 8
printf '%s\n' "$profile" >"$report/profile.txt"
pid= monitor= gpu_dir= frontend_stopped=0 clocks_started=0
finish(){
 result=$?;trap - EXIT INT TERM HUP
 if [[ -n $monitor ]];then kill "$monitor" 2>/dev/null || true;wait "$monitor" 2>/dev/null || true;fi
 if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null;then
  kill -TERM "$pid" 2>/dev/null || true
  for tick in {1..30};do kill -0 "$pid" 2>/dev/null || break;sleep .1;done
  kill -KILL "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true
 fi
 if [[ $clocks_started == 1 ]];then sudo -n python3 port_clocks.py restore "$report" || true;fi
 if [[ -n $gpu_dir ]];then for name in $gpu_names;do rm -f -- "$gpu_dir/$name";done;rmdir -- "$gpu_dir" || true;fi
 if [[ $frontend_stopped == 1 ]];then sudo -n systemctl start emulationstation.service || true;fi
 if declare -F pm_finish >/dev/null;then set +u;pm_finish || true;fi
 printf '%s\n' "$result" >"$report/exit-code";exit "$result"
}
trap finish EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
export HOME="$root/userdata" XDG_CONFIG_HOME="$root/userdata/.config" XDG_DATA_HOME="$root/userdata/.local/share"
export MALLOC_ARENA_MAX=2 SDL_GAMECONTROLLER_USE_BUTTON_LABELS=0 FIFA14_LETTERBOX=1
export ALSOFT_DRIVERS=alsa
export PORT_FPS_HUD=0
if [[ $mode == --check ]];then
 if [[ $profile == r36 ]];then
  "$root/runtime/ld-linux-armhf.so.3" --library-path "$root/runtime/lib" --list "$root/fifa14-intro" >"$report/intro-dependencies.txt" 2>&1 || { cat "$report/intro-dependencies.txt";exit 8; }
  "$root/runtime/ld-linux-armhf.so.3" --library-path "$root/runtime/lib" --list "$root/fifa14-host" >"$report/game-dependencies.txt" 2>&1 || { cat "$report/game-dependencies.txt";exit 8; }
 else
  echo 'Perfil firmware: requiere cargador y SDL2 ARM32 del sistema; prueba real pendiente.'
 fi
 echo 'CHECK OK: datos y hashes verificados; no se ha iniciado el juego ni cambiado frecuencias.'
 exit 0
fi
if [[ ${FIFA14_TEST_DETACHED:-0} == 1 ]] && systemctl is-active --quiet emulationstation.service;then
 sudo -n systemctl stop emulationstation.service || exit 7;frontend_stopped=1
fi
if [[ $profile == r36 ]];then
 gpu_dir="/dev/shm/fifa14-gpu-$$";mkdir -m 700 "$gpu_dir" || exit 6
 gpu_names='libMali.so libmali.so libEGL.so libEGL.so.1 libGLESv2.so libGLESv2.so.2 libGLESv1_CM.so.1 libgbm.so libgbm.so.1'
 for name in $gpu_names;do ln -s "$root/graphics/libMali.so" "$gpu_dir/$name";done
 export SDL_VIDEO_EGL_DRIVER="$root/graphics/libMali.so" SDL_VIDEO_GL_DRIVER="$root/graphics/libMali.so" SDL_VIDEODRIVER=kmsdrm SDL_AUDIODRIVER=alsa
 export ALSA_CONFIG_DIR="$root/runtime/share/alsa" ALSA_CONFIG_PATH="$root/runtime/share/alsa/alsa.conf" ALSA_PLUGIN_DIR="$root/runtime/lib/alsa-lib"
 unset LD_PRELOAD LD_LIBRARY_PATH
 loader=("$root/runtime/ld-linux-armhf.so.3" --library-path "$gpu_dir:$root/runtime/lib" --preload "$root/libfifa14.so")
else
 unset ALSA_CONFIG_DIR ALSA_CONFIG_PATH ALSA_PLUGIN_DIR
 portcompat_apply_backends
 export LD_PRELOAD="$root/libfifa14.so${LD_PRELOAD:+:$LD_PRELOAD}"
 loader=()
fi
rm -f -- quit.req capture.req controls.req input.req
set +u;portcompat_before_exec "$root/fifa14-host";result=$?;set -u
[[ $result == 0 ]] || exit "$result"
intro_result=0
touch_choice="$report/touch-controls.choice"
if [[ -f reports/capture-intro-next ]];then
 export FIFA14_INTRO_CAPTURE="$report/intro.ppm"
 rm -f reports/capture-intro-next
fi
if [[ $profile == r36 ]];then
 env -u LD_PRELOAD -u LD_LIBRARY_PATH "$root/runtime/ld-linux-armhf.so.3" \
  --library-path "$gpu_dir:$root/runtime/lib" "$root/fifa14-intro" "$touch_choice" || intro_result=$?
else
 env -u LD_PRELOAD -u LD_LIBRARY_PATH "$root/fifa14-intro" "$touch_choice" || intro_result=$?
fi
[[ $intro_result != 125 ]] || exit 0
[[ $intro_result == 0 ]] || exit "$intro_result"
IFS= read -r touch_mode <"$touch_choice" || exit 8
case "$touch_mode" in
 1|0) export FIFA14_TOUCH_BUTTONS="$touch_mode";;
 *) echo 'Seleccion de controles no valida.';exit 8;;
esac
if [[ $profile == r36 ]];then
 for path in /sys/class/devfreq/ff400000.gpu/min_freq /sys/class/devfreq/ff400000.gpu/max_freq /sys/class/devfreq/dmc/max_freq /sys/devices/system/cpu/cpufreq/policy0/scaling_governor;do
  [[ ! -r $path ]] || printf '%s %s\n' "$path" "$(cat "$path")" >>"$report/clocks-before.tsv"
 done
 clocks_started=1
 sudo -n python3 port_clocks.py start >"$report/clocks.log" 2>&1 || true
fi
"${loader[@]}" ./fifa14-host >"$report/game.log" 2>&1 &
pid=$!;printf '%s\n' "$pid" >"$report/game.pid"
(
 while kill -0 "$pid" 2>/dev/null;do
  printf '%s ' "$(date +%s)";awk '/^(MemAvailable|SwapFree):/{printf "%s ",$0}END{print ""}' /proc/meminfo
  awk '/^(VmRSS|VmSwap):/{printf "%s ",$0}END{print ""}' "/proc/$pid/status" 2>/dev/null || true;sleep 2
 done
) >"$report/memory.log" 2>&1 &
monitor=$!
wait "$pid";result=$?;pid=
exit "$result"
