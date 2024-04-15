#!/bin/bash

# 
# ADJUST TO YOUR NEEDS:
#

disk="/dev/sda"
kernel="6.6.y"

#
# (end)
#

arch="${1}"
if [[ -z "${arch}" ]]; then
	printf "\
Usage: %s ARCH
	Where ARCH is either arm64 or amd64.
" "${0}"
	exit 1
fi

case "${arch}" in
	arm64)
		stage3_url="https://distfiles.gentoo.org/releases/arm64/autobuilds/current-stage3-arm64-systemd"
		state3_msg="latest-stage3-arm64-systemd.txt"
		kernelimage="Image"
		kernelarch="arm64"
		efi="BOOTAA64"
		;;
	*)
		stage3_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-nomultilib-systemd"
		state3_msg="latest-stage3-amd64-nomultilib-systemd.txt"
		kernelimage="bzImage"
		kernelarch="x86"
		efi="BOOTX64"
		;;
esac

kernel_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
wd="/root"
os="/mnt/gentoo"
portage="gentoo-latest.tar.xz"
portage_url="http://distfiles.gentoo.org/snapshots"
portage_dir="/var/db/repos/gentoo"
ssh_pubkey=".ssh/robot_user_keys"

printf "Gentoo Setup

arch:       ${arch}
disk:       ${disk}
kernel:     ${kernel}

Ctrl-C now if this setup does not match your needs.

Assert to have added your ssh pubkey during server setup since it will
be used as the ssh key to access the new Gentoo system after reboot.
\n"

read -p "Continue to WIPE disk? y/n " answer
if [[ "${answer}" != "y" ]]; then
	printf "Aborted.\n"
	exit 0
fi

function die ()
{
	[ "$1" == "" ] || printf "Error: $1\n"
	printf "Aborted.\n"
	exit 1
}

function unmount ()
{
	umount ${os}/boot &> /dev/null
	umount ${os}/proc &> /dev/null
	umount --recursive ${os}/dev &> /dev/null
	umount --recursive ${os}/sys &> /dev/null
	umount ${os}/tmp &>/dev/null
	umount ${os} &>/dev/null
}

# cleanup in case the script has been interrupted and then restarted:
unmount

cd ${wd}

printf "* Getting URL of latest stage3 archive...\n"
wget "${stage3_url}/${state3_msg}"
while read -r line
do
	IFS=' ' read -r f1 f2 <<<"$line"
	if [[ "${f1}" =~ stage3-* ]]; then
		stage3="${f1}"
		break
	fi
done <"${state3_msg}"
[[ ! -z "${stage3}" ]] || die "stage3 archive not found"
printf "* Latest stage3 archive found: %s\n" "${stage3}"

printf "* Asserting local ssh pubkeys are present...\n"
[ -f ${wd}/${ssh_pubkey} ] || die "ssh pubkey missing, add you pubkey via the cloud console"

printf "* Creating partitions...\n"
case "${arch}" in
	arm64)
		sfdisk --quiet --label gpt --wipe always --wipe-partitions always "${disk}" <<-EOF
		,256M,U
		,4G,S
		,,L
		EOF
		[ $? == 0 ] || die "sfdisk"
		;;
	*)
		# amd64 needs grub + DOS partition type
		sfdisk --quiet --label dos --wipe always --wipe-partitions always "${disk}" <<-EOF
		,256M,0c,*
		,4G,S
		,,L
		EOF
		[ $? == 0 ] || die "sfdisk"
		;;
esac

printf "* Waiting 10 sec after partitioning...\n"
sleep 10

printf "* Creating boot partition...\n"
mkfs.vfat -F32 ${disk}1 1>/dev/null || die

printf "* Creating swap partition...\n"
mkswap ${disk}2         1>/dev/null || die

printf "* Creating os partition...\n"
mkfs.ext4 ${disk}3      1>/dev/null || die

printf "* Downloading stage3...\n"
wget --no-verbose --show-progress --continue "${stage3_url}/${stage3}" || die "downloading ${stage3_url}/${stage3}; try newer version"

printf "* Downloading portage...\n"
wget --no-verbose --show-progress --continue "${portage_url}/${portage}" || die

