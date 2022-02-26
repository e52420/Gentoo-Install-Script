#!/bin/bash
#Gentoo-Install-Script by Ayoub

cd ..
start_dir=$(pwd)
fdisk -l >> devices
ifconfig -s >> nw_devices
cut -d ' ' -f1 nw_devices >> network_devices
rm -rf nw_devices
sed -e "s/lo//g" -i network_devices
sed -e "s/Iface//g" -i network_devices
sed '/^$/d' network_devices
sed -e '\#Disk /dev/ram#,+5d' -i devices
sed -e '\#Disk /dev/loop#,+5d' -i devices

cat devices
while true; do
    printf "Enter the device name you want to install gentoo on (ex, sda for /dev/sda)\n>"
    read disk
    disk="${disk,,}"
    partition_count="$(grep -o $disk devices | wc -l)"
    disk_chk=("/dev/${disk}")
    if grep "$disk_chk" devices; then
            wipefs -a $disk_chk
            parted -a optimal $disk_chk --script mklabel gpt
            parted $disk_chk --script mkpart primary 1MiB 3MiB
            parted $disk_chk --script name 1 grub
            parted $disk_chk --script set 1 bios_grub on
            parted $disk_chk --script mkpart primary 3MiB 131MiB
            parted $disk_chk --script name 2 boot
            parted $disk_chk --script mkpart primary 131MiB 4227MiB
            parted $disk_chk --script name 3 swap
            parted $disk_chk --script -- mkpart primary 4227MiB -1
            parted $disk_chk --script name 4 rootfs
            parted $disk_chk --script set 2 boot on
            part_1=("${disk_chk}1")
            part_2=("${disk_chk}2")
            part_3=("${disk_chk}3")
            part_4=("${disk_chk}4")
            mkfs.fat -F 32 $part_2
            #mkfs.ext4 $part_2
            mkfs.ext4 $part_4
            mkswap $part_3
            swapon $part_3
            rm -rf devices
            clear
            sleep 2
            break               
    else
        printf "%s is an invalid device, try again with a correct one\n" $disk_chk
        printf ".\n"
        sleep 5
        clear
        cat devices
    fi
done



printf "Enter the username for your NON ROOT user\n>"
read username
username="${username,,}"
printf "Enter yes to make a kernel from scratch or bin  to use bin kernel or no to use the default config\n>"
read kernelanswer
kernelanswer="${kernelanswer,,}"
printf "Enter the Hostname you want to use\n>"
read hostname
printf "Do you want to do performance optimizations. LTO -O3 and Graphite?(yes or no)\n>"
read performance_opts
performance_opts="${performance_opts,,}"
printf "Beginning installation, this will take several minutes\n"


#copying files into place
mount $part_4 /mnt/gentoo
mv deploygentoo /mnt/gentoo
mv network_devices /mnt/gentoo/deploygentoo/
cd /mnt/gentoo/deploygentoo

install_vars=/mnt/gentoo/
cpus=$(grep -c ^processor /proc/cpuinfo)
echo "$disk" >> "$install_vars"
echo "$username" >> "$install_vars"
echo "$kernelanswer" >> "$install_vars"
echo "$hostname" >> "$install_vars"
echo "$cpus" >> "$install_vars"
echo "$part_3" >> "$install_vars"
echo "$part_1" >> "$install_vars"
echo "$part_2" >> "$install_vars"
echo "$part_4" >> "$install_vars"
echo "$performance_opts" >> "$install_vars"
cat network_devices >> "$install_vars"
rm -f network_devices



STAGE3_PATH_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt
STAGE3_PATH=$(curl -s $STAGE3_PATH_URL | grep -v "^#" | cut -d" " -f1)
STAGE3_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_PATH
touch /mnt/gentoo/gentootype.txt
echo latest-stage3-amd64-openrc >> /mnt/gentoo/gentootype.txt
cd /mnt/gentoo/
while [ 1 ]; do
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 $STAGE3_URL
	if [ $? = 0 ]; then break; fi;
	sleep 1s;
done;
check_file_exists () {
	file=$1
	if [ -e $file ]; then
		exists=true
	else
		printf "%s doesn't exist\n" $file
		wget --tries=20 $STAGE3_URL
		exists=false
		$2
	fi
}




check_file_exists /mnt/gentoo/stage3*
stage3=$(ls /mnt/gentoo/stage3*)
tar xpvf $stage3 --xattrs-include='*.*' --numeric-owner
printf "unpacked stage 3\n"

cd /mnt/gentoo/deploygentoo/gentoo/
cp -a /mnt/gentoo/deploygentoo/gentoo/portage/package.use/. /mnt/gentoo/etc/portage/package.use/
cd /mnt/gentoo/
rm -rf /mnt/gentoo/etc/portage/make.conf
cp /mnt/gentoo/deploygentoo/gentoo/portage/make.conf /mnt/gentoo/etc/portage/
printf "copied new make.conf to /etc/portage/\n"
printf "there are %s cpus\n" $cpus
sed -i "s/MAKEOPTS=\"-j12\"/MAKEOPTS=\"-j12 -l12\"/g" /mnt/gentoo/etc/portage/make.conf
sed -i "s/--jobs=12  --load-average=12/--jobs=12  --load-average=12/g" /mnt/gentoo/etc/portage/make.conf
printf "moved portage files into place\n"

