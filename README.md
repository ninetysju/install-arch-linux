# install-arch-linux

### disable middle mouse
```bash
echo "pointer = 1 0 3 4 5 6 7 8 9 10" > ~/.Xmodmap
xmodmap ~/.Xmodmap
```

### check updates
```bash
#!/bin/bash
number=$(sudo pacman -Qu | wc -l)

if [[ $number -gt 0 ]]; then
  notify-send "There are $number updates available!"
fi
```
