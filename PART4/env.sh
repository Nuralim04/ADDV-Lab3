# Source this file from bash on Apporto: source env.sh
# Paths and license settings are from the team's provided PART2/env.cshrc.
export VCS_HOME=/usr/local2/synopsys/vcs_2024/vcs/W-2024.09-SP2-3
export VERDI_HOME=/usr/local2/synopsys/verdi_2024.09/verdi_2024
export PATH="$VERDI_HOME/bin:$VCS_HOME/bin:/usr/local2/synopsys/syn_2023.12-SP51/bin:$PATH"
export LM_LICENSE_FILE=27020@enlicense5.eas.asu.edu
export SNPSLMD_LICENSE_FILE=27020@enlicense5.eas.asu.edu
export LD_LIBRARY_PATH="$VERDI_HOME/share/PLI/VCS/linux64:$VERDI_HOME/platform/linux64/lib/Qt5/lib/depends/xlib:/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PDK_DIR=/usr/local2/cadence/NCSU/SRC/FreePDK45
