#!/bin/bash

# initialize
loadkeys sv-latin1
timedatectl set-ntp true

read -s -p 'Root password: ' PASSWORD
# get wired network device
WIRED_DEVICE=$(networkctl list | grep ether | awk '{ print $2 }')

# create partitions
parted /dev/sda mklabel gpt
parted /dev/sda mkpart efi fat32 1MiB 513MiB
# parted set 1 boot on
parted /dev/sda mkpart root ext4 513MiB 100%

# format partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

# mount
mount /dev/sda2 /mnt

# install base packages
pacstrap /mnt base linux linux-firmware nano

# install grub
arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
arch-chroot /mnt mkdir /boot/efi
arch-chroot /mnt mount /dev/sda1 /boot/efi
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot/efi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# root pasword
echo "root:$PASSWORD" | chpasswd --root /mnt

# hwclock
hwclock --systohc --utc

# setup network
arch-chroot /mnt pacman -S --noconfirm networkmanager
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable systemd-resolved

# set locale, keymap, timezone and hostname
systemd-firstboot --root=/mnt --locale=en_US.UTF-8 --keymap=sv-latin1 --timezone=Europe/Stockholm --hostname=archlinux

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

  # configure grub
  arch-chroot /mnt grub-install --target=i386-pc /dev/sda
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

  # generate fstab
  genfstab -U /mnt >> /mnt/etc/fstab
}
