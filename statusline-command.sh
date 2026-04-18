#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
hour_pct=$(echo "$input" | jq -r '(.rate_limits["5h"] // .rate_limits.five_hour // .rate_limits.hour).used_percentage // empty')
week_pct=$(echo "$input" | jq -r '(.rate_limits["7d"] // .rate_limits.seven_day // .rate_limits.week).used_percentage // empty')
hour_reset=$(echo "$input" | jq -r '(.rate_limits["5h"] // .rate_limits.five_hour // .rate_limits.hour).resets_at // empty')

dir=$(basename "$cwd")

RESET=$'\033[0m'
DIM=$'\033[2;37m'
WHITE=$'\033[0;37m'
BOLD_WHITE=$'\033[1;37m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
BOLD_RED=$'\033[1;31m'

branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.hooksPath=/dev/null symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

build_bar() {
  local pct=$1
  local filled=$(( pct * 8 / 100 ))
  local color
  if   [ "$pct" -ge 90 ]; then color="$BOLD_RED"
  elif [ "$pct" -ge 75 ]; then color="$RED"
  elif [ "$pct" -ge 50 ]; then color="$YELLOW"
  else                          color="$CYAN"
  fi
  local i=1 result=""
  while [ $i -le 8 ]; do
    if [ $i -le $filled ]; then result="${result}${color}▊${RESET}"
    else                        result="${result}${DIM}▊${RESET}"
    fi
    i=$(( i + 1 ))
  done
  printf '%s' "$result"
}

visible_len() {
  printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=en_US.UTF-8 wc -m | tr -d ' \n'
}

format_reset() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  [[ "$epoch" =~ ^[0-9]+$ ]] || return
  local h ampm
  h=$(date -r "$epoch" "+%I" 2>/dev/null) || return
  h=$((10#$h))
  ampm=$(date -r "$epoch" "+%p" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  printf '%d%s' "$h" "$ampm"
}

dir_sec="${BOLD_WHITE}${dir}${RESET}"
model_sec="  ${WHITE}${model}${RESET}"

bars_sec=""
if [ -n "$ctx_pct" ]; then
  pct=$(printf "%.0f" "$ctx_pct")
  bars_sec="${bars_sec}  ${DIM}ctx${RESET} $(build_bar "$pct") ${WHITE}${pct}%${RESET}"
fi
if [ -n "$hour_pct" ]; then
  pct=$(printf "%.0f" "$hour_pct")
  bars_sec="${bars_sec}  ${DIM}5h${RESET} $(build_bar "$pct") ${WHITE}${pct}%${RESET}"
fi
if [ -n "$week_pct" ]; then
  pct=$(printf "%.0f" "$week_pct")
  bars_sec="${bars_sec}  ${DIM}7d${RESET} $(build_bar "$pct") ${WHITE}${pct}%${RESET}"
fi

reset_sec=""
reset_str=$(format_reset "$hour_reset")
[ -n "$reset_str" ] && reset_sec="  ${DIM}reset${RESET} ${WHITE}${reset_str}${RESET}"

cols=$(tput cols 2>/dev/null)
[ -z "$cols" ] && cols="${COLUMNS:-120}"
[[ "$cols" =~ ^[0-9]+$ ]] || cols=120

fixed_str="${dir_sec}${model_sec}${bars_sec}${reset_sec}"
fixed_len=$(visible_len "$fixed_str")
[[ "$fixed_len" =~ ^[0-9]+$ ]] || fixed_len=0

display_branch=""
if [ -n "$branch" ]; then
  avail=$(( cols - fixed_len - 2 ))
  branch_len=${#branch}
  if [ "$avail" -ge "$branch_len" ]; then
    display_branch="$branch"
  elif [ "$avail" -ge 2 ]; then
    display_branch="${branch:0:$((avail - 1))}…"
  fi
fi

out="${dir_sec}"
[ -n "$display_branch" ] && out="${out}  ${GREEN}${display_branch}${RESET}"
out="${out}${model_sec}${bars_sec}${reset_sec}"

printf '%s' "$out"
