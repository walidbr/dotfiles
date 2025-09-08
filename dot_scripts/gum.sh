#!/usr/bin/env bash
# ops-gum: interactive ops helper using "gum" dialogs
# deps: gum, docker (optional for docker flows), systemctl (for systemd), ss or lsof

set -Eeuo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need gum

#######################################
# Helpers
#######################################

hr() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' -; }

confirm() { gum confirm "$1"; }

run() {
  # Run a command with a spinner and show the command.
  local title="$1"; shift
  gum spin --title "$title" -- bash -lc "$*"
}

open_shell() {
  # Open a bash shell inside a container
  local cid="$1"
  run "Opening shell in $cid" "docker exec -it '$cid' bash || docker exec -it '$cid' sh"
}

#######################################
# Docker Images Flow
#######################################
docker_images_menu() {
  need docker
  while :; do
    # --no-trunc to ensure full SHAs are shown
    mapfile -t rows < <(docker images --no-trunc --format '{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}')
    if [ "${#rows[@]}" -eq 0 ]; then
      gum style --foreground 212 "No images found."
      return
    fi

    # table header
    local header="IMAGE_ID(full SHA)\tREPO\tTAG\tSIZE"
    local pick
    pick=$(printf "%s\n%s\n" "$header" "${rows[@]}" \
      | gum table --height 15 --border normal --print --columns "IMAGE_ID(full SHA),REPO,TAG,SIZE" \
      | tail -n +2) || return

    local img_id repo tag
    img_id=$(printf "%s" "$pick" | awk -F'\t' '{print $1}')
    repo=$(printf "%s" "$pick" | awk -F'\t' '{print $2}')
    tag=$(printf "%s" "$pick" | awk -F'\t' '{print $3}')
    local ref="${repo}:${tag}"

    local action
    action=$(printf "inspect\nremove (rmi)\ntag\nsave (tar)\nback\n" \
      | gum choose --header "Image: $ref") || return

    case "$action" in
      inspect)
        docker image inspect "$img_id" | gum pager
        ;;
      "remove (rmi)")
        confirm "Remove image $ref ?" && run "docker rmi $ref" "docker rmi '$ref'"
        ;;
      tag)
        newref=$(gum input --placeholder "new-repo:new-tag") || continue
        [ -n "$newref" ] && run "docker tag $ref -> $newref" "docker tag '$ref' '$newref'"
        ;;
      "save (tar)")
        out=$(gum input --placeholder "output tar path (e.g., /tmp/img.tar)") || continue
        [ -n "$out" ] && run "docker save $ref > $out" "docker save '$ref' -o '$out'"
        ;;
      back) return ;;
    esac
  done
}

#######################################
# Docker Containers Flow
#######################################
docker_ps_menu() {
  need docker
  while :; do
    # show running; allow switching to all
    local scope
    scope=$(printf "running\nall\nback\n" | gum choose --header "Which containers?") || return
    [ "$scope" = "back" ] && return
    local flag="-a"; [ "$scope" = "running" ] && flag=""

    mapfile -t rows < <(docker ps $flag --no-trunc --format '{{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}')
    if [ "${#rows[@]}" -eq 0 ]; then
      gum style --foreground 212 "No containers ($scope)."
      continue
    fi

    local header="CONTAINER_ID(full)\tIMAGE\tNAME\tSTATUS\tPORTS"
    local pick
    pick=$(printf "%s\n%s\n" "$header" "${rows[@]}" \
      | gum table --height 15 --border normal --print \
      --columns "CONTAINER_ID(full),IMAGE,NAME,STATUS,PORTS" \
      | tail -n +2) || continue

    local cid image name status ports
    cid=$(printf "%s" "$pick" | awk -F'\t' '{print $1}')
    image=$(printf "%s" "$pick" | awk -F'\t' '{print $2}')
    name=$(printf "%s" "$pick" | awk -F'\t' '{print $3}')
    status=$(printf "%s" "$pick" | awk -F'\t' '{print $4}')
    ports=$(printf "%s" "$pick" | awk -F'\t' '{print $5}')

    local action
    action=$(printf "logs (follow)\nexec shell\nstop\nstart\nrestart\nkill\ninspect\nback\n" \
      | gum choose --header "Container: $name  ($cid)") || continue

    case "$action" in
      "logs (follow)")
        gum style --bold "Ctrl-C to exit logs"
        docker logs -f "$cid"
        ;;
      "exec shell") open_shell "$cid" ;;
      stop)    confirm "Stop $name ?"    && run "docker stop $name"    "docker stop '$cid'";;
      start)   confirm "Start $name ?"   && run "docker start $name"   "docker start '$cid'";;
      restart) confirm "Restart $name ?" && run "docker restart $name" "docker restart '$cid'";;
      kill)
        sig=$(gum input --value "9" --placeholder "signal (e.g., 9, TERM, INT)") || continue
        [ -n "$sig" ] && run "docker kill -s $sig $name" "docker kill -s '$sig' '$cid'"
        ;;
      inspect) docker inspect "$cid" | gum pager ;;
      back) ;;
    esac
  done
}

