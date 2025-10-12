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
