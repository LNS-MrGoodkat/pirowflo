#!/bin/bash
#Check every 10 Minutes if S4 is connected, if not Shutdown the PI
if [ $(usb-devices | grep WR-S4.2 | wc -l) = 0 ]
then
	sudo shutdown -h now
fi
