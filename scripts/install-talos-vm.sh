#!/usr/bin/env bash

source /dev/stdin <<<$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func)

function header_info {
  clear
  cat <<"EOF"
  _______     __            __    _                 
 /_  __/___ _/ /___  ___   / /   (_)___  __  ___  __
  / / / __ `/ / __ \/ __/  / /   / / __ \/ / / / |/_/
 / / / /_/ / / /_/ /\__ \ / /___/ / / / / /_/ />  <  
/_/  \__,_/_/\____/___/_//_____/_/_/ /_/\__,_/_/|_|  
                                                      
EOF
}
header_info
echo -e "\n Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
NSAPP="talosvm"
var_os="talos"
var_version="1.11.5"

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")

CL=$(echo "\033[m")
BOLD=$(echo "\033[1m")
BFR="\\r\\033[K"
HOLD=" "
TAB="  "

CM="${TAB}✔️${TAB}${CL}"
CROSS="${TAB}✖️${TAB}${CL}"
INFO="${TAB}💡${TAB}${CL}"
OS="${TAB}🖥️${TAB}${CL}"
CONTAINERTYPE="${TAB}📦${TAB}${CL}"
DISKSIZE="${TAB}💾${TAB}${CL}"
CPUCORE="${TAB}🧠${TAB}${CL}"
RAMSIZE="${TAB}🛠️${TAB}${CL}"
CONTAINERID="${TAB}🆔${TAB}${CL}"
HOSTNAME="${TAB}🏠${TAB}${CL}"
BRIDGE="${TAB}🌉${TAB}${CL}"
GATEWAY="${TAB}🌐${TAB}${CL}"
DEFAULT="${TAB}⚙️${TAB}${CL}"
MACADDRESS="${TAB}🔗${TAB}${CL}"
VLANTAG="${TAB}🏷️${TAB}${CL}"
CREATING="${TAB}🚀${TAB}${CL}"
ADVANCED="${TAB}🧩${TAB}${CL}"
CLOUD="${TAB}☁️${TAB}${CL}"

THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  post_update_to_api "failed" "${command}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function get_valid_nextid() {
  local try_id
  try_id=$(pvesh get /cluster/nextid)
  while true; do
    if [ -f "/etc/pve/qemu-server/${try_id}.conf" ] || [ -f "/etc/pve/lxc/${try_id}.conf" ]; then
      try_id=$((try_id + 1))
      continue
    fi
    if lvs --noheadings -o lv_name | grep -qE "(^|[-_])${try_id}($|[-_])"; then
      try_id=$((try_id + 1))
      continue
    fi
    break
  done
  echo "$try_id"
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  post_update_to_api "done" "none"
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

function msg_info() {
  local msg="$1"
  echo -ne "${TAB}${YW}${HOLD}${msg}${HOLD}"
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR}${CM}${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR}${CROSS}${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

function exit-script() {
  clear
  echo -e "\n${CROSS}${RD}User exited script${CL}\n"
  exit
}

function get_settings() {
  # Set opinionated defaults for Talos
  FORMAT=",efitype=4m"
  MACHINE=" -machine q35"
  DISK_CACHE="cache=writethrough,"
  CPU_TYPE=" -cpu host"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  
  # Get VM ID
  VMID=$(get_valid_nextid)
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox Homelab Scripts" --inputbox "Set Virtual Machine ID" 8 58 $VMID --title "VM ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID=$(get_valid_nextid)
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        whiptail --backtitle "Proxmox Homelab Scripts" --msgbox "ID $VMID is already in use" 8 58
        continue
      fi
      break
    else
      exit-script
    fi
  done
  echo -e "${CONTAINERID}${BOLD}${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
  
  # Get Hostname
  if VM_NAME=$(whiptail --backtitle "Proxmox Homelab Scripts" --inputbox "Set Hostname" 8 58 talos-node --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="talos-node"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
    fi
  else
    exit-script
  fi
  echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
  
  # Get CPU Cores
  if CORE_COUNT=$(whiptail --backtitle "Proxmox Homelab Scripts" --inputbox "Allocate CPU Cores (Minimum 2)" 8 58 2 --title "CPU CORES" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
    fi
  else
    exit-script
  fi
  echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}$CORE_COUNT${CL}"
  
  # Get RAM Size
  if RAM_SIZE=$(whiptail --backtitle "Proxmox Homelab Scripts" --inputbox "Allocate RAM in MiB\\n(4096 for control plane, 8192 for worker)" 10 58 4096 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="4096"
    fi
  else
    exit-script
  fi
  echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}$RAM_SIZE MiB${CL}"
  
  # Get Disk Size
  if DISK_INPUT=$(whiptail --backtitle "Proxmox Homelab Scripts" --inputbox "Set Disk Size in GiB" 8 58 20 --title "DISK SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $DISK_INPUT ]; then
      DISK_SIZE="20G"
    else
      DISK_SIZE="${DISK_INPUT}G"
    fi
  else
    exit-script
  fi
  echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}$DISK_SIZE${CL}"
  
  # Summary
  echo -e "${CONTAINERTYPE}${BOLD}${DGN}Machine Type: ${BGN}q35 (UEFI)${CL}"
  echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}Host${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}${BRG}${CL}"
  echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${CREATING}${BOLD}${DGN}Creating Talos Linux VM${CL}"
}

check_root

header_info
get_settings

post_to_api_vm

msg_info "Validating Storage"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "Unable to detect a valid storage location."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox Homelab Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool would you like to use for ${HN}?\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3)
  done
fi
msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Retrieving the URL for the Talos Linux ISO with QEMU Guest Agent"
# Using the factory image with qemu-guest-agent extension
# Factory installer ID: ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515
URL=https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.11.5/metal-amd64.iso
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
msg_info "Downloading Talos Linux ISO"
curl -f#SL -o "metal-amd64.iso" "$URL"
echo -en "\e[1A\e[0K"
FILE="metal-amd64.iso"
msg_ok "Downloaded ${CL}${BL}${FILE}${CL}"

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  ;;
esac

# Allocate EFI disk
DISK0=vm-${VMID}-disk-0${DISK_EXT:-}
DISK0_REF=${STORAGE}:${DISK_REF:-}${DISK0}

msg_info "Creating a Talos Linux VM"
# Create VM with recommended Talos settings:
# - BIOS: ovmf (UEFI)
# - Machine: q35
# - SCSI Controller: virtio-scsi-pci (NOT virtio-scsi-single)
# - Network: virtio
# - Enable QEMU guest agent (with custom ISO that includes it)
# - Disable ballooning (balloon=0)
# - Serial console for troubleshooting
qm create $VMID \
  -agent 1 \
  ${MACHINE} \
  -tablet 0 \
  -localtime 1 \
  -bios ovmf \
  ${CPU_TYPE} \
  -cores $CORE_COUNT \
  -memory $RAM_SIZE \
  -balloon 0 \
  -name $HN \
  -tags talos \
  -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU \
  -onboot 1 \
  -ostype l26 \
  -scsihw virtio-scsi-pci \
  -serial0 socket

# Allocate and create EFI disk (4MB)
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null

# Create main disk for Talos installation
qm set $VMID \
  -efidisk0 ${DISK0_REF}${FORMAT} \
  -scsi0 ${STORAGE}:${DISK_SIZE},${DISK_CACHE}iothread=1 \
  -boot order=scsi0 >/dev/null

# Upload ISO to local storage and attach as CD-ROM
msg_info "Uploading Talos ISO to Proxmox storage"
UPLOAD_ISO_PATH="/var/lib/vz/template/iso/talos-${var_version}-metal-amd64.iso"
cp ${FILE} ${UPLOAD_ISO_PATH}
msg_ok "ISO uploaded to ${UPLOAD_ISO_PATH}"

# Attach ISO to VM
qm set $VMID -ide2 local:iso/talos-${var_version}-metal-amd64.iso,media=cdrom >/dev/null

DESCRIPTION=$(
  cat <<EOF
<div align='center'>
  <h2 style='font-size: 24px; margin: 20px 0;'>Talos Linux VM</h2>
  
  <p style='margin: 16px 0;'>
    Version: ${var_version}<br/>
    Machine Type: q35 (UEFI)<br/>
    SCSI Controller: VirtIO SCSI<br/>
    QEMU Guest Agent: Enabled
  </p>

  <h3>Next Steps:</h3>
  <ol style='text-align: left; display: inline-block;'>
    <li>Start the VM and note the IP address from console</li>
    <li>Generate machine configs: <code>talosctl gen config talos-cluster https://\\\$CONTROL_PLANE_IP:6443</code></li>
    <li>Apply config: <code>talosctl apply-config --insecure --nodes \\\$IP --file controlplane.yaml</code></li>
    <li>Bootstrap: <code>talosctl bootstrap</code></li>
    <li>Get kubeconfig: <code>talosctl kubeconfig .</code></li>
  </ol>

  <p style='margin: 16px 0;'>
    <a href='https://www.talos.dev/latest/talos-guides/install/virtualized-platforms/proxmox/' target='_blank' rel='noopener noreferrer'>
      Talos Proxmox Documentation
    </a>
  </p>
</div>
EOF
)
qm set "$VMID" -description "$DESCRIPTION" >/dev/null

msg_ok "Created a Talos Linux VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Talos Linux VM"
  qm start $VMID
  msg_ok "Started Talos Linux VM"
  echo ""
  echo -e "${INFO}${YW}VM is booting into maintenance mode${CL}"
  echo -e "${INFO}${YW}Check the console for the IP address${CL}"
  echo ""
  echo -e "${INFO}Next steps:${CL}"
  echo -e "  1. Note the IP address from VM console (press Enter at boot menu)"
  echo -e "  2. Generate configs: ${BL}talosctl gen config talos-cluster https://\$IP:6443${CL}"
  echo -e "  3. Apply config: ${BL}talosctl apply-config --insecure --nodes \$IP --file controlplane.yaml${CL}"
  echo -e "  4. Bootstrap: ${BL}talosctl bootstrap${CL}"
  echo -e "  5. Get kubeconfig: ${BL}talosctl kubeconfig .${CL}"
  echo ""
fi

msg_ok "Completed Successfully!\n"
echo "More Info at https://www.talos.dev/latest/talos-guides/install/virtualized-platforms/proxmox/"