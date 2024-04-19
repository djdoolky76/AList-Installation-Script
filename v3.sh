#!/bin/bash

# INSTALL_PATH='/opt/alist'
VERSION='latest'

if [ ! -n "$2" ]; then
  INSTALL_PATH='/opt/alist'
else
  if [[ $2 == */ ]]; then
    INSTALL_PATH=${2%?}
  else
    INSTALL_PATH=$2
  fi
  if ! [[ $INSTALL_PATH == */alist ]]; then
    INSTALL_PATH="$INSTALL_PATH/alist"
  fi
fi

RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
PINK_COLOR='\e[1;35m'
SHAN='\e[1;33;5m'
RES='\e[0m'
clear

# Get platform
if command -v arch >/dev/null 2>&1; then
  platform=$(arch)
else
  platform=$(uname -m)
fi

ARCH="UNKNOWN"

if [ "$platform" = "x86_64" ]; then
  ARCH=amd64
elif [ "$platform" = "aarch64" ]; then
  ARCH=arm64
fi

GH_PROXY='https://mirror.ghproxy.com/'

if [ "$(id -u)" != "0" ]; then
  echo -e "\r\n${RED_COLOR}Error，please use root permission and try again！${RES}\r\n" 1>&2
  exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}Error${RES}，一Key installation currently only supports x86_64 and arm64 platforms。\r\nPlease refer to other platforms：${GREEN_COLOR}https://alist.nn.ci${RES}\r\n"
  exit 1
elif ! command -v systemctl >/dev/null 2>&1; then
  echo -e "\r\n${RED_COLOR}Error${RES}，Unable to determine your current Linux distribution。\r\nIt is recommended to install manually：${GREEN_COLOR}https://alist.nn.ci${RES}\r\n"
  exit 1
else
  if command -v netstat >/dev/null 2>&1; then
    check_port=$(netstat -lnp | grep 5244 | awk '{print $7}' | awk -F/ '{print $1}')
  else
    echo -e "${GREEN_COLOR}Port check ...${RES}"
    if command -v yum >/dev/null 2>&1; then
      yum install net-tools -y >/dev/null 2>&1
      check_port=$(netstat -lnp | grep 5244 | awk '{print $7}' | awk -F/ '{print $1}')
    else
      apt-get update >/dev/null 2>&1
      apt-get install net-tools -y >/dev/null 2>&1
      check_port=$(netstat -lnp | grep 5244 | awk '{print $7}' | awk -F/ '{print $1}')
    fi
  fi
fi

CHECK() {
  if [ -f "$INSTALL_PATH/alist" ]; then
    echo "This location is already installed，Please select a different location，or use update command"
    exit 0
  fi
  if [ $check_port ]; then
    kill -9 $check_port
  fi
  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH
  else
    rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
  fi
}

INSTALL() {
  # Download the Alist program
  echo -e "\r\n${GREEN_COLOR}Downloading Alist $VERSION ...${RES}"
  curl -L ${GH_PROXY}https://github.com/djdoolky76/alist/releases/download/Latest/alist-linux-musl-$ARCH.tar.gz -o /tmp/alist.tar.gz $CURL_BAR
  tar zxf /tmp/alist.tar.gz -C $INSTALL_PATH/

  if [ -f $INSTALL_PATH/alist ]; then
    echo -e "${GREEN_COLOR} Download successful. ${RES}"
  else
    echo -e "${RED_COLOR}Download alist-linux-musl-$ARCH.tar.gz failed！${RES}"
    exit 1
  fi

  # Delete download cache
  rm -f /tmp/alist*
}

INIT() {
  if [ ! -f "$INSTALL_PATH/alist" ]; then
    echo -e "\r\n${RED_COLOR}Error${RES}，The current system is not installed Alist\r\n"
    exit 1
  else
    rm -f $INSTALL_PATH/alist.db
  fi

  # create systemd
  cat >/etc/systemd/system/alist.service <<EOF
[Unit]
Description=Alist service
Wants=network.target
After=network.target network.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/alist server
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

  # Add startup
  systemctl daemon-reload
  systemctl enable alist >/dev/null 2>&1
}