cp /mnt/gentoo/deploygentoo/gentoo/portage/package.license /mnt/gentoo/etc/portage
cp /mnt/gentoo/deploygentoo/gentoo/portage/package.accept_keywords /mnt/gentoo/etc/portage/


mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
printf "copied gentoo repository to repos.conf\n"
#
##copy DNS info
cp --dereference /etc/resolv.conf /mnt/gentoo/etc
printf "copied over DNS info\n"


cp /mnt/gentoo/deploygentoo/install_vars /mnt/gentoo/



mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run

cd /mnt/gentoo/
chroot /mnt/gentoo 



source /etc/profile
cd deploygentoo
scriptdir=$(pwd)
cd ..
sed -i '/^$/d' install_vars
install_vars=install_vars

install_vars_count="$(wc -w /install_vars)"
disk=$(sed '1q;d' install_vars)
username=$(sed '2q;d' install_vars)
kernelanswer=$(sed '3q;d' install_vars)
hostname=$(sed '4q;d' install_vars)
cpus=$(sed '6q;d' install_vars)
part_3=$(sed '7q;d' install_vars)
part_1=$(sed '8q;d' install_vars)
part_2=$(sed '9q;d' install_vars)
part_4=$(sed '10q;d' install_vars)
#performance_opts=$(sed '11q;d' install_vars)
nw_interface=$(sed '12q;d' install_vars)
dev_sd=("/dev/$disk")
mount $part_2 /boot
jobs=("-j12")
printf "mounted boot\n"

emerge --sync --quiet
emerge -q app-portage/mirrorselect
emerge -q gentoolkit
printf "searching for fastest servers\n"
mirrorselect -s5 -b10 -D
printf "sync complete\n"

sleep 10

filename=gentootype.txt
line=$(head -n 1 $filename)

printf "preparing to do big emerge\n"
emerge -uvNDq @world
printf "big emerge complete\n"

printf "Europe/Madrid\n" > /etc/timezone
emerge --config --quiet sys-libs/timezone-data
printf "timezone data emerged\n"
#es_ES.UTF-8 UTF-8
printf "es_ES.UTF-8 UTF-8\n" >> /etc/locale.gen
locale-gen
printf "script complete\n"
eselect locale set 4
env-update && source /etc/profile

#Installs the kernel

printf "preparing to emerge kernel sources\n"
emerge -q sys-kernel/gentoo-sources
eselect kernel set 1
ls -l /usr/src/linux/
cd /usr/src/linux/
emerge -q sys-apps/pciutils
emerge -q app-arch/lzop
emerge -q app-arch/zstd
emerge --autounmask-continue -q sys-kernel/genkernel
emerge app-eselect/eselect-repository


if [ $kernelanswer = "bin" ]; then
	emerge -q sys-kernel/gentoo-kernel-bin
	printf "Kernel installed\n"
elif [ $kernelanswer = "no" ]; then
	cp /deploygentoo/gentoo/kernel/gentoominimal /usr/src/linux/.config
	make -j12 && make modules_install
	make install
else
	printf "time to configure your own kernel\n"
	make menuconfig
	make -j12 && make modules_installl
	make install
	printf "Kernel installed\n"
fi
genkernel --install --kernel-config=/usr/src/linux/.config initramfs


cd /etc/init.d
#enables DHCP
sed -i -e "s/localhost/$hostname/g" /etc/conf.d/hostname
emerge --noreplace --quiet net-misc/netifrc
emerge -q net-misc/networkmanager
rc-update add NetworkManager default
rc-update add elogind boot

lscpu >> install_vars
UUID2=$(blkid -s UUID -o value $part_2)
UUID2=("UUID=${UUID2}")
UUID3=$(blkid -s UUID -o value $part_3)
UUID3=("UUID=${UUID3}")
UUID4=$(blkid -s UUID -o value $part_4)
UUID4=("UUID=${UUID4}")
printf "%s\t\t/boot/efi\tvfat\t\tdefaults\t0 2\n" $UUID2 >> /etc/fstab
SUB_STR='/dev/'
if [[ "$part_3" == *"$SUB_STR"* ]]; then
    printf "%s\t\tnone\t\tswap\t\tsw\t\t0 0\n" $UUID3 >> /etc/fstab
fi
printf "%s\t\t/\t\text4\t\tnoatime\t\t0 1\n" $UUID4 >> /etc/fstab

emerge -q sys-apps/mlocate
emerge -q net-misc/dhcpcd

#installs grub
emerge --verbose -q sys-boot/grub:2
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg
printf "updated grub\n"
printf "run commands manually from here on to see what breaks\n"
cd ..

