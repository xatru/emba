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

# Description:  This module is for including simple user commands that should get executed.

S150_user_check()
{
  module_log_init "${FUNCNAME[0]}"
  module_title "Custom check commands"

  print_output "[*] Your own check commands"
  print_output "[*] Testing firmware in ""$FIRMWARE_PATH"

  for LINE in "${BINARIES[@]}" ; do
	  print_output "$LINE"
  done

  module_end_log "${FUNCNAME[0]}" 1
}
