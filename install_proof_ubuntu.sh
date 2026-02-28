#!/data/data/com.termux/files/usr/bin/bash

# Unofficial Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths and constants
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG_FILE="$HOME/termux_proof_setup.log"
TEMP_DIR=$(mktemp -d)
DISTRO="ubuntu"
DISPLAY_NUM=":0"
ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO"
BASE_RAW_URL="https://raw.githubusercontent.com/brfluidpri/Termux_XFCE_ubuntu/main"

exec 2>>"$LOG_FILE"

print_status() {
  local status=$1
  local message=$2
  case "$status" in
    ok) echo -e "${GREEN}✓${NC} $message" ;;
    warn) echo -e "${YELLOW}!${NC} $message" ;;
    *) echo -e "${RED}✗${NC} $message" ;;
  esac
}

finish() {
  local ret=$?
  if [ $ret -ne 0 ] && [ $ret -ne 130 ]; then
    echo
    echo -e "${RED}ERROR: 설치 중 문제가 발생했습니다 / An issue occurred during setup.${NC}"
    echo -e "${YELLOW}로그 확인: $LOG_FILE${NC}"
  fi
  rm -rf "$TEMP_DIR"
}

trap finish EXIT

pd_login() {
  pd login "$DISTRO" --shared-tmp -- env DISPLAY="$DISPLAY_NUM" "$@"
}

detect_termux() {
  local errors=0

  echo -e "\n${BLUE}╔════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   System Compatibility Check       ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════╝${NC}\n"

  if [[ "$(uname -o)" = "Android" ]]; then
    print_status "ok" "Android: $(getprop ro.build.version.release)"
  else
    print_status "error" "Android 환경이 아닙니다 / Not running on Android"
    ((errors++))
  fi

  local arch
  arch=$(uname -m)
  if [[ "$arch" = "aarch64" ]]; then
    print_status "ok" "Architecture: $arch"
  else
    print_status "error" "Unsupported architecture: $arch (required: aarch64)"
    ((errors++))
  fi

  if [[ -d "$PREFIX" ]]; then
    print_status "ok" "Termux PREFIX detected"
  else
    print_status "error" "Termux PREFIX not found"
    ((errors++))
  fi

  local free_space_h
  free_space_h=$(df -h "$HOME" | awk 'NR==2 {print $4}')
  if [[ $(df "$HOME" | awk 'NR==2 {print $4}') -gt 4194304 ]]; then
    print_status "ok" "Available storage: $free_space_h"
  else
    print_status "warn" "Low storage: $free_space_h (4GB+ recommended)"
  fi

  local total_ram
  total_ram=$(free -m | awk 'NR==2 {print $2}')
  if [[ $total_ram -gt 2048 ]]; then
    print_status "ok" "RAM: ${total_ram}MB"
  else
    print_status "warn" "Low RAM: ${total_ram}MB (2GB+ recommended)"
  fi

  if [[ $errors -eq 0 ]]; then
    echo -e "\n${GREEN}요구 사항 확인 완료 / Requirements look good.${NC}"
    return 0
  fi

  echo -e "\n${RED}치명적 오류 $errors개 발견 / Found $errors blocking error(s).${NC}"
  return 1
}

ensure_storage_access() {
  if [ -d "$HOME/storage" ]; then
    print_status "ok" "Storage access already granted"
    return 0
  fi

  echo -e "${YELLOW}Termux 저장소 접근 권한을 허용해주세요 / Please grant storage access.${NC}"
  termux-setup-storage
}

append_once() {
  local file=$1
  local marker=$2
  local block=$3
  if ! grep -Fq "$marker" "$file" 2>/dev/null; then
    printf '\n%s\n' "$block" >> "$file"
  fi
}

run_step() {
  local title=$1
  shift
  echo -e "\n${BLUE}==>${NC} $title"
  "$@"
  print_status "ok" "$title"
}

