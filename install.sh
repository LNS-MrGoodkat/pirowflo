#!/bin/bash
# https://stackoverflow.com/questions/9449417/how-do-i-assign-the-output-of-a-command-into-an-array

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or with sudo" 1>&2
   exit 1
fi

echo " "
echo " "
echo " "
echo " "
echo "  PiRowFlo for Waterrower"
echo "                                                             +-+"
echo "                                           XX+-----------------+"
echo "              +-------+                 XXXX    |----|       | |"
echo "               +-----+                XXX +----------------+ | |"
echo "               |     |             XXX    |XXXXXXXXXXXXXXXX| | |"
echo "+--------------X-----X----------+XXX+------------------------+-+"
echo "|                                                              |"
echo "+--------------------------------------------------------------+"
echo " "
echo " This script will install all the needed packages and modules "
echo " to make the Waterrower Ant and BLE Raspbery Pi Module working"
echo " "

echo " "
echo "-------------------------------------------------------------"
echo "updates the list of latest updates available for the packages"
echo "-------------------------------------------------------------"
echo " "
sudo apt-get update

echo " "
echo "----------------------------------------------"
echo "installed needed packages for python          "
echo "----------------------------------------------"

sudo apt-get install -y python3 python3-gi python3-gi-cairo python3-cairo-dev gir1.2-gtk-3.0 python3-pip libatlas-base-dev libglib2.0-dev libgirepository1.0-dev libcairo2-dev zlib1g-dev libfreetype6-dev liblcms2-dev libopenjp2-7 libtiff5 libdbus-1-dev

echo " "


echo " "
echo "----------------------------------------------"
echo "install needed python3 modules for the project        "
echo "----------------------------------------------"
echo " "

export repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
sudo pip3 install -r ${repo_dir}/requirements.txt

echo " "
echo "-------------------------------------------------------"
echo "check for Ant+ dongle in order to set udev rules       "
echo "Load the Ant+ dongle with FTDI driver                  "
echo "and ensure that the user pi has access to              "
echo "-------------------------------------------------------"
echo " "

# https://unix.stackexchange.com/questions/67936/attaching-usb-serial-device-with-custom-pid-to-ttyusb0-on-embedded

IFS=$'\n'
arrayusb=($(lsusb | cut -d " " -f 6 | cut -d ":" -f 2))

for i in "${arrayusb[@]}"
do
  if [ $i == 1008 ]|| [ $i == 1009 ] || [ $i == 1004 ]; then
    echo "Ant dongle found"
    echo 'ACTION=="add", ATTRS{idVendor}=="0fcf", ATTRS{idProduct}=="'$i'", RUN+="/sbin/modprobe ftdi_sio" RUN+="/bin/sh -c '"'echo 0fcf 1008 > /sys/bus/usb-serial/drivers/ftdi_sio/new_id'\""'' > /etc/udev/rules.d/99-garmin.rules
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0fcf", ATTR{idProduct}=="'$i'", MODE="666"' >> /etc/udev/rules.d/99-garmin.rules
    echo "udev rule written to /etc/udev/rules.d/99-garmin.rules"
    break
  else
    echo "No Ant stick found !"
  fi

done
unset IFS

echo "----------------------------------------------"
echo " add user to the group bluetoot and dialout   "
echo "----------------------------------------------"


sudo usermod -a -G bluetooth $(who -m | awk '{print $1;}')
sudo usermod -a -G dialout   $(who -m | awk '{print $1;}')

echo " "
echo "-----------------------------------------------"
echo " Change bluetooth name of the pi to PiRowFlo"
echo "-----------------------------------------------"
echo " "

echo "PRETTY_HOSTNAME=PiRowFlo" | sudo tee -a /etc/machine-info > /dev/null
sudo bluetoothctl system-alias "PiRowFlo"
#echo "PRETTY_HOSTNAME=S4 Comms PI" | sudo tee -a /etc/machine-info > /dev/null


echo " "
echo "------------------------------------------------------"
echo " install as cli service or with web interface         "
echo "------------------------------------------------------"
echo " "
while true; do
    read -p "Do you wish to install web interface? (y/n) " yn
    case $yn in
        [Yy]* ) webinterface=yes;break;;
        [Nn]* ) webinterface=no;break;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo " "
echo "------------------------------------------------------"
echo " configuring web interface on http://${HOSTNAME}:9001 "
echo "------------------------------------------------------"
echo " "

# generate supervisord.conf from supervisord.conf.orig with updated paths
#
export python3_path=$(which python3)
export supervisord_path=$(which supervisord)
export supervisorctl_path=$(which supervisorctl)

