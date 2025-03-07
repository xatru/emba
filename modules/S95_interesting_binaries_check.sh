#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2022 Siemens AG
# Copyright 2020-2022 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
#
# Author(s): Michael Messner, Pascal Eckmann

# Description:  Searches explicitly for binaries like gcc or gdb and also binaries for post exploitation like wget or ftp.

S95_interesting_binaries_check()
{
  module_log_init "${FUNCNAME[0]}"
  module_title "Check interesting binaries"
  pre_module_reporter "${FUNCNAME[0]}"

  NEG_LOG=0
  INT_COUNT=0

  if [[ "$THREADED" -eq 1 ]]; then
    interesting_binaries &
    WAIT_PIDS_S95+=( "$!" )
    post_exploitation &
    WAIT_PIDS_S95+=( "$!" )
  else
    interesting_binaries
    post_exploitation
  fi

  if [[ "$THREADED" -eq 1 ]]; then
    wait_for_pid "${WAIT_PIDS_S95[@]}"
  fi
  if [[ -f "$LOG_PATH_MODULE"/interesting_binaries.txt ]]; then
    sub_module_title "Interesting binaries"
    tee -a "$LOG_FILE" < "$LOG_PATH_MODULE"/interesting_binaries.txt
  fi
  if [[ -f "$LOG_PATH_MODULE"/post_exploitation_binaries.txt ]]; then
    sub_module_title "Interesting binaries for post exploitation"
    tee -a "$LOG_FILE" < "$LOG_PATH_MODULE"/post_exploitation_binaries.txt
  fi

  if [[ -f "$TMP_DIR"/INT_COUNT.tmp || -f "$TMP_DIR"/POST_COUNT.tmp ]]; then
    POST_COUNT=$(cat "$TMP_DIR"/POST_COUNT.tmp 2>/dev/null || true)
    INT_COUNT=$(cat "$TMP_DIR"/INT_COUNT.tmp 2>/dev/null || true)
    if [[ "$POST_COUNT" -gt 0 || "$INT_COUNT" -gt 0 ]]; then
      NEG_LOG=1
    fi
  fi

  write_log ""
  write_log "[*] Statistics:$INT_COUNT:$POST_COUNT"

  module_end_log "${FUNCNAME[0]}" "$NEG_LOG"
}

interesting_binaries()
{

  local COUNT=0
  declare -a MD5_DONE_INT
  INT_COUNT=0
  INT_BIN=()

  mapfile -t INT_BIN < <(config_find "$CONFIG_DIR""/interesting_binaries.cfg")
  if [[ "${INT_BIN[0]-}" == "C_N_F" ]] ; then print_output "[!] Config not found"
  elif [[ "${#INT_BIN[@]}" -ne 0 ]] ; then
    for LINE in "${INT_BIN[@]}" ; do
      if [[ -f "$LINE" ]] && file "$LINE" | grep -q "executable" ; then
        # we need every binary only once. So calculate the checksum and store it for checking
        BIN_MD5=$(md5sum "$LINE" | cut -d\  -f1)
        if [[ ! " ${MD5_DONE_INT[*]} " =~ ${BIN_MD5} ]]; then
          if [[ $COUNT -eq 0 ]] ; then
            write_log "[+] Found interesting binaries:" "$LOG_PATH_MODULE"/interesting_binaries.txt
            COUNT=1
          fi
          write_log "$(indent "$(orange "$(print_path "$LINE")")")" "$LOG_PATH_MODULE"/interesting_binaries.txt
          ((INT_COUNT+=1))
          MD5_DONE_INT+=( "$BIN_MD5" )
        fi
      fi
    done
  fi

  if [[ $COUNT -eq 0 ]] ; then
    write_log "[-] No interesting binaries found" "$LOG_PATH_MODULE"/interesting_binaries.txt
  fi
  echo "$INT_COUNT" >> "$TMP_DIR"/INT_COUNT.tmp
}

post_exploitation()
{

  local COUNT=0
  declare -a MD5_DONE_POST
  POST_COUNT=0
  INT_BIN_PE=()

  mapfile -t INT_BIN_PE < <(config_find "$CONFIG_DIR""/interesting_post_binaries.cfg")
  if [[ "${INT_BIN_PE[0]-}" == "C_N_F" ]] ; then print_output "[!] Config not found"
  elif [[ "${#INT_BIN_PE[@]}" -ne 0 ]] ; then
    for LINE in "${INT_BIN_PE[@]}" ; do
      if [[ -f "$LINE" ]] && file "$LINE" | grep -q "executable" ; then
        # we need every binary only once. Calculate the checksum and store it for checking
        BIN_MD5=$(md5sum "$LINE" | cut -d\  -f1)
        if [[ ! " ${MD5_DONE_POST[*]} " =~ ${BIN_MD5} ]]; then
          if [[ $COUNT -eq 0 ]] ; then
            write_log "[+] Found interesting binaries for post exploitation:" "$LOG_PATH_MODULE"/post_exploitation_binaries.txt
            COUNT=1
          fi
          write_log "$(indent "$(orange "$(print_path "$LINE")")")" "$LOG_PATH_MODULE"/post_exploitation_binaries.txt
          ((POST_COUNT+=1))
          MD5_DONE_POST+=( "$BIN_MD5" )
        fi
      fi
    done
  fi
  if [[ $COUNT -eq 0 ]] ; then
    write_log "[-] No interesting binaries for post exploitation found" "$LOG_PATH_MODULE"/post_exploitation_binaries.txt
  fi
  echo "$POST_COUNT" >> "$TMP_DIR"/POST_COUNT.tmp
}

