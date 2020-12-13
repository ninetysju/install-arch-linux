#!/bin/bash

# https://wiki.archlinux.org/index.php/Installation_guide
# http://hvornum.se/arch.html
# https://github.com/helmuthdu/aui
# https://disconnected.systems/blog/archlinux-installer/#the-complete-installer-script

loadkeys sv-latin1
timedatectl set-ntp true
echo

arch_chroot() {
  arch-chroot /mnt /bin/bash -c "${1}"
}

initialize() {
  # Get infomation from user https://disconnected.systems/blog/archlinux-installer/#the-complete-installer-script
  read -p 'Hostname: ' hostname
  read -p 'Username: ' username
  read -s -p 'Password: ' password
}

create_partitions() {
  # unmount disk
  umount /dev/sda

  # create partitions
  parted /dev/sda mklabel gpt
  parted /dev/sda mkpart efi fat32 1MiB 513MiB
  # parted set 1 boot on
  parted /dev/sda mkpart root ext4 513MiB 100%

  # format partitions
  mkfs.fat -F32 /dev/sda1
  mkfs.ext4 /dev/sda2
}

install_base() {
  #mount the root partition as /mnt
  mount /dev/sda2 /mnt

  # install base packages
  pacstrap /mnt base linux linux-firmware nano

  #generate fstab
  genfstab -U /mnt >> /mnt/etc/fstab
}

install_grub() {
  arch_chroot "pacman -S --noconfirm grub efibootmgr"
  arch_chroot "mkdir /boot/efi"
  arch_chroot "mount /dev/sda1 /boot/efi"
  arch_chroot "grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot/efi"
  arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
}

configure_time() {
  # set timezone
  ln -s /usr/share/zoneinfo/Europe/Stockholm /mnt/etc/localtime

  # set hardware clock to system time
  hwclock --systohc --utc --adjfile=/mnt/etc/adjtime
  #arch-chroot /mnt hwclock --systohc --utc

  # enable ntp
  arch-chroot /mnt timedatectl set-ntp true

  # save
  arch-chroot /mnt systemctl enable systemd-timesyncd.service
}

configure_localization() {
  # uncomment lines in /etc/locale
  arch_chroot "sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen"
  arch_chroot "sed -i '/sv_SE.UTF-8/s/^#//g' /etc/locale.gen"
  arch_chroot "locale-gen"

  # set language
  echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_NUMERIC=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_TIME=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_MONETARY=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_PAPER=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_NAME=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_ADDRESS=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_TELEPHONE=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_MEASUREMENT=sv_SE.UTF-8" >> /mnt/etc/locale.conf
  echo "LC_IDENTIFICATION=sv_SE.UTF-8" >> /mnt/etc/locale.conf

  # set keyboard map
  echo "KEYMAP=sv-latin1" > /mnt/etc/vconsole.conf
}

configure_network() {
  arch_chroot "pacman -S --noconfirm dhcpcd"
  arch_chroot "systemctl enable dhcpcd"

  # set hostname
  echo "${hostname}" > /mnt/etc/hostname

  # set hosts
  echo "127.0.0.1 localhost" >> /mnt/etc/hosts
  echo "::1 localhost" >> /mnt/etc/hosts
}

add_user() {
  # add admin user
  arch-chroot /mnt useradd -m -G wheel ${username}

  # set passwords
  echo "$username:$password" | chpasswd --root /mnt
  echo "root:$password" | chpasswd --root /mnt

  # sudo and enable wheel group
  arch-chroot /mnt pacman -S --noconfirm sudo
  sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
}

install_xorg() {
  arch-chroot /mnt pacman -S --noconfirm xorg-server

  echo "setxkbmap se" > /mnt/etc/profile.d/layout.sh
}

install_xfce() {
  install_xorg

  arch-chroot /mnt pacman -S --noconfirm xfce4 lightdm lightdm-gtk-greeter gvfs mousepad
  arch-chroot /mnt pacman -Rs --noconfirm xfwm4-themes
  arch-chroot /mnt systemctl enable lightdm
}

initialize
create_partitions
install_base
configure_time
configure_localization
configure_network
add_user
install_grub
install_xfce

umount -R /mnt; reboot

#create_system_legacy
create_system_legacy() {
  # unmount
  umount /dev/sda

  # create partitions
  parted /dev/sda mklabel msdos
  parted /dev/sda mkpart primary ext4 1MiB 100%

  # format partitions
  mkfs.ext4 /dev/sda1

  # mount
  mount /dev/sda1 /mnt
  mkdir -p /mnt/boot

  # install base
  pacstrap /mnt base linux linux-firmware grub nano

  # generate fstab
  genfstab -U /mnt >> /mnt/etc/fstab

  # configure grub
  arch_chroot "grub-install --target=i386-pc /dev/sda"
  arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
}