stage3=$(ls stage3*)
rm -rf $stage3


if [ $performance_opts = "yes" ]; then
#ADDED TODAY START
    emerge --autounmask-continue -UD @world
    emerge dev-vcs/git
    eselect repository enable mv
    eselect repository enable lto-overlay
    emerge --sync
    emerge --oneshot --quiet sys-devel/gcc
    gcc-config 2
    emerge --oneshot --usepkg=n --quiet sys-devel/libtool
    emerge --autounmask-continue app-text/texlive
    emerge -q dev-libs/isl
    cd /bin
    git clone https://github.com/periscop/cloog
    cd cloog
    GET_SUBMODULES="/bin/cloog/get_submodules.sh"
    . "$GET_SUBMODULES"
    AUTOGEN="/bin/cloog/autogen.sh"
    . "$AUTOGEN"
    CONFIG="/bin/cloog/configure"
    bash "$CONFIG"
    make && make install
    echo "dev-lang/python::lto-overlay ~amd64" >> /etc/portage/package.accept_keywords
    echo "dev-lang/python::lto-overlay ~amd64" >> /etc/portage/package.accept_keywords
    echo "virtual/freedesktop-icon-theme::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-portage/eix::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-shells/push::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-shells/quoter::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-text/lesspipe::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "sys-apps/less::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "x11-libs/gtk+::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "virtual/man::mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "sys-apps/less:mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-text/lesspipe:mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-shells/quoter:mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-shells/push:mv ~amd64" >> /etc/portage/package.accept_keywords
    echo "app-portage/eix:mv ~amd64" >> /etc/portage/package.accept_keywords
    emerge -q sys-config/ltoize
    emerge -q app-portage/portage-bashrc-mv
    emerge -q app-portage/eix
    emerge -q app-portage/lto-rebuild
    emerge -q app-shells/runtitle
    emerge -q app-shells/push
    emerge -q app-shells/quoter
    emerge -q app-text/lesspipe
    emerge -q sys-apps/less
    emerge -q virtual/freedesktop-icon-theme
    emerge -q virtual/man
    emerge -q dev-lang/python
    #TODO add option to append -falign-functions=32 to CFLAGS if user has an Intel Processor
    if grep -Fq "$GenuineIntel" install_vars
    then
        sed -i 's/^CFLAGS=\"${COMMON_FLAGS}\"/CFLAGS=\"-march=native ${CFLAGS} -pipe -falign-functions=32\"/g' /etc/portage/make.conf
    else
        sed -i 's/^CFLAGS=\"${COMMON_FLAGS}\"/CFLAGS=\"-march=native ${CFLAGS} -pipe\"/g' /etc/portage/make.conf
    fi
    sed -i 's/CXXFLAGS=\"${COMMON_FLAGS}\"/CXXFLAGS=\"${CFLAGS}\"/g' /etc/portage/make.conf
    sed -i "5s/^/NTHREADS=\"$cpus\"\n/" /etc/portage/make.conf
    sed -i '6s/^/source make.conf.lto\n\n/' /etc/portage/make.conf
    sed -i '11s/^/LDFLAGS=\"${CFLAGS} -fuse-linker-plugin\"\n/' /etc/portage/make.conf
    sed -i '12s/^/CPU_FLAGS_X86=\"aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3\"\n/' /etc/portage/make.conf
    sed -i 's/-quicktime/-quicktime lto/g' /etc/portage/make.conf
    sed -i 's/-clamav/-clamav graphite/g' /etc/portage/make.conf
    emerge gcc
    emerge dev-util/pkgconf
    emerge -eq --keep-going @world
    printf "performance enhancements setup, you'll have to emerge sys-config/ltoize to complete\n"
elif [ $performance_opts = "no" ]; then
    printf "performance optimization not selected\n"
fi


while true; do
    printf "enter the password for your root user\n>"
    read -s password
    printf "re-enter the password for your root user\n>"
    read -s password_compare
    if [ "$password" = "$password_compare" ]; then
	echo "root:$password" | chpasswd
        break
    else
        printf ${LIGHTRED}"passwords do not match, re enter them\n"
        printf ${WHITE}".\n"
        sleep 3
        clear
    fi
done
while truer the password for your user %s\n>" $username
    printf "re-enter the password for %s\n>" "$username"
    read -s password_compare
    if [ "$password" = "$password_compare" ]; then
	echo "$username:$password" | chpasswd
        break
    else
        printf ${LIGHTRED}"passwords do not match, re enter them\n"
        printf ${WHITE}".\n"
        sleep 3
        clear
    fi
done
printf "cleaning up\n"
r
rm -rf /install_vars
cp -r /deploygentoo/gentoo/portage/savedcon-r /deploygentoo/gentoo/portage/env /etc/portage/
cp /deploygentoo/gentoo/portage/package.env /etc/portage/
rm -rf /deploygentoo
printf "You now have a completed gentoo installation system, reboot and remove the installation media to load it\nm -rf /post_chroot.sh
