# sfz prompt
# by Mike Reinhardt: https://github.com/mreinhardt/sfz-prompt.zsh
#
# Based on Lean by Miek Gieben: https://github.com/miekg/lean
#
# MIT License

PROMPT_SFZ_CHAR=${PROMPT_SFZ_CHAR-">"}
PROMPT_SFZ_TMUX=${PROMPT_SFZ_TMUX-"™"}
PROMPT_SFZ_PATH_UNTRUNCATED=${PROMPT_SFZ_PATH_UNTRUNCATED-""}

# subzero color palette, names correspond to terminal names but may not
# represent actual color.
sfz_colors () {
    case $1 in
        grey)     echo "{234}";;
        bgrey)    echo "{060}";;
        red)      echo "{126}";;
        bred)     echo "{200}";;
        green)    echo "{035}";;
        bgreen)   echo "{048}";;
        yellow)   echo "{148}";;
        byellow)  echo "{190}";;
        blue)     echo "{025}";;
        bblue)    echo "{069}";;
        magenta)  echo "{092}";;
        bmagenta) echo "{099}";;
        cyan)     echo "{074}";;
        bcyan)    echo "{081}";;
        white)    echo "{153}";;
        bwhite)   echo "{195}";;
    esac
}

sfz_help() {
  cat <<'EOF'
This is a one line prompt that tries to stay out of your face. It utilizes
the right side prompt for most information, like the CWD. The left side of
the prompt is only a '>'. The only other information shown on the left are
the jobs numbers of background jobs. When the exit code of a process isn't
zero the prompt turns red. If a process takes more then 5 (default) seconds
to run the total running time is shown in the next prompt.

Currently there is no configuration possible.

You can invoke it thus:

  prompt sfz

EOF
}

# turns seconds into human readable time, 165392 => 1d 21h 56m 32s
sfz_human_time() {
    local tmp=$1
    local days=$(( tmp / 60 / 60 / 24 ))
    local hours=$(( tmp / 60 / 60 % 24 ))
    local minutes=$(( tmp / 60 % 60 ))
    local seconds=$(( tmp % 60 ))
    (( $days > 0 )) && echo -n "${days}d"
    (( $hours > 0 )) && echo -n "${hours}h"
    (( $minutes > 0 )) && echo -n "${minutes}m"
    echo "${seconds}s"
}

# return git repo status indicators
sfz_git_dirty() {
    # check if we're in a git repo
    command git rev-parse --is-inside-work-tree &>/dev/null || return
    # get set of status indicators
    local git_status="$(git status --porcelain --ignore-submodules | cut -c1-2 | grep -o . | sort -u | paste -s -d'\0' - | tr -d ' ')"
    # set ahead or behind upstream count
    local git_ahead="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d '\n')"
    local git_behind="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d '\n')"
    if [[ $git_ahead -gt 0 ]]; then
        local git_upstream_diff="%F$(sfz_colors bgreen)+$git_ahead"
    elif [[ $git_behind -gt 0 ]]; then
        local git_upstream_diff="%F$(sfz_colors bred)-$git_behind"
    else
        local git_upstream_diff=""
    fi
    [[ "${git_status}" == "" && "${git_upstream_diff}" == "" ]] && echo "" && return
    local sfz_git_status
    sfz_git_status=""
    if [[ "${git_upstream_diff}" ]]; then
        sfz_git_status="${sfz_git_status} ${git_upstream_diff}"
    fi
    if [[ "${git_status}" ]]; then
        # colorize indicators by status
        local partial_git_status=$(echo "${git_status}%f" | \
                                   sed -e "s/?/%F$(sfz_colors white)?%f/" \
                                       -e "s/M/%B%F$(sfz_colors byellow)M%f%b/" \
                                       -e "s/A/%B%F$(sfz_colors bgreen)A%f%b/" \
                                       -e "s/D/%B%F$(sfz_colors bred)D%f%b/" \
                                       -e "s/R/%F$(sfz_colors magenta)R%f/" \
                                       -e "s/C/%F$(sfz_colors cyan)C%f/" \
                                       -e "s/U/%B%F$(sfz_colors bblue)U%f%b/")
        if [[ -n $sfz_git_status ]]; then
            sfz_git_status="${partial_git_status}"
        else
            sfz_git_status="${sfz_git_status} ${partial_git_status}"
        fi
    fi
    echo -n "$sfz_git_status"
}

