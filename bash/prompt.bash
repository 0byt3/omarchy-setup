# Bash prompt deployed by deploy-configuration.nu. Sourced from ~/.bashrc
# after Omarchy's own startup. Login shells install bash-preexec first, and
# Starship registers starship_precmd there. That hook redraws PS1 immediately
# before the prompt is shown, so it is removed before this prompt is set.
remove_starship_hook() {
    local array_name=$1
    local -n array=$array_name
    local hook
    local -a kept=()
    for hook in "${array[@]}"; do
        if [[ $hook != *starship_precmd* && $hook != *starship_preexec* ]]; then
            kept+=("$hook")
        fi
    done
    array=("${kept[@]}")
}

if [[ $(declare -p PROMPT_COMMAND 2> /dev/null) == declare\ -a* ]]; then
    remove_starship_hook PROMPT_COMMAND
elif [[ ${PROMPT_COMMAND-} == *starship_precmd* ]]; then
    if [[ -n ${STARSHIP_PROMPT_COMMAND-} ]]; then
        PROMPT_COMMAND=$STARSHIP_PROMPT_COMMAND
    else
        unset PROMPT_COMMAND
    fi
fi
unset STARSHIP_PROMPT_COMMAND
if [[ $(declare -p precmd_functions 2> /dev/null) == declare\ -a* ]]; then
    remove_starship_hook precmd_functions
fi
if [[ $(declare -p preexec_functions 2> /dev/null) == declare\ -a* ]]; then
    remove_starship_hook preexec_functions
fi
if declare -F starship_precmd > /dev/null; then
    PS2='> '
fi
unset -f starship_precmd starship_preexec starship_preexec_all starship_preexec_ps0 remove_starship_hook

prompt_color_count=0
if [[ -t 2 && ${TERM:-dumb} != dumb ]] && command -v tput > /dev/null 2>&1; then
    prompt_color_count=$(tput colors 2> /dev/null || printf '%s' 0)
fi

PS1='╭─| \u@\h: \w\n╰─ bash$ '
if [[ -t 2 && ${TERM:-dumb} != dumb ]]; then
    if [[ ${COLORTERM:-} == truecolor || ${COLORTERM:-} == 24bit || ${TERM:-} == *direct* ]]; then
        PS1='╭─| \[\e[38;2;157;206;212m\]\u@\h\[\e[39m\]: \[\e[38;2;232;196;160m\]\w\[\e[39m\]\n╰─ \[\e[38;2;201;177;224m\]bash\[\e[39m\]$ '
    elif [[ ${TERM:-} == *256color* || ( $prompt_color_count =~ ^[0-9]+$ && $prompt_color_count -ge 256 ) ]]; then
        PS1='╭─| \[\e[38;5;152m\]\u@\h\[\e[39m\]: \[\e[38;5;223m\]\w\[\e[39m\]\n╰─ \[\e[38;5;183m\]bash\[\e[39m\]$ '
    fi
fi
unset prompt_color_count
