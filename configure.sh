#!/bin/bash

read -p 'Hostname: ' hostname
read -p 'Username: ' username
read -s -p 'Password: ' password

configure_network() {
  hostnamectl set-hostname ${hostname}

  configure_ethernet() {
    # get device
    device=$(networkctl list | grep ether | awk '{ print $2 }')
    echo "Configuring ${device}"
    cat <<EOF > /etc/systemd/network/20-wired.network
[Match]
Name=${device}

[Network]
DHCP=yes
EOF
  }

  configure_ethernet
  systemctl enable systemd-resolved
  systemctl start systemd-resolved

  systemctl enable systemd-networkd
  systemctl start systemd-networkd
}

configure_time() {
  timedatectl set-timezone Europe/Stockholm
  timedatectl set-ntp true
  hwclock --systohc --utc
}

configure_localization() {
  # generate locale
  sed -i "/en_US.UTF-8/s/^#//g" /etc/locale.gen
  sed -i "/sv_SE.UTF-8/s/^#//g" /etc/locale.gen
  locale-gen

  # set language
  echo "LANG=en_US.UTF-8" >> /etc/locale.conf
  echo "LC_NUMERIC=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_TIME=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_MONETARY=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_PAPER=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_NAME=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_ADDRESS=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_TELEPHONE=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_MEASUREMENT=sv_SE.UTF-8" >> /etc/locale.conf
  echo "LC_IDENTIFICATION=sv_SE.UTF-8" >> /etc/locale.conf

  # set keymap
  localectl set-keymap sv-latin1
}

configure_user() {
  # add user
  useradd -m -G wheel ${username}

  # set passwords
  echo "$username:$password" | chpasswd --root /
  echo "root:$password" | chpasswd --root /

  # sudo and enable wheel group
  pacman -S --noconfirm sudo
  sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers
}

install_desktop() {
  pacman -S --noconfirm \
    xorg-server \
    xfce4 lightdm lightdm-gtk-greeter gvfs \
    xfce4-taskmanager xfce4-notifyd xfce4-screensaver xfce4-screenshooter \
    xfce4-battery-plugin \
    xfce4-pulseaudio-plugin pavucontrol pulseaudio \
    thunar-archive-plugin \
    mousepad \
    ffmpeg

  pacman -Rs --noconfirm xfwm4-themes

  # graphical network
  pacman -S --noconfirm networkmanager nm-connection-editor network-manager-applet
  systemctl enable NetworkManager.service
  systemctl start NetworkManager.service

  localectl set-x11-keymap se
  systemctl enable lightdm
}

configure_network
configure_time
configure_localization
configure_user
install_desktop

reboot
