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

# Description: As binwalk has issues with UBI filesystems we are going to extract them here
# Pre-checker threading mode - if set to 1, these modules will run in threaded mode
export PRE_THREAD_ENA=0

P15_ubi_extractor() {
  module_log_init "${FUNCNAME[0]}"
  NEG_LOG=0
  if [[ "$UBI_IMAGE" -eq 1 ]]; then
    module_title "UBI filesystem extractor"
    pre_module_reporter "${FUNCNAME[0]}"

    EXTRACTION_DIR="$LOG_DIR/firmware/ubi_extracted"
    mkdir -p "$EXTRACTION_DIR"

    ubi_extractor "$FIRMWARE_PATH" "$EXTRACTION_DIR"

    if [[ "$FILES_UBI_EXT" -gt 0 ]]; then
      export FIRMWARE_PATH="$LOG_DIR"/firmware/
    fi
    NEG_LOG=1
  fi
  module_end_log "${FUNCNAME[0]}" "$NEG_LOG"
}

ubi_extractor() {
  local UBI_PATH_="$1"
  local EXTRACTION_DIR_="$2"
  local UBI_FILE
  local UBI_INFO
  local UBI_1st_ROUND
  local UBI_DATA
  local DIRS_UBI_EXT=0
  FILES_UBI_EXT=0

  sub_module_title "UBI filesystem extractor"

  print_output "[*] Extracts UBI firmware image $ORANGE$UBI_PATH_$NC with ${ORANGE}ubireader_extract_images$NC."
  print_output "[*] File details: $ORANGE$(file "$UBI_PATH_" | cut -d ':' -f2-)$NC"
  ubireader_extract_images -i -v -w -o "$EXTRACTION_DIR_" "$UBI_PATH_" | tee -a "$LOG_FILE"

  print_output "[*] Extracts UBI firmware image $ORANGE$UBI_PATH_$NC with ${ORANGE}ubireader_extract_files$NC."
  ubireader_extract_files -i -v -w -o "$EXTRACTION_DIR_" "$UBI_PATH_" | tee -a "$LOG_FILE"
  UBI_1st_ROUND="$(find "$EXTRACTION_DIR_" -type f -exec file {} \; | grep "UBI image")"

  for UBI_DATA in "${UBI_1st_ROUND[@]}"; do
    UBI_FILE=$(echo "$UBI_DATA" | cut -d: -f1)
    UBI_INFO=$(echo "$UBI_DATA" | cut -d: -f2)
    if [[ "$UBI_INFO" == *"UBIfs image"* ]]; then
      sub_module_title "UBIfs deep extraction"
      print_output "[*] Extracts UBIfs firmware image $ORANGE$UBI_PATH_$NC with ${ORANGE}ubireader_extract_files$NC."
      print_output "[*] File details: $ORANGE$(file "$UBI_FILE" | cut -d ':' -f2-)$NC"
      ubireader_extract_files -l -i -v -o "$EXTRACTION_DIR_"/UBIfs_extracted "$UBI_FILE" | tee -a "$LOG_FILE"
    fi
  done

  print_output ""
  FILES_UBI_EXT=$(find "$EXTRACTION_DIR_" -type f | wc -l)
  DIRS_UBI_EXT=$(find "$EXTRACTION_DIR_" -type d | wc -l)
  print_output "[*] Extracted $ORANGE$FILES_UBI_EXT$NC files and $ORANGE$DIRS_UBI_EXT$NC directories from the firmware image."
}
