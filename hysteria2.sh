#!/usr/bin/bash
set -e
# Initialize variables
action=
tag=
type=
go_type=
remove_type=
beta=false
win=false
CGO_ENABLED=0

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='386'
        ;;
      'amd64' | 'x86_64')
        MACHINE='amd64'
        ;;
      'armv5tel')
        MACHINE='arm'
        ;;
      'armv6l')
        MACHINE='arm'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64'
        ;;
      'mips')
        MACHINE='mips'
        ;;
      'mipsle')
        MACHINE='mipsle'
        ;;
      'mips64')
        MACHINE='mips64'
        lscpu | grep -q "Little Endian" && MACHINE='mips64le'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
     elif [[ "$(type -P emerge)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='emerge -qv'
      PACKAGE_MANAGEMENT_REMOVE='emerge -Cv'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" > /dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name" >/dev/null 2>&1; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}

# Function for check wheater user is running at root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "\033[1;31m\033[1mERROR:\033[0m You have to use root to run this script"
    exit 1
  fi
}

curl() {
  if ! $(type -P curl) -L -q --retry 5 --retry-delay 5 --retry-max-time 60 "$@";then
    echo -e "\033[1;31m\033[1mERROR:\033[0m Curl Failed, check your network"
    exit 1
  fi
}

install_log_and_config() {
  if [ ! -d /usr/local/etc/sing-box ];then
    if ! install -d -m 700 /usr/local/etc/sing-box;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Failed to Install: /usr/local/etc/sing-box"
      exit 1
    else
      echo "Installed: /usr/local/etc/sing-box"
    fi
    if ! install -m 700 /dev/null /usr/local/etc/sing-box/config.json;then
      echo -e "\033[1;31m\033[1mERROR:\033[0m Failed to Install: /usr/local/etc/sing-box/config.json"
      exit 1
    else
      echo -e "Installed: /usr/local/etc/sing-box/config.json"
      echo -e "{\n\n}" > /usr/local/etc/sing-box/config.json
    fi
  fi
  if [ ! -d /usr/local/share/sing-box ];then
    if ! install -d -m 700 /usr/local/share/sing-box;then
      echo "\033[1;31m\033[1mERROR:\033[0m Failed to Install: /usr/local/share/sing-box"
      exit 1
    else
      echo "Installed: /usr/local/share/sing-box"
    fi
  fi
}

# Function for service installation
install_service() {
  cat <<EOF > /etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/usr/local/share/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
  echo -e "Installed: /etc/systemd/system/sing-box.service"
  cat <<EOF > /etc/systemd/system/sing-box@.service
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/usr/local/share/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/%i.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
  echo -e "Installed: /etc/systemd/system/sing-box@.service"
  systemctl daemon-reload
  if systemctl enable sing-box && systemctl restart sing-box;then
    echo "INFO: Enable and start sing-box.service"
  else
    echo -e "\033[1;31m\033[1mERROR:\033[0m Failed to enable and start sing-box.service"
    exit 1
  fi
}

install_building_components() {
  if [[ $PACKAGE_MANAGEMENT_INSTALL == 'apt -y --no-install-recommends install' ]]; then
    if ! dpkg -l | awk '{print $2"\t","Version="$3,"ARCH="$4}' | grep build-essential ;then
      echo -e "\e[93mWARN\e[0m: Building components not found, Installing."
      ${PACKAGE_MANAGEMENT_INSTALL} build-essential
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'dnf -y install' ]]; then
    if ! dnf list installed "Development Tools";then
      echo -e "\e[93mWARN\e[0m: Building components not found, Installing."
      ${PACKAGE_MANAGEMENT_INSTALL} "Development Tools"
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'yum -y install' ]]; then
    if ! yum list installed "Development Tools";then
      echo -e "\e[93mWARN\e[0m: Building components not found, Installing."
      ${PACKAGE_MANAGEMENT_INSTALL} "Development Tools"
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'zypper install -y --no-recommends' ]]; then
    if ! zypper se --installed-only gcc;then
      echo -e "\e[93mWARN\e[0m: Building components not found, Installing."
      ${PACKAGE_MANAGEMENT_INSTALL} gcc
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'pacman -Syu --noconfirm' ]]; then
    if ! pacman -Q base-devel;then
      echo -e "\e[93mWARN\e[0m: Building components not found, Installing."
      ${PACKAGE_MANAGEMENT_INSTALL} base-devel
    fi
  elif [[ $PACKAGE_MANAGEMENT_INSTALL == 'emerge -qv' ]]; then
    if ! emerge -p sys-devel/base-system;then
      echo -e "\e[93mWARN\e[0m: Building components not found, Installing."
      ${PACKAGE_MANAGEMENT_INSTALL} sys-devel/base-system
    fi
  fi
}

