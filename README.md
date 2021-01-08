# Install Arch Linux
This is highly opinionated and my own personal setup. It's possible to change every script with nano before running it aswell.

You should read https://wiki.archlinux.org/index.php/installation_guide before using this to understand what's happening.

1. Install base system
    ```bash
      $ curl -L /install-base.sh > install-base.sh
      $ sh install-base.sh
    ```

2. Configure and install desktop(xfce), if wireless run `$ nmtui` first
    ```bash
      $ curl -L /install-xfce.sh > install-xfce.sh
      $ sh install-xfce.sh
    ```

3. Configure xfce
    ```bash
      $ curl -L /configure-xfce.sh > configure-xfce.sh
      $ sh configure-xfce.sh
    ```

4. Install applications
    ```bash
      $ curl -L /install-applications.sh > install-applications.sh
      $ sh install-applications.sh
    ```

5. Remove scripts
    `~/install-xfce.sh`
    `~/configure-xfce.sh`
    `~/install-applications.sh`

---

### Theming
mousepad:
  - Font: FreeMono Regular 12
  - Color Scheme: Classic

xfce4-terminal
  - Font: FreeMono Regular 14
  - Background: Transparent, 0.80
  - Colors: Dark Pastels

---

#### disable middle mouse
```bash
$ echo "pointer = 1 0 3 4 5 6 7 8 9 10" > ~/.Xmodmap
$ xmodmap ~/.Xmodmap
```

#### kill window
https://wiki.archlinux.org/index.php/xfce#Kill_window_shortcut
```bash
$ sh -c "xkill -id $(xprop -root -notype | sed -n '/^_NET_ACTIVE_WINDOW/ s/^.*# *\|\,.*$//g p')"
```

#### check updates
```bash
#!/bin/bash
number=$(pacman -Qu | wc -l)

if [[ $number -gt 0 ]]; then
  notify-send "There are $number updates available!"
fi
```

#### simple math
```bash
#!/bin/bash
precision=2
notify_time=20000
answer=$(bc <<< "scale=$precision;$1")

notify-send -t $notify_time "$1=$answer"
```
For use with xfce4-appfinder:
- Type: Regular Expression
- Pattern: ^([0-9]|\(|\.).*
- Command: /bin/sh ~/math.sh \0
