#!/bin/bash

# ROS Jazzy Jalisco Install Script for Turtlebot 3 + OpenCR Configuration
# status --> UNTESTED

# exit on error
set -e

# Ask for sudo password once and keep sudo session alive
sudo -v
while true; do sudo -n true; sleep 60; done 2>/dev/null &

# Args: swapfile: bool, ROS_DOMAIN_ID: int, lidar type: int
SWAPFILE="true"
ROS_ID="30"
LIDAR="2"

# handling cli args
while [[ $# -gt 0 ]]; do
    case $1 in
        --ros-id|-id)
            ROS_ID="$2"
            shift 2
            ;;
        --lidar|-ld)
            LIDAR="$2"
            shift 2
            ;;
        --no-swapfile|-nsf)
            SWAPFILE="false"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--lidar|-ld LIDAR] [--ros-id|-id ID] [--no-swapfile|-nsf]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# fun ascii art :)
cat << "EOF"
 _____           _   _      ____              _   
|_   _|   _ _ __| |_| | ___| __ )  ___   ___ | |_ 
  | || | | | '__| __| |/ _ \  _ \ / _ \ / _ \| __|
  | || |_| | |  | |_| |  __/ |_) | (_) | (_) | |_ 
  |_| \__,_|_|   \__|_|\___|____/ \___/ \___/ \__|
           R  O  S  +  O  P  E  N  C  R           
                   _____     ____
                 /      \  |  o | 
                |        |/ ___\| 
                |_________/     
                |_|_| |_|_|
EOF
echo "Welcome to TurtleBoot ROS+OPENCR!"
echo "developed by @kmhswimgirl"

if [ "$SWAPFILE" = "true" ]; then
  # make swapfile if RPi has <= 2GB RAM --> ask for bool
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  free -h # --> to check for swap memory
  echo "Swapfile successfully created!"
fi

# Other required dependencies
sudo apt install -y software-properties-common
sudo add-apt-repository -y universe

#referesh package updates and install curl
sudo apt update && sudo apt install -y curl
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" # If using Ubuntu derivates use $UBUNTU_CODENAME
sudo apt install -y /tmp/ros2-apt-source.deb

# install ROS + dev tools
sudo apt update 
sudo apt install -y ros-dev-tools
sudo apt update 
sudo apt -y upgrade
sudo apt install -y ros-jazzy-ros-base

source ~/.bashrc
source /opt/ros/jazzy/setup.bash

# Turtlebot Dependencies
sudo apt install -y python3-argcomplete python3-colcon-common-extensions libboost-system-dev build-essential
sudo apt install -y ros-jazzy-hls-lfcd-lds-driver
sudo apt install -y ros-jazzy-turtlebot3-msgs
sudo apt install -y ros-jazzy-dynamixel-sdk
sudo apt install -y ros-jazzy-xacro
sudo apt install -y libudev-dev

# make turtlebot workspace
mkdir -p ~/turtlebot3_ws/src
cd ~/turtlebot3_ws/src

# check for duplicate dir or accidental root owned dir
if [ -d "turtlebot3" ]; then
  echo "Removing existing turtlebot3 directory (may be root-owned or incomplete)..."
  sudo rm -rf turtlebot3
fi

# Clone Packages from GitHub, make sure branches are there as well
if ! git clone -b jazzy https://github.com/ROBOTIS-GIT/turtlebot3.git; then
  echo "Failed to clone turtlebot3 repository. Check if the branch 'jazzy' exists."
  exit 1
fi
if ! git clone -b jazzy https://github.com/ROBOTIS-GIT/ld08_driver.git; then
  echo "Failed to clone ld08_driver repository. Check if the branch 'jazzy' exists."
  exit 1
fi

# remove cartographer and nav2 packages
cd ~/turtlebot3_ws/src/turtlebot3
rm -rf turtlebot3_cartographer turtlebot3_navigation2 || true
cd ~/turtlebot3_ws/

# Prevent duplicate lines in .bashrc
grep -qxF 'source /opt/ros/jazzy/setup.bash' ~/.bashrc || echo 'source /opt/ros/jazzy/setup.bash' >> ~/.bashrc

# building turtlebot workspace
cd ~/turtlebot3_ws/
colcon build --symlink-install --parallel-workers 1

# prevent ~/.bashrc clutter
grep -qxF 'source ~/turtlebot3_ws/install/setup.bash' ~/.bashrc || echo 'source ~/turtlebot3_ws/install/setup.bash' >> ~/.bashrc
source /opt/ros/jazzy/setup.bash
source ~/turtlebot3_ws/install/setup.bash

PKG_PREFIX=$(ros2 pkg prefix turtlebot3_bringup)
if [ -z "$PKG_PREFIX" ]; then
  echo "Could not find turtlebot3_bringup package. Exiting."
  exit 1
fi
sudo cp "$PKG_PREFIX/share/turtlebot3_bringup/script/99-turtlebot3-cdc.rules" /etc/udev/rules.d/

sudo udevadm control --reload-rules
sudo udevadm trigger

# export variables for configuring the turtlebot, prevent duplicates
grep -qxF "export ROS_DOMAIN_ID=$ROS_ID #TURTLEBOT3" ~/.bashrc || echo "export ROS_DOMAIN_ID=$ROS_ID #TURTLEBOT3" >> ~/.bashrc
grep -qxF "export LDS_MODEL=LDS-0$LIDAR # lidar config" ~/.bashrc || echo "export LDS_MODEL=LDS-0$LIDAR # lidar config" >> ~/.bashrc

# Kill sudo process
kill %1 2>/dev/null || true

# confirm sucess
echo "Set up complete!"
exit 0