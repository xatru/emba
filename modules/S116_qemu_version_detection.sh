#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2022 Siemens Energy AG
# Copyright 2020-2022 Siemens AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
#
# Author(s): Michael Messner, Pascal Eckmann

# Description:  This module extracts version information from the results of S115

S116_qemu_version_detection() {
  module_log_init "${FUNCNAME[0]}"
  NEG_LOG=0

  if [[ "$RTOS" -eq 0 ]]; then
    module_title "Identified software components - via usermode emulation."
    pre_module_reporter "${FUNCNAME[0]}"


    # This module waits for S115_usermode_emulator
    # check emba.log for S115_usermode_emulator
    if [[ -f "$LOG_DIR"/"$MAIN_LOG_FILE" ]]; then
      while [[ $(grep -c S115_usermode_emulator "$LOG_DIR"/"$MAIN_LOG_FILE" || true) -eq 1 ]]; do
        sleep 1
      done
    fi

    LOG_PATH_S115="$LOG_DIR"/s115_usermode_emulator.txt
    if [[ -f "$LOG_PATH_S115" && -d "$LOG_DIR/s115_usermode_emulator" ]]; then
      LOG_PATH_MODULE_S115="$LOG_DIR"/s115_usermode_emulator/

      write_csv_log "binary/file" "version_rule" "version_detected" "csv_rule" "license" "static/emulation"
      TYPE="emulation"

      while read -r VERSION_LINE; do
        if echo "$VERSION_LINE" | grep -v -q "^[^#*/;]"; then
          continue
        fi

        if [[ $THREADED -eq 1 ]]; then
          version_detection_thread &
          WAIT_PIDS_F05+=( "$!" )
        else
          version_detection_thread
        fi
      done < "$CONFIG_DIR"/bin_version_strings.cfg
      echo
      if [[ $THREADED -eq 1 ]]; then
        wait_for_pid "${WAIT_PIDS_F05[@]}"
      fi
      if [[ $(wc -l "$LOG_DIR"/s116_qemu_version_detection.csv | awk '{print $1}' ) -gt 1 ]]; then
        NEG_LOG=1
      fi
    fi
  fi

  module_end_log "${FUNCNAME[0]}" "$NEG_LOG"
}

version_detection_thread() {
  BINARY="$(echo "$VERSION_LINE" | cut -d\; -f1)"
  STRICT="$(echo "$VERSION_LINE" | cut -d\; -f2)"
  LIC="$(echo "$VERSION_LINE" | cut -d\; -f3)"
  CSV_REGEX="$(echo "$VERSION_LINE" | cut -d\; -f5)"

  VERSION_IDENTIFIER="$(echo "$VERSION_LINE" | cut -d\; -f4 | sed s/^\"// | sed s/\"$//)"

  BINARY_PATH=""
  BINARY_PATHS=()
  LOG_PATH_=""

  # if we have the key strict this version identifier only works for the defined binary and is not generic!
  if [[ $STRICT == "strict" ]]; then
    if [[ -f "$LOG_PATH_MODULE_S115"/qemu_tmp_"$BINARY".txt ]]; then
      mapfile -t VERSIONS_DETECTED < <(grep -a -o -E "$VERSION_IDENTIFIER" "$LOG_PATH_MODULE_S115"/qemu_tmp_"$BINARY".txt | sort -u 2>/dev/null || true)
      mapfile -t BINARY_PATHS < <(strip_color_codes "$(grep -a "Emulating binary:" "$LOG_PATH_MODULE_S115"/qemu_tmp_"$BINARY".txt | cut -d: -f2 | sed -e 's/^\ //' | sort -u 2>/dev/null || true)")
      TYPE="emulation/strict"
    fi
  else
    readarray -t VERSIONS_DETECTED < <(grep -a -o -H -E "$VERSION_IDENTIFIER" "$LOG_PATH_MODULE_S115"/qemu_tmp*.txt | sort -u 2>/dev/null || true)
    # VERSIONS_DETECTED:
    # path_to_logfile:Version Identifier
    #└─$ grep -a -o -H -E "Version: 1.8" /home/m1k3/firmware/emba_logs_manual/test_dir300/s115_usermode_emulator/qemu_tmp_radvd.txt                                                    130 ⨯
    # /home/m1k3/firmware/emba_logs_manual/test_dir300/s115_usermode_emulator/qemu_tmp_radvd.txt:Version: 1.8
    # /home/m1k3/firmware/emba_logs_manual/test_dir300/s115_usermode_emulator/qemu_tmp_radvd.txt:Version: 1.8
    for VERSION_DETECTED in "${VERSIONS_DETECTED[@]}"; do
      mapfile -t LOG_PATHS < <(strip_color_codes "$(echo "$VERSION_DETECTED" | cut -d: -f1 | sort -u || true)")
      for LOG_PATH_ in "${LOG_PATHS[@]}"; do
        mapfile -t BINARY_PATHS_ < <(strip_color_codes "$(grep -a "Emulating binary:" "$LOG_PATH_" 2>/dev/null | cut -d: -f2 | sed -e 's/^\ //' | sort -u 2>/dev/null || true)")
        for BINARY_PATH_ in "${BINARY_PATHS_[@]}"; do
          # BINARY_PATH is the final array which we are using further
          BINARY_PATHS+=( "$BINARY_PATH_" )
        done
      done
    done
    TYPE="emulation"
  fi

  for VERSION_DETECTED in "${VERSIONS_DETECTED[@]}"; do
    LOG_PATH_="$(strip_color_codes "$(echo "$VERSION_DETECTED" | cut -d: -f1 | sort -u || true)")"
    if [[ $STRICT != "strict" ]]; then
      VERSION_DETECTED="$(echo "$VERSION_DETECTED" | cut -d: -f2- | sort -u)"
    fi

    get_csv_rule "$VERSION_DETECTED" "$CSV_REGEX"

    for BINARY_PATH in "${BINARY_PATHS[@]}"; do
      print_output "[+] Version information found ${RED}""$VERSION_DETECTED""${NC}${GREEN} in binary $ORANGE$BINARY_PATH$GREEN (license: $ORANGE$LIC$GREEN) (${ORANGE}$TYPE$GREEN)." "" "$LOG_PATH_"
      write_csv_log "$BINARY_PATH" "$BINARY" "$VERSION_DETECTED" "$CSV_RULE" "$LIC" "$TYPE"
    done
  done
}