go_install() {
  install_building_components

  if ! GO_PATH=$(type -P go);then
    bash -c "$(curl -L https://github.com/chise0713/go-install/raw/master/install.sh)" @ install
  else
    echo "INFO: GO Found, PATH=$GO_PATH"
  fi

  if [[ $win == true ]];then 
    export GOOS=windows
    export GOARCH=amd64 && export GOAMD64=v3
  elif [[ $win == false ]];then
    export GOOS=linux
    [[ $MACHINE == amd64 ]] && export GOAMD64=v2
  fi

  if [[ $CGO_ENABLED == 0 ]];then
    export CGO_ENABLED=0
  elif [[ $CGO_ENABLED == 1 ]];then
    export CGO_ENABLED=1
  fi
  
  if echo $tag |grep -oP with_lwip >> /dev/null && [[ $CGO_ENABLED == 0 ]];then
    echo -e "\033[1;31m\033[1mERROR:\033[0m Tag with_lwip \e[1mMUST HAVE environment variable CGO_ENABLED=1\e[0m\nExiting."
    exit 1
  fi

  if echo $tag |grep -oP with_embedded_tor >> /dev/null && [[ $CGO_ENABLED == 0 ]];then
    echo -e "\033[1;31m\033[1mERROR:\033[0m Tag with_embedded_tor \e[1mMUST HAVE environment variable CGO_ENABLED=1\e[0m\nExiting."
    exit 1
  fi

  if [[ $go_type == default ]];then
    echo -e "\
Using offcial default Tags: with_gvisor,with_quic,with_dhcp,with_wireguard,with_ech,with_utls,with_reality_server,with_clash_api.\
"
    tag="with_gvisor,with_quic,with_dhcp,with_wireguard,with_ech,with_utls,with_reality_server,with_clash_api"
  elif [[ $go_type == custom ]]; then
    echo -e "\
Using custom config:
Tags: $tag\
"
  fi

  if ! GOARCH=$MACHINE go install -v -tags $tag github.com/sagernet/sing-box/cmd/sing-box@dev-next;then
      echo -e "Go Install Failed.\nExiting."
      exit 1
  fi

  if [[ $win == false ]];then
    ln -sf /root/go/bin/sing-box /usr/local/bin/sing-box
      echo -e "\
Installed: /root/go/bin/sing-box
Installed: /usr/local/bin/sing-box\
"
  elif [[ $win == true ]];then
    cp -rf /root/go/bin/windows_amd64/sing-box.exe /root/sing-box.exe
    echo -e "Installed: /root/go/bin/sing-box.exe\nInstalled: /root/sing-box.exe"
    exit 0
  fi
}

