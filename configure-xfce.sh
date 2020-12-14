#!/bin/bash

sudo pacman -S --noconfirm git
git clone https://github.com/rafacuevas3/dots-theme.git
if [ ! -d ~/.themes ]; then
  mkdir ~/.themes
fi

sudo mv "./dots-theme/Dots Black" ~/.themes && rm -rf ./dots-theme

sudo pacman -S --noconfirm papirus-icon-theme arc-gtk-theme

xfconf-query -c xfwm4 -p /general/theme -s "Dots Black"
xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Darker"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"
