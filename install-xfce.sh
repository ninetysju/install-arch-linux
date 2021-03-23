#!/bin/bash

sudo pacman -S --noconfirm \
  xorg-server \
  xfce4 lightdm lightdm-gtk-greeter \
  xfce4-taskmanager xfce4-notifyd xfce4-screensaver xfce4-screenshooter \
  xfce4-pulseaudio-plugin pavucontrol pulseaudio \
  nm-connection-editor network-manager-applet \
  gvfs ntfs-3g \
  thunar-archive-plugin \
  mousepad xarchiver ristretto qpdfview \
  ufw gufw \
  ffmpeg

sudo pacman -Rs --noconfirm xfwm4-themes

sudo timedatectl set-ntp true
sudo localectl set-x11-keymap se
sudo systemctl enable lightdm