SUCCESS() {
  clear
  echo "Alist Installed Successfuly！"
  echo -e "\r\nAddress：${GREEN_COLOR}http://YOUR_IP:5244/${RES}\r\n"

  echo -e "Configuration file path：${GREEN_COLOR}$INSTALL_PATH/data/config.json${RES}"

#   sleep 1s
#   cd $INSTALL_PATH
#   get_password=$(./alist password 2>&1)
#   echo -e "Initial management password：${GREEN_COLOR}$(echo $get_password | awk -F'your password: ' '{print $2}')${RES}"
  echo -e "---------How to get password？--------"
  echo -e "First cd to the directory where alist is located:"
  echo -e "${GREEN_COLOR}cd $INSTALL_PATH${RES}"
  echo -e "Set a new password randomly:"
  echo -e "${GREEN_COLOR}./alist admin random${RES}"
  echo -e "Or manually set a new password:"
  echo -e "${GREEN_COLOR}./alist admin set ${RES}${RED_COLOR}NEW_PASSWORD${RES}"
  echo -e "----------------------------"
  
  echo -e "Starting service"
  systemctl restart alist

  echo
  echo -e "View status：${GREEN_COLOR}systemctl status alist${RES}"
  echo -e "Start service：${GREEN_COLOR}systemctl start alist${RES}"
  echo -e "Restart service：${GREEN_COLOR}systemctl restart alist${RES}"
  echo -e "Out of service：${GREEN_COLOR}systemctl stop alist${RES}"
  echo -e "\r\nWarm reminder: If the port cannot be accessed normally, please check \033[36mServer security group、native firewall、Alist State\033[0m"
  echo
}

UNINSTALL() {
  echo -e "\r\n${GREEN_COLOR}Uninstall Alist ...${RES}\r\n"
  echo -e "${GREEN_COLOR}Stop process${RES}"
  systemctl disable alist >/dev/null 2>&1
  systemctl stop alist >/dev/null 2>&1
  echo -e "${GREEN_COLOR}Clear residual files${RES}"
  rm -rf $INSTALL_PATH /etc/systemd/system/alist.service
  # Compatible with previous versions
  rm -f /lib/systemd/system/alist.service
  systemctl daemon-reload
  echo -e "\r\n${GREEN_COLOR}Alist Removed from system！${RES}\r\n"
}

UPDATE() {
  if [ ! -f "$INSTALL_PATH/alist" ]; then
    echo -e "\r\n${RED_COLOR}Error${RES}，The current system is not installed Alist\r\n"
    exit 1
  else
    config_content=$(cat $INSTALL_PATH/data/config.json)
    if [[ "${config_content}" == *"assets"* ]]; then
      echo -e "\r\n${RED_COLOR}Error${RES}，V3 is not compatible with V2. Please uninstall V2 first or install V3 in a different location.\r\n"
      exit 1
    fi

    echo
    echo -e "${GREEN_COLOR}Stop the Alist process${RES}\r\n"
    systemctl stop alist
    # Back up the alist binary file for fallback if the download update fails
    cp $INSTALL_PATH/alist /tmp/alist.bak
    echo -e "${GREEN_COLOR}Downloading.. Alist $VERSION ...${RES}"
    curl -L ${GH_PROXY}https://github.com/djdoolky76/alist/releases/download/Latest/alist-linux-musl-$ARCH.tar.gz -o /tmp/alist.tar.gz $CURL_BAR
    tar zxf /tmp/alist.tar.gz -C $INSTALL_PATH/
    if [ -f $INSTALL_PATH/alist ]; then
      echo -e "${GREEN_COLOR} Download successful ${RES}"
    else
      echo -e "${RED_COLOR}下载 alist-linux-musl-$ARCH.tar.gz Error, update failed！${RES}"
      echo "Roll back all changes ..."
      mv /tmp/alist.bak $INSTALL_PATH/alist
      systemctl start alist
      exit 1
    fi
  echo -e "---------How to get password？--------"
  echo -e "First cd to the directory where alist is located:"
  echo -e "${GREEN_COLOR}cd $INSTALL_PATH${RES}"
  echo -e "Set a new password randomly:"
  echo -e "${GREEN_COLOR}./alist admin random${RES}"
  echo -e "Or manually set a new password:"
  echo -e "${GREEN_COLOR}./alist admin set ${RES}${RED_COLOR}NEW_PASSWORD${RES}"
  echo -e "----------------------------"
    echo -e "\r\n${GREEN_COLOR}start up Alist process${RES}"
    systemctl start alist
    echo -e "\r\n${GREEN_COLOR}Alist Updated to the latest stable version！${RES}\r\n"
    # 删除临时文件
    rm -f /tmp/alist*
  fi
}

# CURL 进度显示
if curl --help | grep progress-bar >/dev/null 2>&1; then # $CURL_BAR
  CURL_BAR="--progress-bar"
fi

# The temp directory must exist
if [ ! -d "/tmp" ]; then
  mkdir -p /tmp
fi

# Fuck bt.cn (BT will use chattr to lock the php isolation config)
chattr -i -R $INSTALL_PATH >/dev/null 2>&1

if [ "$1" = "uninstall" ]; then
  UNINSTALL
elif [ "$1" = "update" ]; then
  UPDATE
elif [ "$1" = "install" ]; then
  CHECK
  INSTALL
  INIT
  if [ -f "$INSTALL_PATH/alist" ]; then
    SUCCESS
  else
    echo -e "${RED_COLOR} Installation failed${RES}"
  fi
else
  echo -e "${RED_COLOR} Wrong command${RES}"
fi
