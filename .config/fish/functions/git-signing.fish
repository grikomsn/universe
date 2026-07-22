function git-signing --description "Select the Git SSH signing backend"
    set -l private_config $HOME/.gitconfig-private

    switch "$argv[1]"
        case local
            command git config --file $private_config gpg.format ssh
            command git config --file $private_config gpg.ssh.program /usr/bin/ssh-keygen
            command git config --file $private_config user.signingkey $HOME/.ssh/id_ed25519
            chmod 600 $private_config
            echo "Git signing backend: local ($HOME/.ssh/id_ed25519)"

        case 1password op
            for key in gpg.format gpg.ssh.program user.signingkey
                command git config --file $private_config --unset-all $key 2>/dev/null
            end
            echo "Git signing backend: 1Password"

        case status
            command git config --show-origin --get-regexp \
                '^(gpg\.format|gpg\.ssh\.program|user\.signingkey)$'

        case '*'
            echo "Usage: git-signing {local|1password|status}" >&2
            return 2
    end
end
