#!/bin/bash
set -e

echo "=== Hasib OS Installer (Arch-based) ==="

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
base linux linux-firmware intel-ucode amd-ucode
mkinitcpio grub efibootmgr sudo bash coreutils util-linux
networkmanager
)

# 6️⃣ Extra packages (light KDE for live)
EXTRA_PKGS=(
alsa-utils arch-install-scripts btrfs-progs cloud-init dhcpcd e2fsprogs
dosfstools edk2-shell ethtool exfatprogs gparted gpm gptfdisk hdparm
iw iwd less lftp man-db man-pages nano nmap ntfs-3g open-iscsi openssh
openvpn parted pv reflector rsync screen smartmontools syslinux tcpdump
tmux usbutils vim zsh git
)

# 7️⃣ Desktop packages
KDE_PKGS=(xorg-server xorg-apps plasma plasma-workspace plasma-desktop sddm networkmanager firefox chromium)
XFCE_PKGS=(xorg-server xorg-apps xfce4 xfce4-goodies lightdm lightdm-gtk-greeter networkmanager firefox chromium)
LXQT_PKGS=(xorg-server xorg-apps lxqt sddm networkmanager firefox chromium)

# 8️⃣ Choose installation type
echo "Select installation type:"
echo "1) Minimal (no GUI)"
echo "2) KDE Plasma"
echo "3) XFCE"
echo "4) LXQT"
read -p "Choice [1-4]: " INSTALL_TYPE

case "$INSTALL_TYPE" in
  1) INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}") ;;
  2)
     INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}" "${KDE_PKGS[@]}")
     read -p "Install KDE applications? (y/n): " KDE_APPS
     if [[ "$KDE_APPS" != "y" ]]; then
         INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}" "${KDE_PKGS[@]/kde-applications}")
     fi
     ;;
  3)
     INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}" "${XFCE_PKGS[@]}")
     read -p "Install XFCE goodies? (y/n): " XFCE_GOODIES
     if [[ "$XFCE_GOODIES" != "y" ]]; then
         INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}" "${XFCE_PKGS[@]/xfce4-goodies}")
     fi
     ;;
  4) INSTALL_PKGS=("${BASE_PKGS[@]}" "${EXTRA_PKGS[@]}" "${LXQT_PKGS[@]}") ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

# 9️⃣ Choose timezone
echo "Select your timezone:"
echo "1) Riyadh GMT+3"
echo "2) UTC GMT+0"
echo "3) New York GMT-5"
echo "4) Tokyo GMT+9"
read -p "Choice [1-4]: " TZ_CHOICE
case "$TZ_CHOICE" in
  1) TZ=Asia/Riyadh ;;
  2) TZ=UTC ;;
  3) TZ=America/New_York ;;
  4) TZ=Asia/Tokyo ;;
  *) TZ=UTC ;;
esac

# 10️⃣ Choose language
echo "Select your language:"
echo "1) Arabic"
echo "2) English-US"
echo "3) Español"
echo "4) 中文"
read -p "Choice [1-4]: " LANG_CHOICE
case "$LANG_CHOICE" in
  1) LANG=ar_SA.UTF-8 ;;
  2) LANG=en_US.UTF-8 ;;
  3) LANG=es_ES.UTF-8 ;;
  4) LANG=zh_CN.UTF-8 ;;
  *) LANG=en_US.UTF-8 ;;
esac

# 11️⃣ Pacstrap install
echo "Installing base system and selected packages..."
pacstrap /mnt/target "${INSTALL_PKGS[@]}"

# 12️⃣ Prepare directories
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

# 13️⃣ Copy pixmaps/icons
if [ -d /usr/local/share/pixmaps ]; then
    cp -r /usr/local/share/pixmaps/* /mnt/target/usr/share/pixmaps/
fi

# 14️⃣ OS release
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

# 15️⃣ GRUB config
cat > /mnt/target/etc/default/grub <<EOF
GRUB_DEFAULT='0'
GRUB_TIMEOUT='5'
GRUB_DISTRIBUTOR='Hasib OS'
GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES loglevel=3'
GRUB_CMDLINE_LINUX=""
EOF

# 16️⃣ Chroot for system setup
arch-chroot /mnt/target /bin/bash <<EOF
# User
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# fstab
genfstab -U / > /etc/fstab

# Timezone and hostname
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
hwclock --systohc
echo "hasib" > /etc/hostname
echo "LANG=$LANG" > /etc/locale.conf

# Enable services
systemctl enable NetworkManager
[[ "$INSTALL_TYPE" == "2" || "$INSTALL_TYPE" == "3" || "$INSTALL_TYPE" == "4" ]] && systemctl enable sddm

# GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Initramfs
mkinitcpio -P
EOF

echo "Installation complete! You can reboot now."
