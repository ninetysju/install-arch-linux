# Variables
DEVICE=sda
PARTITION_ROOT=${DEVICE}2
PARTITION_BOOT=${DEVICE}1

read -p "Username: " USERNAME
read -p "Password: " PASSWORD
read -p "Hostname: " HOSTNAME
read -p "Encryption (true/false): " ENCRYPTION

# Initialize
loadkeys sv-latin1
timedatectl set-ntp true

# Create partitions
parted /dev/${DEVICE} mklabel gpt
parted /dev/${DEVICE} mkpart efi fat32 1MiB 513MiB
parted /dev/${DEVICE} set 1 boot on
parted /dev/${DEVICE} mkpart root ext4 513MiB 100%

# Configure root partition
if [ ${ENCRYPTION} = true ] ; then
  cryptsetup luksFormat /dev/${PARTITION_ROOT}
  cryptsetup open /dev/${PARTITION_ROOT} cryptroot
  mkfs.ext4 /dev/mapper/cryptroot
  mount /dev/mapper/cryptroot /mnt
else
  mkfs.ext4 /dev/${PARTITION_ROOT}
  mount /dev/${PARTITION_ROOT} /mnt
fi

# Configure boot partition
mkfs.fat -F32 /dev/${PARTITION_BOOT}
mkdir /mnt/boot
mount /dev/${PARTITION_BOOT} /mnt/boot

# Install base
pacstrap /mnt base linux linux-firmware nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# chroot
arch-chroot /mnt <<- EOC

# Configure time
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc --utc

# Configure localization
sed -i "s/#en_US.UTF-8/en_US.UTF-8/g" /etc/locale.gen
sed -i "s/#sv_SE.UTF-8/sv_SE.UTF-8/g" /etc/locale.gen
locale-gen

cat > /etc/locale.conf << EOF
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

cat > /etc/vconsole.conf << EOF
KEYMAP=sv-latin1
EOF

# Configure network
pacman -S networkmanager --noconfirm
systemctl enable NetworkManager

cat > /etc/hostname << EOF
${HOSTNAME}
EOF

cat >> /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Configure users
useradd -m -G wheel ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd --root /
echo "root:${PASSWORD}" | chpasswd --root /
pacman -S sudo --noconfirm
sed -i "/%wheel ALL=(ALL) ALL/s/^#//" /etc/sudoers

EOC

# Initramfs
if [ ${ENCRYPTION} = true ] ; then
  INIT_HOOKS="HOOKS=(base udev autodetect modconf block keyboard encrypt filesystems fsck)"
  sed -i "s|^HOOKS=.*|$INIT_HOOKS|" /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -P
fi

# Configure boot loader (bootctl)
arch-chroot /mnt bootctl install

if [ ${ENCRYPTION} = true ] ; then
  FS_UUID=$(blkid -o value -s UUID /dev/${PARTITION_ROOT})
  BOOTCTL_OPTIONS="cryptdevice=UUID=${FS_UUID}:cryptroot root=/dev/mapper/cryptroot rw"
else
  BOOTCTL_OPTIONS="root=/dev/${PARTITION_ROOT}"
fi

cat > /mnt/boot/loader/entries/arch-linux.conf << EOF
title    Arch Linux
linux    /vmlinuz-linux
initrd   /initramfs-linux.img
options  ${BOOTCTL_OPTIONS}
EOF

cat > /mnt/boot/loader/loader.conf << EOF
default      arch-linux.conf
timeout      5
console-mode max
editor       no
EOF

# Bootctl automatic update
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

echo "Arch Linux is now installed on ${DEVICE}. You are ready to reboot, 'umount -R /mnt; reboot'"
