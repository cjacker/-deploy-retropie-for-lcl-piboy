#!/bin/sh

CDIR=$(pwd)

# welcome
echo "This script will help you to deploy and config retropie for LCL PiBoy"
echo "By Cjacker <cjacker@gmail.com>"

# check image exist or not
echo -n "Image exist:"
if [ ! -f $CDIR/retropie-buster-4.7.1-rpi4_400.img.gz ];
then
    echo "[failed]"
    echo "Please download retropie image first."
    echo "visit https://retropie.org.uk/download/"
    echo "or use link below:"
    echo "https://github.com/RetroPie/RetroPie-Setup/releases/download/4.7.1/retropie-buster-4.7.1-rpi4_400.img.gz"
    exit 0
fi
echo "[ok]"

# check md5sum
cd $CDIR
echo -n "Verify image md5sum:"
md5sum retropie-buster-4.7.1-rpi4_400.img.gz > $CDIR/md5sum.tmp
diff $CDIR/md5sum.tmp $CDIR/retropie-buster-4.7.1-rpi4_400.img.gz.md5sum
if [ $? -ne 0 ]; then
    echo "[failed]"
    echo "Image checksum failed, please re-download it"
    rm -rf $CDIRmd5sum.tmp
    exit 0
fi
rm -rf $CDIR/md5sum.tmp
echo "[ok]"

# unzip image
echo -n "Unzip gzimage: "
gunzip $CDIR/retropie-buster-4.7.1-rpi4_400.img.gz

if [ $? -ne 0 ]; then
    echo "[failed]"
    echo "gunzip failed, please check it"
    exit 0
fi
echo "[ok]"

#dd image to device
echo "Be careful!!!!"
echo "Which device should the image write to? (for example:/dev/sda):"
read target_device
echo "All data on the device will be erased!!!"
echo "Please comfirm you really want to write to this device: $target_device (y/n)" 
read iamsure
if [ ${iamsure} = "y" ]; then
    echo -n "Writing to $target_device, please wait until finished:"
    sudo dd if=$CDIR/retropie-buster-4.7.1-rpi4_400.img of=$target_device bs=8M status=progress
    ecoh "[done]"
else
    echo "Well, please verify carefully before run this script."
    exit 0
fi


echo -n "Mount partitions:"
# prepare dir for mount partations
mkdir $CDIR/tmp1
mkdir $CDIR/tmp2

# mount partitions
sudo mount $target_device"1" $CDIR/tmp1
sudo mount $target_device"2" $CDIR/tmp2
echo "[done]"

echo -n "Config target OS:"
# install config.txt for PiBoy, mostly for DPI screen settings
sudo mv $CDIR/tmp1/config.txt $CDIR/tmp1/config.txt.orig
sudo cp $CDIR/config/config.txt $CDIR/tmp1/

# install font
sudo cp $CDIR/assets/wqy-microhei.ttf $CDIR/tmp2/usr/share/fonts

# Correct sound card index
sudo sed -i 's/options snd-usb-audio index=-2/options snd-usb-audio index=0/g' $CDIR/tmp2/lib/modprobe.d/aliases.conf

# install joystick config file
sudo cp $CDIR/config/autoconfig/* $CDIR/tmp2/opt/retropie/configs/all/retroarch/autoconfig/

# install some cfgs
#do not need sudo

if [ -f $CDIR/tmp2/opt/retropie/configs/all/emulationstation/es_input.cfg ];
then
    mv $CDIR/tmp2/opt/retropie/configs/all/emulationstation/es_input.cfg $CDIR/tmp2/opt/retropie/configs/all/emulationstation/es_input.cfg.orig
fi
if [ -f $CDIR/tmp2/opt/retropie/configs/all/emulationstation/es_settings.cfg ];
then
    mv $CDIR/tmp2/opt/retropie/configs/all/emulationstation/es_settings.cfg $CDIR/tmp2/opt/retropie/configs/all/emulationstation/es_settings.cfg.orig
fi
if [ -f $CDIR/tmp2/opt/retropie/configs/all/retroarch.cfg ];
then
    mv $CDIR/tmp2/opt/retropie/configs/all/retroarch.cfg $CDIR/tmp2/opt/retropie/configs/all/retroarch.cfg.orig
fi

cp $CDIR/config/es_input.cfg $CDIR/tmp2/opt/retropie/configs/all/emulationstation/
cp $CDIR/config/es_settings.cfg $CDIR/tmp2/opt/retropie/configs/all/emulationstation/
cp $CDIR/config/retroarch.cfg $CDIR/tmp2/opt/retropie/configs/all/

# install switch theme
sudo cp -r $CDIR/assets/es-theme-switch $CDIR/tmp2/etc/emulationstation/themes/switch

# theme font and fontsize
sudo mv $CDIR/tmp2/etc/emulationstation/themes/switch/theme.xml $CDIR/tmp2/etc/emulationstation/themes/switch/theme.xml.bak
sudo cp $CDIR/assets/switch-theme.xml $CDIR/tmp2/etc/emulationstation/themes/switch/theme.xml
echo "[done]"


# config network and ssh
echo "Do you want to config network and ssh? (y/n)"
read config_network 
if [ ${config_network} = "y" ]; then
    echo "Input your wifi essid:"
    read wifi_essid
    echo "Input your password:"
    read wifi_pass
    echo "Your essid is: $wifi_essid"
    echo "Your password is: $wifi_pass"
    echo "Write to target os and enable ssh"
    sudo bash -c "cat >$CDIR/tmp2/etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
ap_scan=1
network={
        ssid=\"$wifi_essid\"
        psk=\"$wifi_pass\"
}
EOF"
   sudo touch $CDIR/tmp1/ssh.txt
else
    echo "Well, skip network and ssh configuration."
fi

# clean configuration menu
rm -rf $CDIR/tmp2/opt/retropie/configs/all/emulationstation/gamelists/retropie/gamelist.xml
rm -rf $CDIR/tmp2//home/pi/RetroPie/retropiemenu/*

# only with config_network, keep 'ShowIP' there.
#if [ ${config_network} = "y" ]; then
    touch $CDIR/tmp2//home/pi/RetroPie/retropiemenu/showip.rp 
#fi

# remove unused services
sudo rm -rf $CDIR/tmp2/etc/systemd/system/multi-user.target.wants/hciuart.service

# umount
sudo umount $CDIR/tmp1
sudo umount $CDIR/tmp2
rm -rf $CDIR/tmp1
rm -rf $CDIR/tmp2

echo "Finished!"

echo ""
echo "NOTE:"
echo "At first boot, it will inform that \"No input device found\", please reboot your device directly."
echo "If WIFI enabled, you can use Samba or SSH to upload game roms to your device."
echo "If want to update OS or install more emulator/cores, please ssh login and run 'sudo ~/RetroPie-Setup/retropie_setup.sh'"
echo ""
echo "The default username/password for RetroPie is: pi/raspberry" 
