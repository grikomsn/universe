if [[ -r "$HOME/.profile" ]]; then
  source "$HOME/.profile"
fi

if [[ $- == *i* && -r "$HOME/.bashrc" ]]; then
  source "$HOME/.bashrc"
fi
