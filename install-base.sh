#!/bin/bash

# initialize
loadkeys sv-latin1
timedatectl set-ntp true

DEVICE=sda
USB=false

read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD
echo
read -p "Hostname: " HOSTNAME
read -p "Encryption (true/false): " ENCRYPTION

# create partitions
parted /dev/${DEVICE} mklabel gpt
parted /dev/${DEVICE} mkpart efi fat32 1MiB 513MiB
parted /dev/${DEVICE} set 1 boot on
parted /dev/${DEVICE} mkpart root ext4 513MiB 100%

# configure root partition
if [ ${ENCRYPTION} = true ] ; then
  cryptsetup luksFormat /dev/${DEVICE}2
  cryptsetup open /dev/${DEVICE}2 cryptroot
  mkfs.ext4 /dev/mapper/cryptroot
  mount /dev/mapper/cryptroot /mnt
else
  mkfs.ext4 /dev/${DEVICE}2
  mount /dev/${DEVICE}2 /mnt
fi

# configure boot partition
mkfs.fat -F32 /dev/${DEVICE}1
mkdir /mnt/boot
mount /dev/${DEVICE}1 /mnt/boot

# install base
pacstrap /mnt base linux linux-firmware nano

# generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# chroot
arch-chroot /mnt <<- EOF
  hwclock --systohc --utc

  # configure network
  pacman -S networkmanager --noconfirm
  systemctl enable NetworkManager

  # configure users
  useradd -m -G wheel ${USERNAME}
  echo "${USERNAME}:${PASSWORD}" | chpasswd --root /
  echo "root:${PASSWORD}" | chpasswd --root /
  pacman -S --noconfirm sudo
  sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers
EOF

systemd-firstboot --root=/mnt --locale=en_US.UTF-8 --keymap=sv-latin1 --timezone=Europe/Stockholm --hostname=${HOSTNAME}

# configure mkinitcpio
# INIT_HOOKS="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
if [ ${ENCRYPTION} = true ] ; then
  INIT_HOOKS="HOOKS=(base udev autodetect modconf block keyboard encrypt filesystems fsck)"
  sed -i "s|^HOOKS=.*|$INIT_HOOKS|" /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -P
fi
if [ ${USB} = true ] ; then
  INIT_HOOKS="HOOKS=(base udev block autodetect modconf filesystems keyboard fsck)"
  sed -i "s|^HOOKS=.*|$INIT_HOOKS|" /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -P
fi

install_bootctl() {
arch-chroot /mnt bootctl install

BOOTCTL_OPTIONS="root=/dev/${DEVICE}2"

if [ ${ENCRYPTION} = true ] ; then
  FS_UUID=$(blkid -o value -s UUID /dev/${DEVICE}2)
  BOOTCTL_OPTIONS="cryptdevice=UUID=${FS_UUID}:cryptroot root=/dev/mapper/cryptroot rw"
fi

# Arch Linux config
cat > /mnt/boot/loader/entries/arch-linux.conf << EOF
title    Arch Linux
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  ${BOOTCTL_OPTIONS}
EOF

# Bootctl config
cat > /mnt/boot/loader/loader.conf << EOF
default      arch-linux.conf
timeout      5
console-mode max
editor       no
EOF

# Automatic update
mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/100-systemd-boot.hook << EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF
}

install_grub() {
  arch-chroot /mnt pacman -S --noconfirm grub efibootmgr

  if [ ${USB} = true ] ; then
    arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot --removable --recheck
  else
    arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=/boot
  fi

  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

install_bootctl
#install_grub

echo "You are now ready to reboot, 'umount -R /mnt; reboot'"
