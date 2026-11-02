#!/bin/bash
# PORTLANDIA compatibility primitives. Source from a port; functions are opt-in.
# Does not replace system libraries, stop frontends, or tune clocks.

portcompat_canonical_firmware(){
 local name
 name=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')
 case "$name" in
  darkosre*) printf 'dArkOSRE\n';; darkos*) printf 'dArkOS\n';; arkos*) printf 'ArkOS\n';;
  knulli*) printf 'knulli\n';; muos|mustardos) printf 'muOS\n';; rocknix*) printf 'ROCKNIX\n';;
  amberelec*|351elec*) printf 'AmberELEC\n';; batocera*) printf 'Batocera.linux\n';;
  reglinux*) printf 'REGLinux\n';; crossmix*|trimui*) printf 'TrimUI\n';; nextui*) printf 'NextUI\n';;
  spruce*) printf 'spruce\n';; emuelec*) printf 'EmuELEC\n';; uos|unofficialos) printf 'UnofficialOS\n';;
  jelos*) printf 'JELOS\n';; stock*) printf 'Stock-unknown\n';; *) printf 'Unknown\n';;
 esac
}

portcompat_find_control(){
 local candidate
 for candidate in "${controlfolder:-/nonexistent}" "${PORTMASTER_HOME:-/nonexistent}" "${EMU_DIR:-/nonexistent}" \
  "${XDG_DATA_HOME:-${HOME:-/tmp}/.local/share}/PortMaster" \
  /opt/system/Tools/PortMaster /opt/tools/PortMaster /roms/tools/PortMaster /roms2/tools/PortMaster \
  /roms/ports/PortMaster /roms2/ports/PortMaster /userdata/system/.local/share/PortMaster \
  /userdata/roms/ports/PortMaster /mnt/mmc/MUOS/PortMaster /mnt/sdcard/MUOS/PortMaster \
  /mnt/SDCARD/Apps/PortMaster/PortMaster /storage/roms/ports/PortMaster /storage/.config/PortMaster;do
  if [[ -r "$candidate/control.txt" ]];then printf '%s\n' "$candidate";return 0;fi
 done
 return 1
}

portcompat_detect(){
 local os_text title value dimension
 PORTLANDIA_CONTROL_DIR=$(portcompat_find_control || true)
 PORTLANDIA_FIRMWARE=$(portcompat_canonical_firmware "${CFW_NAME:-Unknown}")
 if [[ $PORTLANDIA_FIRMWARE == Unknown ]];then
  os_text=$(cat /etc/os-release /usr/lib/os-release 2>/dev/null || true)
  if [[ -f /etc/rocknix-release ]] || [[ ${os_text,,} == *rocknix* ]];then PORTLANDIA_FIRMWARE=ROCKNIX
  elif [[ -d /opt/muos ]] || [[ ${os_text,,} == *mustardos* || ${os_text,,} == *muos* ]];then PORTLANDIA_FIRMWARE=muOS
  elif [[ -f /usr/share/knulli/knulli.version || -f /etc/knulli.version || -f /boot/boot/knulli.board ]] || [[ ${os_text,,} == *knulli* ]];then PORTLANDIA_FIRMWARE=knulli
  elif [[ -f /usr/share/plymouth/themes/text.plymouth ]];then
   title=$(grep -i -m1 'title=' /usr/share/plymouth/themes/text.plymouth 2>/dev/null || true)
   PORTLANDIA_FIRMWARE=$(portcompat_canonical_firmware "${title#*=}")
  elif [[ -f /etc/darkos_version ]];then PORTLANDIA_FIRMWARE=dArkOS
  elif [[ -f /etc/arkos_version ]];then PORTLANDIA_FIRMWARE=ArkOS
  elif [[ -d /mnt/SDCARD/Apps/PortMaster/PortMaster ]];then PORTLANDIA_FIRMWARE=TrimUI
  fi
 fi
 PORTLANDIA_KERNEL_ARCH=$(uname -m)
 PORTLANDIA_VIDEO=${SDL_VIDEODRIVER:-auto}
 if [[ $PORTLANDIA_VIDEO == auto && -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} && -S $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY ]];then PORTLANDIA_VIDEO=wayland;fi
 PORTLANDIA_AUDIO=${SDL_AUDIODRIVER:-auto}
 PORTLANDIA_PHYSICAL_W=${DISPLAY_WIDTH:-unknown};PORTLANDIA_PHYSICAL_H=${DISPLAY_HEIGHT:-unknown}
 if [[ $PORTLANDIA_PHYSICAL_W == unknown && -r /sys/class/graphics/fb0/virtual_size ]];then
  dimension=$(cat /sys/class/graphics/fb0/virtual_size)
  if [[ $dimension =~ ^([0-9]+),([0-9]+)$ ]];then PORTLANDIA_PHYSICAL_W=${BASH_REMATCH[1]};PORTLANDIA_PHYSICAL_H=${BASH_REMATCH[2]};fi
 fi
 export PORTLANDIA_CONTROL_DIR PORTLANDIA_FIRMWARE PORTLANDIA_KERNEL_ARCH PORTLANDIA_VIDEO PORTLANDIA_AUDIO PORTLANDIA_PHYSICAL_W PORTLANDIA_PHYSICAL_H
}