# displays the exec time of the last command if set threshold was exceeded
sfz_cmd_exec_time() {
    local stop=$EPOCHSECONDS
    local start=${sfz_global_cmd_timestamp:-$stop}
    local integer elapsed=$stop-$start
    (($elapsed > ${PROMPT_SFZ_CMD_MAX_EXEC_TIME:=5})) && sfz_human_time $elapsed
}

sfz_pwd() {
    local sfz_path="${PWD/$HOME/\~}"
    if [[ $PROMPT_SFZ_PATH_UNTRUNCATED ]]; then
        print "$sfz_path"
    else
        print "$sfz_path" | sed 's#\([.]*[^/]\)[^/]*/#\1/#g'
    fi
}

sfz_preexec() {
    sfz_global_cmd_timestamp=$EPOCHSECONDS

    # shows the current dir and executed command in the title when a process is active
    print -Pn "\e]0;"
    echo -nE "$(sfz_pwd) $PROMPT_SFZ_CHAR $2"
    print -Pn "\a"
}

# Add a color around a text
sfz_color() {
    if [[ "$2" != "" ]]; then
        echo "%F$(sfz_colors $1)$2%f"
    fi
}

# Add bold around a text
sfz_bold() {
    if [[ "$1" != "" ]]; then
        echo "%B$1%b"
    fi
}

# Get current location prompt part (cwd, prefixed by host on SSH session)
sfz_location() {
    if [[ "$SSH_CONNECTION" != '' ]]; then
        sfz_color byellow "%M:$(sfz_pwd)"
    else
        sfz_color byellow "$(sfz_pwd)"
    fi
}

# Get the error result of previous command
sfz_previous_error() {
    if [[ $sfz_global_previous_result -ne 0 ]]; then
        local result=$(sfz_color bred "=> %?")
        sfz_bold "$result"
    fi
}

# Get the duration of previous command, if more than 5 seconds
sfz_previous_duration() {
    local result=$(sfz_color bmagenta "$(sfz_cmd_exec_time)")
    sfz_bold "$result"
}

# Get the list of background jobs and their status
sfz_background_jobs() {
    if [[ -n $sfz_global_jobs ]]; then
        echo "%F$(sfz_colors bgrey)[%F$(sfz_colors magenta)"${(j:,:)sfz_global_jobs}"%F$(sfz_colors bgrey)]%f"
    fi
}

# Add a separator between fragments
sfz_separator() {
    local sep="$1"
    shift
    while [[ $# -gt 0 ]]; do
        if [[ "$1" != '' ]]; then
            echo -n "$1"
            if [[ $# -gt 1 ]]; then
                echo -n "$sep"
            fi
        fi
        shift
    done
}

# Get the summary line for previous command and background jobs
sfz_previous_info() {
    sfz_separator " " "$(sfz_previous_duration)" "$(sfz_previous_error)" "$(sfz_background_jobs)"
}

# Get the information about being inside a virtualenv
sfz_virtual_env() {
    if [[ "$VIRTUAL_ENV" != '' ]]; then
        sfz_color byellow "(${VIRTUAL_ENV:t})"
    elif [[ "$BUILDOUT_ENV" != '' ]]; then
        sfz_color byellow "(buildout)"
    fi
}

# Get the prompt indicator
sfz_prompt_indicator() {
    local tmux
    if [[ "$TMUX" != '' ]]; then
        tmux="$PROMPT_SFZ_TMUX"
    fi    

    sfz_color bblue "$(sfz_bold "$tmux$PROMPT_SFZ_CHAR")"
}

sfz_precmd() {
    sfz_global_previous_result=$?

    unset sfz_global_jobs
    local a
    for a (${(k)jobstates}) {
        local j=$jobstates[$a];i="${${(@s,:,)j}[2]}"
        sfz_global_jobs+=($a${i//[^+-]/})
    }

    vcs_info
    #rehash

    local prev=$(sfz_previous_info)
    local base=$(sfz_separator " " "$(sfz_location)" "$(sfz_virtual_env)" "$(sfz_prompt_indicator)")
    PROMPT="$(sfz_separator $'\n' "$prev" "$base") "

    RPROMPT=" %F$(sfz_colors green)$vcs_info_msg_0_$(sfz_git_dirty)"

    unset sfz_global_cmd_timestamp # reset value since `preexec` isn't always triggered
}

sfz_setup() {
    prompt_opts=(cr subst percent)

    zmodload zsh/datetime
    autoload -Uz add-zsh-hook
    autoload -Uz vcs_info

    add-zsh-hook precmd sfz_precmd
    add-zsh-hook preexec sfz_preexec

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:git*' formats ' %b'
    zstyle ':vcs_info:git*' actionformats ' %b|%a'
}

sfz_setup "$@"
