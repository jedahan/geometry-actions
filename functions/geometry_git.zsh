# geometry_git - please see the readme for documentation on all features

(( $+commands[git] )) || return

geometry_git_stashes() {
  git rev-parse --quiet --verify refs/stash >/dev/null \
    && ansi ${GEOMETRY_GIT_COLOR_STASHES:="144"} ${GEOMETRY_GIT_SYMBOL_STASHES:="●"}
}

geometry_git_time() {
  local last_commit
  local now
  local seconds_since_last_commit
  last_commit=$(git log -1 --pretty=format:'%at' 2> /dev/null)

  [[ -z "$last_commit" ]] && ansi ${GEOMETRY_COLOR_NO_TIME:-default} ${GEOMETRY_GIT_NO_COMMITS_MESSAGE:-no-commits} && return

  now=$(date +%s)
  seconds_since_last_commit=$((now - last_commit))
  geometry::time $seconds_since_last_commit ${GEOMETRY_GIT_TIME_DETAILED:-false}
}

geometry_git_branch() {
  ansi ${GEOMETRY_GIT_COLOR_BRANCH:-242} $(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
}

geometry_git_status() {
  command git rev-parse --git-dir > /dev/null 2>&1 || return

  [[ -z "$(git status --porcelain --ignore-submodules HEAD)" ]] \
  && [[ -z "$(git ls-files --others --modified --exclude-standard $(git rev-parse --show-toplevel))" ]] \
  && ansi ${GEOMETRY_GIT_COLOR_DIRTY:-red} ${GEOMETRY_GIT_SYMBOL_DIRTY:-"⬡"} \
  || ansi ${GEOMETRY_GIT_COLOR_CLEAN:-green} ${GEOMETRY_GIT_SYMBOL_CLEAN:-"⬢"}
}

geometry_git_rebase() {
  local git_dir
  git_dir=$(git rev-parse --git-dir)
  [[ -d "$git_dir/rebase-merge" ]] || [[ -d "$git_dir/rebase-apply" ]] || return
  echo ${GEOMETRY_GIT_SYMBOL_REBASE:-"®"}
}

geometry_git_remote() {
  local unpushed=${GEOMETRY_GIT_SYMBOL_UNPUSHED:-"⇡"}
  local unpulled=${GEOMETRY_GIT_SYMBOL_UNPULLED:-"⇣"}
  local local_commit && local_commit=$(git rev-parse "@" 2>/dev/null)
  local remote_commit && remote_commit=$(git rev-parse "@{u}" 2>/dev/null)

  [[ $local_commit == "@" || $local_commit == $remote_commit ]] && return

  local common_base && common_base=$(git merge-base "@" "@{u}" 2>/dev/null) # last common commit
  [[ $common_base == $remote_commit ]] && echo $unpushed && return
  [[ $common_base == $local_commit ]]  && echo $unpulled && return

  echo "$unpushed $unpulled"
}

geometry_git_symbol() { echo ${(j: :):-$(geometry_git_rebase) $(geometry_git_remote)}; }

geometry_git_conflicts() {
  local _grep
  local conflicts conflict_list
  local file_count raw_file_count
  local total raw_total
  conflicts=$(git diff --name-only --diff-filter=U)

  [[ -z "$conflicts" ]] && return

  pushd -q $(git rev-parse --show-toplevel)

  _grep=${GEOMETRY_GIT_GREP:=${commands[rg]:=${commands[ag]:=${commands[grep]}}}}
  conflict_list=$($_grep -cH '^=======$' $conflicts)

  popd -q

  raw_file_count="${#${(@f)conflict_list}}"
  file_count=${raw_file_count##*( )}

  raw_total=$(echo $conflict_list | cut -d ':' -f2 | paste -sd+ - | bc)
  total=${raw_total##*(  )}

  [[ -z "$total" ]] && ansi ${GEOMETRY_GIT_COLOR_CONFLICTS_SOLVED:-green} ${GEOMETRY_GIT_SYMBOL_CONFLICTS_SOLVED:-"◆"} && return

  count="(${file_count}f|${total}c)"

  ansi ${GEOMETRY_GIT_COLOR_CONFLICTS_UNSOLVED:-red} "${GEOMETRY_GIT_SYMBOL_CONFLICTS_UNSOLVED:-'◈'} $count"
}

geometry_git() {
  command git rev-parse --git-dir > /dev/null 2>&1 || return

  $(command git rev-parse --is-bare-repository 2>/dev/null) \
    && ansi ${GEOMETRY_GIT_COLOR_BARE:=blue} ${GEOMETRY_GIT_SYMBOL_BARE:="⬢"} \
    && return

  local geometry_git_details && geometry_git_details=(
    $(geometry_git_conflicts)
    $(geometry_git_time)
    $(geometry_git_stashes)
    $(geometry_git_status)
  )

  local separator=${GEOMETRY_GIT_SEPARATOR:-" :: "}
  echo -n $(geometry_git_symbol) $(geometry_git_branch) ${(pj.$separator.)geometry_git_details}
}