portcompat_controls(){
 # Prefer mappings already prepared by the CFW/PortMaster. A local override wins.
 # Does not source upstream mod_dArkOS, which can rewrite /usr/lib symlinks.
 local local_db=${1:-} override=${2:-} pc_existing=${SDL_GAMECONTROLLERCONFIG:-} pc_mapping=${sdl_controllerconfig:-}
 # Linux limits a single execve argument/environment string. Some old PM
 # versions read the entire controller database into this variable (E2BIG).
 if [[ ${#pc_existing} -gt 100000 ]];then unset SDL_GAMECONTROLLERCONFIG;fi
 export -n sdl_controllerconfig 2>/dev/null || true
 if [[ -n $override && -r $override ]];then
  if [[ $(wc -c <"$override") -lt 100000 ]];then export SDL_GAMECONTROLLERCONFIG="$(cat "$override")"
  else unset SDL_GAMECONTROLLERCONFIG;export SDL_GAMECONTROLLERCONFIG_FILE="$override";fi
  return 0
 fi
 if [[ -n $pc_mapping && ${#pc_mapping} -lt 100000 ]];then export SDL_GAMECONTROLLERCONFIG="$pc_mapping";fi
 if [[ -n ${SDL_GAMECONTROLLERCONFIG_FILE:-} && -r $SDL_GAMECONTROLLERCONFIG_FILE ]];then return 0;fi
 if [[ -n ${PORTLANDIA_CONTROL_DIR:-} && -r $PORTLANDIA_CONTROL_DIR/gamecontrollerdb.txt ]];then
  export SDL_GAMECONTROLLERCONFIG_FILE="$PORTLANDIA_CONTROL_DIR/gamecontrollerdb.txt"
 elif [[ -n $local_db && -r $local_db ]];then export SDL_GAMECONTROLLERCONFIG_FILE="$local_db";fi
}

portcompat_before_exec(){
 # The normal caller owns frontend lifetime. Use only the narrow CFW hooks.
 local executable=$1 name
 name=$(basename -- "$executable")
 # A control.txt already loaded by the caller may supply a more complete hook
 # (dialog handoff, Sway, muOS foreground tracking). Do not bypass it or run a
 # second competing platform hook. This function never sources CFW modules.
 if declare -F pm_platform_helper >/dev/null;then
  pm_platform_helper "$executable"
  return $?
 fi
 # Legacy/minimal controls may expose only the dialog APIs. Do not write to a
 # guessed pipe or terminate a frontend by process name.
 if declare -F pm_message_close >/dev/null;then pm_message_close || return $?;fi
 if [[ -n ${PM_PIPE:-} && -p $PM_PIPE && ! -L $PM_PIPE ]] && declare -F PortMasterDialogExit >/dev/null;then
  PortMasterDialogExit || return $?
 fi
 if [[ ${PORTLANDIA_FIRMWARE:-Unknown} == ROCKNIX && -x /usr/bin/portmaster_sway_fullscreen.sh ]];then
  /usr/bin/portmaster_sway_fullscreen.sh "$name" || return $?
 elif [[ ${PORTLANDIA_FIRMWARE:-Unknown} == muOS ]];then
  local path
  for path in /run/muos/system/foreground_process /opt/muos/config/system/foreground_process;do
   [[ ! -w $path ]] || printf '%s' "$name" >"$path"
  done
 fi
}

portcompat_apply_backends(){
 # Call AFTER the game's legacy exports. "auto" means let the installed SDL
 # choose, rather than forcing kmsdrm/alsa on every firmware.
 if [[ ${PORTLANDIA_VIDEO:-auto} == auto ]];then unset SDL_VIDEODRIVER;else export SDL_VIDEODRIVER="$PORTLANDIA_VIDEO";fi
 if [[ ${PORTLANDIA_AUDIO:-auto} == auto ]];then unset SDL_AUDIODRIVER;else export SDL_AUDIODRIVER="$PORTLANDIA_AUDIO";fi
}

portcompat_write_context(){
 # Carry whitelisted values across isolated launchers; no full environment dump.
 local target=$1 key
 : >"$target" || return 1
 for key in PORTLANDIA_CONTROL_DIR PORTLANDIA_FIRMWARE PORTLANDIA_KERNEL_ARCH PORTLANDIA_VIDEO PORTLANDIA_AUDIO PORTLANDIA_PHYSICAL_W PORTLANDIA_PHYSICAL_H SDL_GAMECONTROLLERCONFIG SDL_GAMECONTROLLERCONFIG_FILE;do
  if [[ -v $key ]];then printf 'export %s=%q\n' "$key" "${!key}" >>"$target";fi
 done
}

portcompat_report(){
 printf 'firmware=%s\nvideo=%s\naudio=%s\ncontrols=%s\n' "${PORTLANDIA_FIRMWARE:-Unknown}" "${PORTLANDIA_VIDEO:-auto}" "${PORTLANDIA_AUDIO:-auto}" "${PORTLANDIA_CONTROL_DIR:-not-found}"
 printf 'gpu_policy=firmware-driver unless an exact bundled-driver profile was tested\n'
 printf 'compatibility_status=needs per-game device validation\n'
}
