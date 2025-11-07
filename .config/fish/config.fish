if string match -qi cachyos (uname -r)
    set -l CACHYOS_CONFIG_PATH /usr/share/cachyos-fish-config/cachyos-config.fish
    if test -f $CACHYOS_CONFIG_PATH
        source $CACHYOS_CONFIG_PATH
    end
end

if status is-interactive
    function fish_greeting
        # noop
    end
end

# Self-mutating script to remove LM Studio CLI section from $HOME/.config/fish/config.fish, resolving symlinks
set -l config_file "$HOME/.config/fish/config.fish"
set -l config_realpath "$(realpath "$config_file")"
if grep -q '^# Added by LM Studio CLI (lms)$' $config_realpath
    sed -i '' '/^# Added by LM Studio CLI (lms)$/,/^# End of LM Studio CLI section$/d' $config_realpath
end