main() {
  clear
  echo -e "\n${BLUE}╔════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   XFCE + Ubuntu Proof Installer    ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════╝${NC}\n"

  if ! detect_termux; then
    exit 1
  fi

  echo -e "${GREEN}이 스크립트는 Termux XFCE + Ubuntu proot를 설치합니다.${NC}"
  echo -e "${GREEN}This installer sets up Termux XFCE + Ubuntu proot.${NC}\n"
  echo -e "${YELLOW}Repository base: ${BASE_RAW_URL}${NC}"
  echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel${NC}"
  read -r

  printf "사용자 이름(id)을 입력하세요 / Enter username: " > /dev/tty
  read -r username < /dev/tty

  run_step "Change package repository" termux-change-repo
  run_step "Ensure storage access" ensure_storage_access
  run_step "Package index update" pkg update -y -o Dpkg::Options::=--force-confold
  run_step "Package upgrade" pkg upgrade -y -o Dpkg::Options::=--force-confold

  mkdir -p "$HOME/.termux"
  if [ ! -f "$HOME/.termux/termux.properties" ]; then
    touch "$HOME/.termux/termux.properties"
  fi
  sed -i 's/^#\?\s*allow-external-apps\s*=.*/allow-external-apps = true/' "$HOME/.termux/termux.properties" || true

  local deps=(wget curl git unzip proot-distro x11-repo tur-repo pulseaudio)
  local missing=()
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    run_step "Install dependencies" pkg install -y "${missing[@]}" -o Dpkg::Options::=--force-confold
  else
    print_status "ok" "Dependencies already installed"
  fi

  mkdir -p "$HOME/Desktop" "$HOME/Downloads"

  local bashrc_block
  bashrc_block=$(cat <<EOF
# >>> termux-xfce-ubuntu-proof >>>
alias ubuntu='proot-distro login $DISTRO --user $username --shared-tmp'
alias debian='proot-distro login $DISTRO --user $username --shared-tmp'
export DISPLAY=$DISPLAY_NUM
# <<< termux-xfce-ubuntu-proof <<<
EOF
)
  append_once "$PREFIX/etc/bash.bashrc" "# >>> termux-xfce-ubuntu-proof >>>" "$bashrc_block"

  chmod +x "$SCRIPT_DIR/xfce.sh" "$SCRIPT_DIR/etc.sh" "$SCRIPT_DIR/proot.sh" "$SCRIPT_DIR/utils.sh"

  if [ -f "$SCRIPT_DIR/cleanup_proof_env.sh" ]; then
    chmod +x "$SCRIPT_DIR/cleanup_proof_env.sh"
  fi

  run_step "Install XFCE phase (local xfce.sh)" "$SCRIPT_DIR/xfce.sh" "$username"
  run_step "Apply environment phase (local etc.sh)" "$SCRIPT_DIR/etc.sh"
  run_step "Install Ubuntu proot phase (local proot.sh)" "$SCRIPT_DIR/proot.sh" "$username"
  run_step "Install utilities phase (local utils.sh)" "$SCRIPT_DIR/utils.sh"

  if [ -f "$SCRIPT_DIR/cleanup_proof_env.sh" ]; then
    run_step "Cleanup duplicated proof config" "$SCRIPT_DIR/cleanup_proof_env.sh"
    cp "$SCRIPT_DIR/cleanup_proof_env.sh" "$PREFIX/bin/proof-cleanup"
    chmod +x "$PREFIX/bin/proof-cleanup"
  else
    print_status "warn" "cleanup_proof_env.sh not found, skipping cleanup step"
  fi

  if [ -f "$SCRIPT_DIR/temp_background.sh" ]; then
    chmod +x "$SCRIPT_DIR/temp_background.sh"
    run_step "Apply background workaround (temp_background.sh)" "$SCRIPT_DIR/temp_background.sh"
  else
    print_status "warn" "temp_background.sh not found, skipping background workaround"
  fi

  # Install Termux-X11 APK into Downloads for user install
  run_step "Download Termux-X11 APK" wget https://github.com/termux/termux-x11/releases/download/nightly/app-arm64-v8a-debug.apk -O "$HOME/storage/downloads/app-arm64-v8a-debug.apk"
  termux-open "$HOME/storage/downloads/app-arm64-v8a-debug.apk" || true

  source "$PREFIX/etc/bash.bashrc"
  termux-reload-settings || true

  clear
  echo -e "\n${BLUE}╔════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║         Setup Complete!            ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════╝${NC}\n"

  echo -e "${GREEN}Available Commands / 사용 가능한 명령어:${NC}"
  echo -e "${YELLOW}start${NC}         - XFCE 시작 / Start XFCE desktop (proof wrapper)"
  echo -e "${YELLOW}startXFCE${NC}     - 직접 실행 / Direct launcher"
  echo -e "${YELLOW}ubuntu${NC}        - Ubuntu proot 로그인 / Enter Ubuntu proot"
  echo -e "${YELLOW}debian${NC}        - ubuntu 호환 별칭 / Compatibility alias"
  echo -e "${YELLOW}prun${NC}          - Termux에서 Ubuntu 앱 실행 / Run Ubuntu app from Termux"
  echo -e "${YELLOW}cp2menu${NC}       - 메뉴 항목 복사/삭제 / Manage menu entries"
  echo -e "${YELLOW}app-installer${NC} - 앱 설치 유틸 / App installer utility"
  echo -e "${YELLOW}proof-cleanup${NC} - 중복 설정 정리 / Cleanup duplicate proof config"
  echo -e "${YELLOW}proof-cleanup -n${NC} - 미리보기 / Preview cleanup without changes"

  echo -e "\n${YELLOW}설치 완료 / Installation complete.${NC}"
}

main
