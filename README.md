https://github.com/Wilfred/difftastic

https://github.com/dandavison/delta

https://github.com/sharkdp/bat

https://github.com/zyedidia/micro

https://neovim.io/

credits:
- ai


```shell
DOTFILES_ROOT="/usr/local/share/dotfiles-system"
source "${DOTFILES_ROOT}/system/scripts/scripts.sh" 2>/dev/null || {
  echo "Error: Failed to load script utilities" >&2
  exit 1
}
```

```shell
bash <(curl -s https://raw.githubusercontent.com/powercasgamer/dotfiles/main/system.sh)
```