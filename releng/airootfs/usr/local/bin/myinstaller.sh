#!/bin/bash
set -e

echo "=== Arch-based Installer ==="

# 1️⃣ Username and password
read -p "Enter your username: " USERNAME
read -s -p "Enter your password: " PASSWORD
echo
read -s -p "Confirm your password: " PASSWORD2
echo
if [ "$PASSWORD" != "$PASSWORD2" ]; then
    echo "Passwords do not match!"
    exit 1
fi

# 2️⃣ Root partition
read -p "Enter root partition (e.g., /dev/sda2): " ROOT_PART
if [ ! -b "$ROOT_PART" ]; then
    echo "Partition does not exist!"
    exit 1
fi
mkfs.ext4 "$ROOT_PART"

# 3️⃣ EFI partition
read -p "Enter EFI partition (e.g., /dev/sda3): " EFI_PART
if [ ! -b "$EFI_PART" ]; then
    echo "Partition does not exist!"
    exit 1
fi
mkfs.fat -F32 "$EFI_PART"

# 4️⃣ Mount partitions
mkdir -p /mnt/target
mount "$ROOT_PART" /mnt/target
mkdir -p /mnt/target/boot/efi
mount "$EFI_PART" /mnt/target/boot/efi

# 5️⃣ Base packages (must install)
BASE_PKGS=(
base linux linux-firmware linux-atm intel-ucode amd-ucode
mkinitcpio grub efibootmgr sudo bash coreutils util-linux
networkmanager
)

# 6️⃣ Additional recommended packages
EXTRA_PKGS=(
alsa-utils arch-install-scripts bcachefs-tools bind bolt brltty btrfs-progs cloud-init cryptsetup dhcpcd diffutils dmidecode dosfstools e2fsprogs
edk2-shell espeakup ethtool exfatprogs f2fs-tools fatresize foot-terminfo fsarchiver gparted gpm gptfdisk hdparm hyperv iw iwd jfsutils
ldns less lftp libfido2 libusb-compat lsscsi lvm2 man-db man-pages mc mdadm memtest86+ memtest86+-efi mmc-utils modemmanager mtools nano
nbd ndisc6 nfs-utils nilfs-utils nmap ntfs-3g nvme-cli open-iscsi open-vm-tools openconnect openpgp-card-tools openssh openvpn partclone
parted partimage pcsclite ppp pptpclient pv qemu-guest-agent refind reflector rsync screen sdparm sg3_utils smartmontools sof-firmware
squashfs-tools syslinux systemd-resolvconf tcpdump terminus-font testdisk tmux tpm2-tools tpm2-tss udftools usb_modeswitch usbmuxd usbutils
vim virtualbox-guest-utils-nox vpnc wireless-regdb wireless_tools wpa_supplicant wvdial xfsprogs xl2tpd zsh zenity gtk4 libadwaita flatpak git libreoffice-fresh power-profiles-daemon
)

# 7️⃣ Desktop packages
DESKTOP_PKGS=(
xorg-server xorg-apps xorg-xinit plasma plasma-workspace plasma-desktop kde-applications sddm networkmanager plasma-nm firefox chromium
)

# 8️⃣ Ask user for installation type
echo "Select installation type:"
echo "1) Minimal (no GUI)"
echo "2) Desktop (Xorg + KDE Plasma)"
read -p "Choice [1-2]: " INSTALL_TYPE

if [[ "$INSTALL_TYPE" == "2" ]]; then
    INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}" "${DESKTOP_PKGS[@]}")
else
    INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}")
fi

# 9️⃣ Pacstrap install
echo "Installing base system and selected packages..."
pacstrap /mnt/target "${INSTALL_PKGS[@]}"

arch-chroot /mnt/target /bin/bash <<EOF
mkdir -p /etc/default
mkdir -p /usr/share/pixmaps
mkdir -p /usr/share/icons/hicolor/48x48/apps
mkdir -p /usr/share/icons/hicolor/256x256/apps
mkdir -p /usr/share/applications
mkdir -p /usr/local/bin
mkdir -p /usr/local/share/livecd-sound
mkdir -p /usr/local/share/pixmaps
EOF

cat > /mnt/target/etc/os-release <<EOF
NAME="Hasib OS"
PRETTY_NAME="Hasib OS"
ID="HASIBOS"
ID_LIKE="arch"
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://www.hasibos.xyz"
DOCUMENTATION_URL="https://www.hasibos.xyz"
SUPPORT_URL="https://www.hasibos.xyz"
BUG_REPORT_URL="https://www.hasibos.xyz"
PRIVACY_POLICY_URL="https://www.hasibos.xyz"
LOGO=logo.png
EOF

cat > /mnt/target/etc/default/grub <<EOF
GRUB_DEFAULT='0'
GRUB_TIMEOUT='5'
GRUB_DISTRIBUTOR='Hasib OS'
GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES loglevel=3'
GRUB_CMDLINE_LINUX=""
EOF

[ -f /usr/local/share/pixmaps/logo.png ] && cp /usr/local/share/pixmaps/logo.png /mnt/target/usr/local/share/pixmaps/logo.png
[ -f /usr/local/share/livecd-sound/asound.conf.in ] && cp /usr/local/share/livecd-sound/asound.conf.in /mnt/target/usr/local/share/livecd-sound/asound.conf.in
[ -f airootfs/usr/local/bin/Installation_guide ] && cp airootfs/usr/local/bin/Installation_guide /mnt/target/usr/local/bin/Installation_guide
[ -f /usr/share/pixmaps/logo.png ] && cp /usr/share/pixmaps/logo.png /mnt/target/usr/share/pixmaps/logo.png
[ -d /usr/share/icons/hicolor ] && cp -r /usr/share/icons/hicolor /mnt/target/usr/share/icons/hicolor

# 11️⃣ Chroot for system setup
# 11️⃣ Chroot for system setup
arch-chroot /mnt/target /bin/bash <<EOF

# User
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# fstab
genfstab -U / > /etc/fstab

# Timezone and hostname
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "hasib" > /etc/hostname

# Enable services
systemctl enable sddm
systemctl enable NetworkManager

# GRUB (UEFI)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Fallback EFI (for broken UEFI)
mkdir -p /boot/efi/EFI/BOOT
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

# Initramfs
mkinitcpio -P

EOF


# 12️⃣ Optional extra packages
read -p "Do you want to install additional packages? (space-separated, leave blank to skip): " USER_PKGS
if [ -n "$USER_PKGS" ]; then
    arch-chroot /mnt/target /bin/bash -c "pacman -Sy --noconfirm $USER_PKGS"
fi

echo "Installation complete! You can reboot now."
