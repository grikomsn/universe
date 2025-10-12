function dataurl --description 'convert a file to a data url'
    set -l mimeType (file -b --mime-type $argv[1])
    if string match -q "text/*" $mimeType
        set mimeType "$mimeType;charset=utf-8"
    end
    echo "data:$mimeType;base64,"(openssl base64 -in $argv[1] | tr -d '\n')
end