#######################################
# Processes Flow
#######################################
proc_menu() {
  need ps
  while :; do
    # List top by CPU; include PID prominently
    # etimes = elapsed seconds, convert later for display
    mapfile -t rows < <(ps -eo pid,comm,user,pcpu,pmem,etimes --sort=-pcpu \
      | awk 'NR==1{next} {printf "%s\t%s\t%s\t%s\t%s\t%s\n",$1,$2,$3,$4,$5,$6}')
    if [ "${#rows[@]}" -eq 0 ]; then
      gum style --foreground 212 "No processes?"
      return
    fi

    local header="PID\tCMD\tUSER\tCPU%%\tMEM%%\tELAPSED(s)"
    local pick
    pick=$(printf "%s\n%s\n" "$header" "${rows[@]}" \
      | gum table --height 15 --border normal --print \
      --columns "PID,CMD,USER,CPU%,MEM%,ELAPSED(s)" \
      | tail -n +2) || return

    local pid cmd user cpu mem et
    pid=$(printf "%s" "$pick" | awk -F'\t' '{print $1}')
    cmd=$(printf "%s" "$pick" | awk -F'\t' '{print $2}')
    user=$(printf "%s" "$pick" | awk -F'\t' '{print $3}')
    cpu=$(printf "%s" "$pick" | awk -F'\t' '{print $4}')
    mem=$(printf "%s" "$pick" | awk -F'\t' '{print $5}')
    et=$(printf "%s" "$pick" | awk -F'\t' '{print $6}')

    local action
    action=$(printf "details\nports\nkill\nback\n" | gum choose --header "PID $pid  CMD $cmd  CPU $cpu%%  MEM $mem%%") || return

    case "$action" in
      details)
        # show full ps line + /proc info if present
        {
          echo "PID: $pid  USER: $user"
          ps -p "$pid" -o pid,ppid,comm,user,pcpu,pmem,etime,args
          echo
          [ -r "/proc/$pid/status" ] && { echo "== /proc/$pid/status =="; sed -n '1,50p' "/proc/$pid/status"; }
        } | gum pager
        ;;
      ports)
        if command -v lsof >/dev/null 2>&1; then
          sudo -n true 2>/dev/null || gum style --foreground 178 "Ports may require sudo for full details."
          (sudo lsof -Pan -p "$pid" -i 2>/dev/null || lsof -Pan -p "$pid" -i 2>/dev/null || true) | gum pager
        else
          sudo -n true 2>/dev/null || gum style --foreground 178 "Using ss; sudo may be required."
          (sudo ss -lntp 2>/dev/null || ss -lntp 2>/dev/null || true) | grep -E "pid=$pid," | gum pager || gum style "No listening ports for $pid"
        fi
        ;;
      kill)
        sig=$(gum input --value "9" --placeholder "signal (e.g., 9, TERM, INT)") || continue
        [ -n "$sig" ] && confirm "Kill -$sig PID $pid ?" && run "kill -$sig $pid" "kill -$sig '$pid'"
        ;;
      back) ;;
    esac
  done
}

#######################################
# systemctl Flow
#######################################
systemctl_menu() {
  need systemctl
  while :; do
    # list services; show loaded/active/sub states
    mapfile -t rows < <(systemctl list-units --type=service --all --no-legend --no-pager \
      | awk '{svc=$1; load=$2; active=$3; sub=$4; $1=$2=$3=$4=""; gsub(/^ +/,""); desc=$0; printf "%s\t%s\t%s\t%s\t%s\n",svc,load,active,sub,desc}')
    if [ "${#rows[@]}" -eq 0 ]; then
      gum style --foreground 212 "No systemd services found."
      return
    fi

    local header="SERVICE\tLOAD\tACTIVE\tSUB\tDESCRIPTION"
    local pick
    pick=$(printf "%s\n%s\n" "$header" "${rows[@]}" \
      | gum table --height 15 --border normal --print \
      --columns "SERVICE,LOAD,ACTIVE,SUB,DESCRIPTION" \
      | tail -n +2) || return

    local svc
    svc=$(printf "%s" "$pick" | awk -F'\t' '{print $1}')

    local action
    action=$(printf "status\nstart\nstop\nrestart\nenable\ndisable\njournal (follow)\nback\n" \
      | gum choose --header "$svc") || return

    case "$action" in
      status)   systemctl status "$svc" --no-pager | gum pager ;;
      start)    confirm "Start $svc ?"    && run "systemctl start $svc"   "sudo systemctl start '$svc' || systemctl start '$svc'";;
      stop)     confirm "Stop $svc ?"     && run "systemctl stop $svc"    "sudo systemctl stop '$svc' || systemctl stop '$svc'";;
      restart)  confirm "Restart $svc ?"  && run "systemctl restart $svc" "sudo systemctl restart '$svc' || systemctl restart '$svc'";;
      enable)   confirm "Enable $svc ?"   && run "systemctl enable $svc"  "sudo systemctl enable '$svc' || systemctl enable '$svc'";;
      disable)  confirm "Disable $svc ?"  && run "systemctl disable $svc" "sudo systemctl disable '$svc' || systemctl disable '$svc'";;
      "journal (follow)") journalctl -fu "$svc" ;;
      back) ;;
    esac
  done
}

#######################################
# Main Menu
#######################################
main_menu() {
  while :; do
    choice=$(printf "docker images\ndocker ps\nprocesses\nsystemctl\nquit\n" \
      | gum choose --cursor="➜" --header "Ops Hub") || exit 0
    case "$choice" in
      "docker images") docker_images_menu ;;
      "docker ps")     docker_ps_menu ;;
      "processes")     proc_menu ;;
      "systemctl")     systemctl_menu ;;
      "quit")          exit 0 ;;
    esac
  done
}

main_menu