set -gx ADBLOCK 1
set -gx CARGO_NET_GIT_FETCH_WITH_CLI true
set -gx DISABLE_OPENCOLLECTIVE 1
set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
set -gx GPG_TTY $TTY # https://stackoverflow.com/a/57591830/4273667
set -gx LANG "en_US.UTF-8"
set -gx LC_ALL "en_US.UTF-8"
set -gx PATH /usr/local/bin /usr/local/sbin $PATH
set -gx PATH $HOME/.local/bin $PATH