printf "* Mounting os partition...\n"
mkdir -p ${os} || die
mount -o noatime ${disk}3 ${os} || die "mounting os partition"

if [ ! -z "$(ls -A --ignore=lost+found ${os})" ]; then
	printf "* Extracting stage3... (skipped: ${os} not empty)\n"
else
	printf "* Extracting stage3...\n"
	tar -xJf ${stage3} -C ${os} || die "extracting stage3 files"
fi

mkdir -p ${os}/${portage_dir} || die
if [ ! -z "$(ls -A ${os}/${portage_dir})" ]; then
	printf "* Extracting portage... (skipped: ${os}/${portage_dir} not empty)\n"
else
	printf "* Extracting portage...\n"
	tar --strip-components=1 -xJf ${portage} -C ${os}/${portage_dir} || die "extracting portage"
fi

if [[ -d "${os}/usr/src/linux" ]]; then
	printf "* Cloning kernel... (skipped: /usr/src/linux exists)\n"
else
	printf "* Cloning kernel...\n"
	git clone ${kernel_url} --branch linux-${kernel} --single-branch \
		--depth=1 ${os}/usr/src/linux || die "cloning kernel from ${kernel_url}"
fi

printf "* Setting up fstab...\n"
cat > ${os}/etc/fstab <<EOF
${disk}1		/boot	vfat	noauto,noatime	1 2
${disk}2		none	swap	sw	0 0
${disk}3		/		ext4	defaults,noauto,noatime	0 1
EOF

# note: DHCP will not work without machine-id
printf "* Setting up DHCP...\n"
cat > ${os}/etc/systemd/network/80-lan.network <<EOF
[Match]
Name=en*

[Network]
DHCP=yes
EOF

# note: below locale-gen will be called
printf "* Setting up minimal locale.gen...\n"
printf "en_US.UTF-8 UTF-8" >> ${os}/etc/locale.gen

printf "* Using own rescue ssh key(s) as authorized_keys...\n"
mkdir -p ${os}/root/.ssh || die
cat ${wd}/${ssh_pubkey} >> ${os}/root/.ssh/authorized_keys || die
chmod 600 ${os}/root/.ssh/authorized_keys

printf "* Mounting boot partition...\n"
mount -o noatime ${disk}1 ${os}/boot || die "mounting boot partition"

printf "* Preparing chroot...\n"
mount -t proc proc ${os}/proc || die "mounting proc"
mount --rbind /dev ${os}/dev || die "mounting dev"
mount --rbind /sys ${os}/sys || die "mounting sys"
mount --make-rslave ${os}/dev || die "make-rslave dev"
mount --make-rslave ${os}/sys || die "make-rslave sys"
mount -t tmpfs none ${os}/tmp || die "mounting tmpfs"

printf "* Copying resolv.conf for network access...\n"
cp /etc/resolv.conf ${os}/etc/

case "${arch}" in
	amd64)
		printf "* Prepare tools for kernel and grub... (chroot)\n"
		LC_ALL=C chroot ${os} /bin/bash <<-EOF
		locale-gen
		env-update
		. /etc/profile
		emerge elfutils &&
		USE="-fonts -nls -themes -grub_platforms_efi-64 grub_platforms_pc" emerge grub
		EOF
		[ $? == 0 ] || die "kernel tool setup (in chroot)"
		;;
	*)
		;;
esac