# Function for installation
curl_install() {
  [[ $MACHINE == amd64 ]] && CURL_MACHINE=amd64
  [[ $MACHINE == arm ]] && CURL_MACHINE=armv7
  [[ $MACHINE == arm64 ]] && CURL_MACHINE=arm64
  [[ $MACHINE == s390x ]] && CURL_MACHINE=s390x
  if [[ $CURL_MACHINE == amd64 ]] || [[ $CURL_MACHINE == arm64 ]] || [[ $CURL_MACHINE == armv7 ]] || [[ $CURL_MACHINE == s390x ]]; then
    if [[ -z $SING_VERSION ]];then
      if [[ $beta == false ]];then
        SING_VERSION=$(curl https://api.github.com/repos/SagerNet/sing-box/releases|grep -oP "sing-box-\d+\.\d+\.\d+-linux-$CURL_MACHINE"| sort -Vru | head -n 1)
        echo "Newest version found: $SING_VERSION"
      elif [[ $beta == true ]];then
        SING_VERSION=$(curl https://api.github.com/repos/SagerNet/sing-box/releases|grep -oP "sing-box-\d+\.\d+\.\d+(-rc|-beta|-alpha)\.\d+-linux-$CURL_MACHINE"| sort -Vru | head -n 1)
        echo "Newest beta/rc version found: $SING_VERSION"
        CURL_TAG=$(echo $SING_VERSION | grep -oP "\d+\.\d+\.\d+(-rc|-beta|-alpha)\.\d+")
      fi
    else
      if curl https://api.github.com/repos/SagerNet/sing-box/releases|grep -oP "sing-box-$SING_VERSION-linux-$CURL_MACHINE";then
        SING_VERSION=$(echo "$SING_VERSION" | sed "s/$SING_VERSION/sing-box-$SING_VERSION-linux-$CURL_MACHINE/")
        CURL_TAG=$((echo $SING_VERSION | grep -oP "\d+\.\d+\.\d+(-rc|-beta|-alpha)\.\d+")||(echo $SING_VERSION | grep -oP "\d+\.\d+\.\d+"))
      else
        echo "No such a version."
        exit 1
      fi
    fi
    if [[ -z $CURL_TAG ]];then 
      curl -o /tmp/$SING_VERSION.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/$SING_VERSION.tar.gz
    else
      curl -o /tmp/$SING_VERSION.tar.gz https://github.com/SagerNet/sing-box/releases/download/v$CURL_TAG/$SING_VERSION.tar.gz
    fi
    tar -xzf /tmp/$SING_VERSION.tar.gz -C /tmp
    cp -rf /tmp/$SING_VERSION/sing-box /usr/local/bin/sing-box
    chmod +x /usr/local/bin/sing-box
    echo -e "\
Installed: /usr/local/bin/sing-box\
"
  else
    echo -e "\
Machine Type Not Support
Try to use \"--type=go\" to install\
"
    exit 1
  fi
}
main() {
  check_root
  identify_the_operating_system_and_architecture

  if [[ $type == go ]];then
    [[ -z $go_type ]] && go_type=default
    go_install
  else
    curl_install
  fi

  [[ $win == false ]] && install_log_and_config
  [[ $win == false ]] && install_service

  # echo -e "Thanks \033[38;5;208m@chika0801\033[0m.\nInstallation Complete"
  exit 0
}

# Function for uninstallation
uninstall() {
  check_root
  if ! ls /etc/systemd/system/sing-box.service >/dev/null 2>&1 ;then
    echo -e "sing-box not Installed.\nExiting."
    exit 1
  fi
  if systemctl stop sing-box && systemctl disable sing-box ;then
    echo -e "INFO: Stop and disable sing-box.service"
  else
    echo -e "\033[1;31m\033[1mERROR:\033[0m Failed to Stop and disable sing-box.service"
    exit 1
  fi
  if [[ $remove_type == purge ]];then
    rm -rf /usr/local/etc/sing-box /var/log/sing-box /usr/local/share/sing-box
    echo -e "\
Removed: /usr/local/etc/sing-box/
Removed: /var/log/sing-box/
Removed: /usr/local/share/sing-box/\
"
  fi
  rm -rf /usr/local/bin/sing-box /etc/systemd/system/sing-box.service /etc/systemd/system/sing-box@.service
  echo -e "\
Removed: /usr/local/bin/sing-box
Removed: /etc/systemd/system/sing-box.service
Removed: /etc/systemd/system/sing-box@.service\
"
# echo -e "Thanks \033[38;5;208m@chika0801\033[0m.\nInstallation Complete"
  exit 0
}
# Show help
help() {
  echo -e "usage: install.sh ACTION [OPTION]...

ACTION:
install                   Install/Update sing-box
remove                    Remove sing-box
help                      Show help
If no action is specified, then help will be selected

OPTION:
  install:
    --beta                    If it's specified, the scrpit will install latest Pre-release version of sing-box. 
                              If it's not specified, the scrpit will install latest release version by default.
    --go                      If it's specified, the scrpit will use go to install sing-box. 
                              If it's not specified, the scrpit will use curl by default.
    --tag=[Tags]              sing-box Install tag, if you specified it, the script will use go to install sing-box, and use your custom tags. 
                              If it's not specified, the scrpit will use offcial default Tags by default.
    --cgo                     Set \`CGO_ENABLED\` environment variable to 1
    --version=[Version]       sing-box Install version, if you specified it, the script will install your custom version sing-box. 
    --win                     If it's specified, the scrpit will use go to compile windows version of sing-box. 
  remove:
    --purge                   Remove all the sing-box files, include logs, configs, etc
"
  exit 0
}
# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --purge)
      remove_type="purge"
      ;;
    --win)
      win=true
      type="go"
      ;;
    --beta)
      beta=true
      ;;
    --go)
      type="go"
      ;;
    --cgo)
      CGO_ENABLED=1
      type="go"
      ;;
    --tag=*)
      tag="${arg#*=}"
      go_type=custom
      type="go"
      ;;
    --version=*)
      SING_VERSION="${arg#*=}"
      ;;
    help)
      action="help"
      ;;
    remove)
      action="remove"
      ;;
    install)
      action="install"
      ;;
    *)
      echo "Invalid argument: $arg"
      exit 1
      ;;
  esac
done

# Perform action based on user input
case "$action" in
  help)
    help
    ;;
  remove)
    uninstall
    ;;
  install)
    main
    ;;
  *)
    echo "No action specified. Exiting..."
    ;;
esac

help