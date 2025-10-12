function vim --wraps=nvim --description 'alias vim nvim'
    if command -q nvim
        nvim $argv
    else
        command vim $argv
    end
end
