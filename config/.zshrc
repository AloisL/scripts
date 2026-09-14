# ----- zsh -----
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh
# ----- zsh -----

# ----- starship -----
eval "$(starship init zsh)"
# ----- starship -----

# ----- nvm -----
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
# ----- nvm -----

# ----- pnpm -----
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# ----- pnpm -----

# ----- docker -----
fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
# ----- docker -----

# ----- vite-plus -----
. "$HOME/.vite-plus/env"
# ----- vite-plus -----

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.fastlane/bin:$PATH"
