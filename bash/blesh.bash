# Load ble.sh only when the terminal can show a colored history suggestion.
blesh_color_count=0
if [[ -t 2 && ${TERM:-dumb} != dumb ]] && command -v tput > /dev/null 2>&1; then
    blesh_color_count=$(tput colors 2> /dev/null || printf '%s' 0)
fi

blesh_color_mode=
if [[ -t 2 && ${TERM:-dumb} != dumb ]]; then
    if [[ ${COLORTERM:-} == truecolor || ${COLORTERM:-} == 24bit || ${TERM:-} == *direct* ]]; then
        blesh_color_mode=truecolor
    elif [[ ${TERM:-} == *256color* || ( $blesh_color_count =~ ^[0-9]+$ && $blesh_color_count -ge 256 ) ]]; then
        blesh_color_mode=256
    fi
fi
unset blesh_color_count

if [[ -n $blesh_color_mode ]]; then
    source -- "$HOME/.config/basic-cli/blesh/ble.sh" --attach=none --rcfile "$HOME/.config/basic-cli/blerc"
    [[ ${BLE_VERSION-} ]] && ble-attach
fi
unset blesh_color_mode