if [[ $webinterface == 'yes' ]]
then
    cp ${repo_dir}/services/supervisord.conf.orig ${repo_dir}/services/supervisord.conf
    sudo chown root:root ${repo_dir}/services/supervisord.conf.orig
    sudo chmod 655 ${repo_dir}/services/supervisord.conf.orig
    sed -i 's@#PYTHON3#@'"$python3_path"'@g' ${repo_dir}/services/supervisord.conf
    sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/services/supervisord.conf
    sed -i 's@#USER#@'"$(who -m | awk '{print $1;}')"'@g' ${repo_dir}/services/supervisord.conf
    #sudo sed -i -e '$i \su '"${USER}"' -c '\''nohup '"${supervisord_path}"' -c '"${repo_dir}"'/supervisord.conf'\''\n' /etc/rc.local
    
    sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/services/supervisord.service
    sed -i 's@#SUPERVISORD_PATH#@'"$supervisord_path"'@g' ${repo_dir}/services/supervisord.service
    sed -i 's@#SUPERVISORCTL_PATH#@'"$supervisorctl_path"'@g' ${repo_dir}/services/supervisord.service
    sudo cp ${repo_dir}/services/supervisord.service /etc/systemd/system/
    sudo chown root:root /etc/systemd/system/supervisord.service
    sudo chmod 655 /etc/systemd/system/supervisord.service
    sudo systemctl enable supervisord
else
    #Autostart PiRowFlow with S4 with Broadcast Bluetooth and ANT
    cp ${repo_dir}/services/pirowflow_cli.service.orig ${repo_dir}/services/pirowflow_cli.service
    sed -i 's@#PYTHON3#@'"$python3_path"'@g' ${repo_dir}/services/pirowflow_cli.service
    sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/services/pirowflow_cli.service
    sudo cp ${repo_dir}/services/pirowflow_cli.service /etc/systemd/system/
    sudo chown root:root /etc/systemd/system/pirowflow_cli.service
    sudo chmod 655 /etc/systemd/system/pirowflow_cli.service
    sudo systemctl enable pirowflow_cli
fi

if ls /tmp/piroflow* 2> /dev/null; then
    sudo rm /tmp/pirowflo*
fi
if ls /tmp/supervisord.log 2> /dev/null; then
    sudo rm /tmp/supervisord.log
fi


#Autoshutdown if no S4 is Connected
sudo chmod 744 ${repo_dir}/services/autoshutdown_S4.sh
sudo /bin/bash -c 'crontab -l | echo "*/10 * * * * ${repo_dir}/services/autoshutdown_S4.sh" | crontab -'

echo " "
echo "------------------------------------------------------------"
echo " Update bluetooth settings according to Apple specifications"
echo "------------------------------------------------------------"
echo " "
# update bluetooth configuration and start supervisord from rc.local
#
#sudo sed -i -e '$i \'"${repo_dir}"'/update-bt-cfg.sh''\n' /etc/rc.local # Update to respect iOS bluetooth specifications

sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/services/update-bt-cfg.service
sudo cp ${repo_dir}/services/update-bt-cfg.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/update-bt-cfg.service
sudo chmod 655 /etc/systemd/system/update-bt-cfg.service
sudo systemctl enable update-bt-cfg


echo " "
echo "------------------------------------------------------------"
echo " setup screen setting to start up at boot                   "
echo "------------------------------------------------------------"
echo " "

sudo sed -i 's/#dtparam=spi=on/dtparam=spi=on/g' /boot/config.txt
sudo sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/src/adapters/screen/settings.ini

sed -i 's@#PYTHON3#@'"$python3_path"'@g' ${repo_dir}/services/screen.service
sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/services/screen.service
sudo cp ${repo_dir}/services/screen.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/screen.service
sudo chmod 655 /etc/systemd/system/screen.service
sudo systemctl enable screen


echo "-----------------------------------------------"
echo " update bluart file as it prevents the start of"
echo " internal bluetooth if usb bluetooth dongle is "
echo " present                                       "
echo "-----------------------------------------------"

sudo sed -i 's/hci0/hci2/g' /usr/bin/btuart

echo "----------------------------------------------"
echo " Add absolut path to the logging.conf file    "
echo "----------------------------------------------"

sed -i 's@#REPO_DIR#@'"$repo_dir"'@g' ${repo_dir}/src/logging.conf

echo " "
echo "----------------------------------------------"
echo " installation done ! rebooting in 3, 2, 1 "
echo "----------------------------------------------"
sleep 3
sudo reboot
echo " "
exit 0
