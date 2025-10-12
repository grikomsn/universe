function cat --wraps=bat --description 'alias cat bat'
    if command -q bat
        bat $argv
    else
        command cat $argv
    end
end