printf "* Setting up kernel, machine-id, ssh... (chroot)\n"
LC_ALL=C chroot ${os} /bin/bash <<EOF
locale-gen
env-update
. /etc/profile
systemd-machine-id-setup &&
systemctl enable sshd &&
systemctl enable systemd-networkd &&
systemctl enable systemd-timesyncd &&
systemctl enable systemd-resolved &&
cd /usr/src/linux &&
mkdir /tmp/hwc &&
make defconfig &&
make kvm_guest.config &&
for i in \
	DRM_NOUVEAU \
	DRM_EXYNOS \
	DRM_ROCKCHIP \
	DRM_RCAR_DU \
	DRM_RCAR_DW_HDMI \
	DRM_RCAR_USE_LVDS \
	DRM_RCAR_USE_MIPI_DSI \
	DRM_IMX_DCSS \
	DRM_ETNAVIV \
	DRM_HISI_HIBMC \
	DRM_HISI_KIRIN \
	DRM_MEDIATEK \
	DRM_MSM \
	DRM_MXSFB \
	DRM_MESON \
	DRM_PL111 \
	DRM_TIDSS \
	DRM_LEGACY \
	DRM_SUN4I \
	DRM_TEGRA \
	TEGRA_HOST1X \
	SCSI_UFSHCD \
	FPGA \
	RC_CORE \
	NEW_LEDS \
	CHROME_PLATFORMS \
	SURFACE_PLATFORMS \
	XEN_BLKDEV_FRONTEND \
	LOGO \
	SOUND \
	SLIMBUS \
	SOUNDWIRE \
	MEDIA_SUPPORT \
	MMC \
	BTRFS_FS \
	OVERLAY_FS \
	NFS_FS \
	9P_FS \
	SUSPEND \
	HIBERNATION \
	BLK_DEV_INITRD \
	VIRTUALIZATION \
	WLAN \
	PINCTRL \
	GPIOLIB \
	PWM \
	IPMI_HANDLER \
	CAN \
	BT \
	WIRELESS \
	MD \
	RFKILL \
	NET_9P \
	NFC \
	SPI \
	SPMI \
	HWMON \
	THERMAL \
	IIO \
	USB_NET_DRIVERS \
	XEN_NETDEV_FRONTEND \
	ETHERNET \
	QCOM_IPA \
	REGULATOR \
	STAGING \
	SQUASHFS \
	DEBUG_KERNEL \
	XEN \
	MODULES; do ./scripts/config --disable \$i; done &&
./scripts/config --set-str CMDLINE "init=/usr/lib/systemd/systemd root=/dev/sda3 rootwait rootfstype=ext4" &&
make --jobs=4 ${kernelimage}
EOF
[ $? == 0 ] || die "kernel and other inital setup (in chroot)"

printf "* Copying kernel to boot partition...\n"
case "${arch}" in
	arm64)
		mkdir -p ${os}/boot/EFI/BOOT || die
		cp -a ${os}/usr/src/linux/arch/${kernelarch}/boot/${kernelimage} ${os}/boot/EFI/BOOT/${efi}.EFI || die "copying kernel"
		;;
	*)
		LC_ALL=C chroot ${os} /bin/bash <<-EOF
		env-update
		. /etc/profile
		printf "GRUB_TIMEOUT=3\nGRUB_TIMEOUT_STYLE=menu\nGRUB_CMDLINE_LINUX=\"init=/usr/lib/systemd/systemd rootfstype=ext4 root=/dev/sda3 rw rootwait\"\n" > /etc/default/grub &&
		grub-install --target=i386-pc --boot-directory=/boot /dev/sda &&
		cp /usr/src/linux/arch/x86/boot/bzImage /boot/kernel-1-working &&
		cp /usr/src/linux/arch/x86/boot/bzImage /boot/kernel-2-new &&
		grub-mkconfig -o /boot/grub/grub.cfg
		EOF
		;;
esac
[ $? == 0 ] || die "kernel tool setup (in chroot)"

printf "* Saving /root/readme-setup.txt...\n"
printf "\
Steps to consider after a new OS setup:

- localectl set-keymap KEYMAP (e.g. en, de, ...)
- passwd
- timedatectl set-timezone TIMEZONE (e.g US/Eastern, Europe/Berlin, ...)
- hostnamectl set-hostname HOSTNAME
- emerge --sync
- emerge -auDUN @world
- emerge -a flaggie  # set use flags easily: flaggie -nls
- emerge -a gentoolkit bash-completion FAVORITE-EDITOR ...
" >> ${os}/root/readme-setup.txt

printf "* Unmount...\n"
unmount

printf "\
* Setup done! Next steps:
  - Reboot: systemctl reboot
  - Login into Gentoo: ssh root@SAME-IP-ADDR
  - Read /root/readme-setup.txt
"

