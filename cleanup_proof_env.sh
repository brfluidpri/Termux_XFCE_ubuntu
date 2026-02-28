#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail
IFS=$'\n\t'

DISTRO="ubuntu"
ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/${DISTRO}"
TERMUX_BASHRC="${PREFIX}/etc/bash.bashrc"
DRY_RUN=0
CHANGED_FILES=0

print_info() {
  echo "[cleanup] $1"
}

print_usage() {
  cat <<'EOF'
Usage: cleanup_proof_env.sh [--dry-run|-n] [--help|-h]

Options:
  --dry-run, -n   Preview changes without modifying files
  --help, -h      Show this help
EOF
}

report_change() {
  local file=$1
  CHANGED_FILES=$((CHANGED_FILES + 1))
  if [ "$DRY_RUN" -eq 1 ]; then
    print_info "[preview] would update: $file"
  else
    print_info "updated: $file"
  fi
}

apply_if_changed() {
  local file=$1
  local temp_file=$2

  if cmp -s "$file" "$temp_file"; then
    rm -f "$temp_file"
    return 1
  fi

  report_change "$file"
  if [ "$DRY_RUN" -eq 1 ]; then
    rm -f "$temp_file"
  else
    mv "$temp_file" "$file"
  fi
  return 0
}

block_dedupe() {
  local file=$1
  local start_marker=$2
  local end_marker=$3

  [ -f "$file" ] || return 0

  awk -v start="$start_marker" -v end="$end_marker" '
    BEGIN {
      in_block=0
      seen_block=0
      keep=1
    }
    {
      if (index($0, start) > 0) {
        in_block=1
        if (seen_block == 0) {
          seen_block=1
          keep=1
          print
        } else {
          keep=0
        }
        next
      }

      if (in_block == 1) {
        if (keep == 1) {
          print
        }
        if (index($0, end) > 0) {
          in_block=0
          keep=1
        }
        next
      }

      print
    }
  ' "$file" > "${file}.tmp"

  apply_if_changed "$file" "${file}.tmp" || true
}

line_dedupe_keep_first() {
  local file=$1
  local target_line=$2

  [ -f "$file" ] || return 0

  awk -v target="$target_line" '
    {
      if ($0 == target) {
        count++
        if (count == 1) {
          print
        }
        next
      }
      print
    }
  ' "$file" > "${file}.tmp"

  apply_if_changed "$file" "${file}.tmp" || true
}

normalize_startxfce_wrapper() {
  local wrapper_path="${PREFIX}/bin/startXFCE"
  if [ -f "$wrapper_path" ] && ! head -n 1 "$wrapper_path" | grep -q '^#!/'; then
    cat <<'EOF' > "${wrapper_path}.tmp"
#!/data/data/com.termux/files/usr/bin/bash
exec "$HOME/.shortcuts/startXFCE" "$@"
EOF
    if apply_if_changed "$wrapper_path" "${wrapper_path}.tmp"; then
      if [ "$DRY_RUN" -eq 0 ]; then
        chmod +x "$wrapper_path"
      fi
    fi
  fi
}

cleanup_termux_bashrc() {
  [ -f "$TERMUX_BASHRC" ] || return 0

  block_dedupe "$TERMUX_BASHRC" "# >>> termux-xfce-ubuntu-proof >>>" "# <<< termux-xfce-ubuntu-proof <<<"
  block_dedupe "$TERMUX_BASHRC" "# >>> termux-xfce-proof-xfce >>>" "# <<< termux-xfce-proof-xfce <<<"
  block_dedupe "$TERMUX_BASHRC" "# >>> termux-xfce-proof-fancybash >>>" "# <<< termux-xfce-proof-fancybash <<<"
  block_dedupe "$TERMUX_BASHRC" "# >>> termux-xfce-proof-etc >>>" "# <<< termux-xfce-proof-etc <<<"

  line_dedupe_keep_first "$TERMUX_BASHRC" "source $HOME/.fancybash.sh"
  line_dedupe_keep_first "$TERMUX_BASHRC" "alias ll='ls -alhF'"
  line_dedupe_keep_first "$TERMUX_BASHRC" "alias shutdown='kill -9 -1'"
  line_dedupe_keep_first "$TERMUX_BASHRC" "alias zink='MESA_LOADER_DRIVER_OVERRIDE=zink TU_DEBUG=noconform '"
}

cleanup_proot_bashrcs() {
  [ -d "${ROOTFS}/home" ] || return 0

  for user_home in "${ROOTFS}"/home/*; do
    [ -d "$user_home" ] || continue
    local user_bashrc="${user_home}/.bashrc"
    [ -f "$user_bashrc" ] || continue

    block_dedupe "$user_bashrc" "# >>> termux-xfce-proof-proot >>>" "# <<< termux-xfce-proof-proot <<<"
    block_dedupe "$user_bashrc" "# >>> termux-xfce-proof-proot-fancy >>>" "# <<< termux-xfce-proof-proot-fancy <<<"

    line_dedupe_keep_first "$user_bashrc" "source ~/.fancybash.sh"
    line_dedupe_keep_first "$user_bashrc" "export DISPLAY=:0"
  done
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run|-n)
        DRY_RUN=1
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      *)
        print_info "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
    shift
  done

  if [ "$DRY_RUN" -eq 1 ]; then
    print_info "Preview mode enabled (no file changes will be made)"
  fi

  print_info "Cleaning duplicated proof config blocks"
  cleanup_termux_bashrc
  cleanup_proot_bashrcs
  normalize_startxfce_wrapper

  if [ "$CHANGED_FILES" -eq 0 ]; then
    print_info "No changes needed"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      print_info "Preview complete: ${CHANGED_FILES} file(s) would be updated"
    else
      print_info "Done: ${CHANGED_FILES} file(s) updated"
    fi
  fi
}

main "$@"
