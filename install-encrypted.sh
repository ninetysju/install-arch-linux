#!/bin/bash

# https://github.com/Thann/arcrypt/blob/master/arcrypt.sh
# https://whhone.com/posts/arch-linux-full-disk-encryption/
# https://gist.github.com/mattiaslundberg/8620837

# initialize
loadkeys sv-latin1
timedatectl set-ntp true

read -p 'Username: ' USERNAME
read -s -p 'Password: ' PASSWORD
echo
read -p 'Hostname: ' HOSTNAME

# Create partitions
create_partitions() {
  parted /dev/sda mklabel gpt
  parted /dev/sda mkpart efi fat32 1MiB 513MiB
  parted /dev/sda set 1 boot on
  parted /dev/sda mkpart root ext4 513MiB 100%
}

# Prepare root partition
configure_root_partition() {
  #cryptsetup luksFormat /dev/sda2
  #cryptsetup open /dev/sda2 cryptroot
  #mkfs.ext4 /dev/mapper/cryptroot
  #mount /dev/mapper/cryptroot /mnt
  mkfs.ext4 /dev/sda2
  mount /dev/sda2 /mnt
}

# Prepare boot partition
configure_boot_partition() {
  mkfs.fat -F32 /dev/sda1
  mkdir /mnt/boot
  mount /dev/sda1 /mnt/boot
}

# Install essential packages
install_base() {
  pacstrap /mnt base linux linux-firmware nano
}

# Generate fstab
generate_fstab() {
  genfstab -U /mnt >> /mnt/etc/fstab
}

# Configure mkinitcpio
configure_mkinitcpio() {
  #INIT_HOOKS="HOOKS=(base udev autodetect modconf block keyboard encrypt filesystems fsck)"
  #sed -i "s|^HOOKS=.*|$INIT_HOOKS|" /mnt/etc/mkinitcpio.conf

  # Generate initramfs boot images
  arch-chroot /mnt mkinitcpio -P
}

configure_users() {
arch-chroot /mnt <<- EOF
  useradd -m -G wheel ${USERNAME}

  # set passwords
  echo "${USERNAME}:${PASSWORD}" | chpasswd --root /
  echo "root:${PASSWORD}" | chpasswd --root /

  # sudo and enable wheel group
  pacman -S --noconfirm sudo
  sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers
EOF
}

configure_network() {
arch-chroot /mnt <<- EOF
  pacman -S networkmanager --noconfirm
  systemctl enable NetworkManager
EOF

cat > /mnt/etc/hostname << EOF
${HOSTNAME}
EOF

cat >> /mnt/etc/hosts << EOF
127.0.0.1  localhost
::1        localhost
EOF
}

configure_time() {
arch-chroot /mnt <<- EOF
  ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
  hwclock --systohc --utc
EOF
}

configure_localization() {
arch-chroot /mnt <<- EOF
  sed -i "/en_US.UTF-8/s/^#//g" /etc/locale.gen
  sed -i "/sv_SE.UTF-8/s/^#//g" /etc/locale.gen
  locale-gen
EOF

cat > /mnt/etc/vconsole.conf << EOF
KEYMAP=sv-latin1
EOF

cat > /mnt/etc/locale.conf << EOF
LANG=en_US.UTF-8
LC_NUMERIC=sv_SE.UTF-8
LC_TIME=sv_SE.UTF-8
LC_MONETARY=sv_SE.UTF-8
LC_PAPER=sv_SE.UTF-8
LC_NAME=sv_SE.UTF-8
LC_ADDRESS=sv_SE.UTF-8
LC_TELEPHONE=sv_SE.UTF-8
LC_MEASUREMENT=sv_SE.UTF-8
LC_IDENTIFICATION=sv_SE.UTF-8
EOF
}

install_xfce() {
arch-chroot /mnt <<- EOF
  pacman -S --noconfirm \
    xorg-server xorg-xkill \
    xfce4 lightdm lightdm-gtk-greeter \
    gvfs ntfs-3g \
    xfce4-taskmanager xfce4-notifyd xfce4-screensaver xfce4-screenshooter \
    nm-connection-editor network-manager-applet \
    xfce4-pulseaudio-plugin pavucontrol pulseaudio \
    thunar-archive-plugin \
    mousepad xarchiver ristretto qpdfview \
    ufw gufw \
    ffmpeg

  pacman -Rs --noconfirm xfwm4-themes

  systemctl enable lightdm
EOF
}

install_microcode() {
arch-chroot /mnt <<- EOF
  cat /proc/cpuinfo | grep -q GenuineIntel && pacman -S intel-ucode --noconfirm
  cat /proc/cpuinfo | grep -q AuthenticAMD && pacman -S amd-ucode --noconfirm
EOF
}

install_bootloader() {
arch-chroot /mnt bootctl install
#fs_uuid=$(blkid -o value -s UUID /dev/sdb1)

# Arch Linux config
cat > /mnt/boot/loader/entries/arch-linux.conf << EOF
title    Arch Linux
linux    /vmlinuz-linux
initrd   /intel-ucode.img
initrd   /initramfs-linux.img
options  root=/dev/sda2
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
cat /mnt/etc/pacman.d/hooks/100-systemd-boot.hook << EOF
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

# First boot script
configure_firstboot() {
# Service
cat > /mnt/etc/systemd/system/firstboot.service << EOF
[Unit]
Description=Configure installation
Before=getty.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/firstboot.sh

[Install]
WantedBy=multi-user.target
EOF

# Script
cat > /mnt/usr/local/bin/firstboot.sh << EOF
#!/bin/sh

timedatectl set-ntp true
hwclock --systohc --utc

localectl set-x11-keymap se

# Cleanup
systemctl disable firstboot.service
rm /etc/systemd/system/firstboot.service
rm /usr/local/bin/firstboot.sh

reboot
EOF

arch-chroot /mnt systemctl enable firstboot.service
arch-chroot /mnt chmod 744 /usr/local/bin/firstboot.sh
}

create_partitions
configure_root_partition
configure_boot_partition
install_base
generate_fstab
configure_time
configure_localization
configure_network
configure_users

#configure_mkinitcpio
install_microcode
install_bootloader

#install_xfce
configure_firstboot

umount -R /mnt; reboot
