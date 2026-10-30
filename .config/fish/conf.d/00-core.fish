set -gx ADBLOCK 1
set -gx CARGO_NET_GIT_FETCH_WITH_CLI true
set -gx DISABLE_OPENCOLLECTIVE 1
set -gx DO_NOT_TRACK 1
set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
set -gx LANG "en_US.UTF-8"
set -gx LC_ALL "en_US.UTF-8"

# Session-scoped PATH: a global fish_user_paths shadows the universal one, so
# every fish_add_path in conf.d rebuilds PATH from this repo on each start
# instead of persisting into fish_variables, where entries for uninstalled
# tools lingered forever.
set -g fish_user_paths
fish_add_path /usr/local/bin /usr/local/sbin
fish_add_path $HOME/.local/bin

set -l onepassword_ssh_auth_sock "$HOME/.1password/agent.sock"
if not test -S $onepassword_ssh_auth_sock
    set -l macos_onepassword_ssh_auth_sock "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if test -S $macos_onepassword_ssh_auth_sock
        set onepassword_ssh_auth_sock $macos_onepassword_ssh_auth_sock
    end
end
if test -S $onepassword_ssh_auth_sock
    set -gx SSH_AUTH_SOCK $onepassword_ssh_auth_sock
end
