# Terminal

[Starship homepage](https://starship.rs)

[Oh My Zsh homepage](https://ohmyz.sh)

## Installation

### JetBrains Mono NF 14

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

### Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Starship

```bash
brew install starship
```

## Configuration

### .zshrc

```bash
# ----- zsh -----
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh
# ----- zsh -----

# ----- starship -----
eval "$(starship init zsh)"
# ----- starship -----
```
