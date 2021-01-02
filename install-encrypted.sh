#!/bin/bash

# https://github.com/Thann/arcrypt/blob/master/arcrypt.sh
# https://whhone.com/posts/arch-linux-full-disk-encryption/
# https://gist.github.com/mattiaslundberg/8620837

# initialize
loadkeys sv-latin1
timedatectl set-ntp true

parted /dev/sda mklabel gpt
parted /dev/sda mkpart efi fat32 1MiB 513MiB
parted /dev/sda set 1 boot on
parted /dev/sda mkpart root ext4 513MiB 100%

# Prepare encrypted partition
cryptsetup luksFormat /dev/sda2
cryptsetup open /dev/sda2 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

# Prepare boot partition
mkfs.fat -F32 /dev/sda1
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

# Install essential packages
pacstrap /mnt base linux linux-firmware nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configure mkinitcpio
INIT_HOOKS="HOOKS=(base udev autodetect modconf block keyboard encrypt filesystems fsck)"
sed -i "s|^HOOKS=.*|$INIT_HOOKS|" /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

arch-chroot /mnt <<- EOF
  # Install microcode updates
  cat /proc/cpuinfo | grep -q GenuineIntel && pacman -S intel-ucode --noconfirm
  cat /proc/cpuinfo | grep -q AuthenticAMD && pacman -S amd-ucode --noconfirm
EOF


TODO INSTALL BOOTLOADER, systemd-boot or grub, add initialize part with disk password, root password, username, user password



# Root
passwd
