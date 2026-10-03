#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
elif [[ $arch == "i386" || $arch == "i686" || $arch == "x86" ]]; then
    arch="32"
elif [[ $arch == "armv7l" || $arch == "armv7" || $arch == "armhf" ]]; then
    arch="arm32-v7a"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [[ "$arch" == "64" ]] && [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件 64 位版本不支持 32 位系统，请使用 64 位系统，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    target_version=""
    target_type="standard" # 默认标准版，通过指定参数安装 minimal 版本，保证无人值守安装

    for arg in "$@"; do
        case "$arg" in
            minimal|min|--minimal|-m)
                target_type="minimal"
                ;;
            standard|std|full|normal|--standard)
                target_type="standard"
                ;;
            latest)
                target_version=""
                ;;
            v*|[0-9]*)
                target_version="$arg"
                ;;
        esac
    done

    if [[ -z "$target_version" ]]; then
        last_version=$(curl -Ls "https://api.github.com/repos/HoshinoNeko/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 XrayR 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 XrayR 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 XrayR 最新版本：${last_version}"
    else
        if [[ $target_version == v* ]]; then
            last_version=$target_version
        else
            last_version="v"$target_version
        fi
    fi

    # Minimal 版本自 v0.9.6 开始支持
    if [[ "$target_type" == "minimal" ]]; then
        ver_clean=$(echo "$last_version" | sed 's/^v//')
        major=$(echo "$ver_clean" | cut -d. -f1)
        minor=$(echo "$ver_clean" | cut -d. -f2)
        patch=$(echo "$ver_clean" | cut -d. -f3 | cut -d- -f1)
        if [[ "$major" -eq 0 && "$minor" -lt 9 ]] || [[ "$major" -eq 0 && "$minor" -eq 9 && "$patch" -lt 6 ]]; then
            echo -e "${red}错误：Minimal 版本自 v0.9.6 开始提供！指定版本 ${last_version} 无 minimal 版本${plain}"
            exit 1
        fi
        package_name="XrayR-linux-${arch}-minimal.zip"
        type_str="Minimal 版"
    else
        package_name="XrayR-linux-${arch}.zip"
        type_str="标准版"
    fi

    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
    cd /usr/local/XrayR/

    url="https://github.com/HoshinoNeko/XrayR/releases/download/${last_version}/${package_name}"
    echo -e "开始安装 XrayR ${last_version} (${type_str})"
    wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
    if [[ $? -ne 0 ]]; then
        if [[ "$target_type" == "minimal" ]]; then
            echo -e "${red}下载 XrayR ${last_version} (${type_str}) 失败，请确保此版本存在（minimal 版本自 v0.9.6 开始提供）且网络畅通${plain}"
        else
            echo -e "${red}下载 XrayR ${last_version} 失败，请确保此版本存在且网络畅通${plain}"
        fi
        exit 1
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/HoshinoNeko/XrayR-release/raw/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR

    if [[ "$target_type" == "minimal" ]]; then
        echo -e "${green}XrayR Minimal ${last_version}${plain} 安装完成，已设置开机自启"
        echo -e "${yellow}注意：Minimal 版本不包含 lego 自动证书签发，请在 ControllerConfig 下使用 CertMode: file 配置证书${plain}"
        [[ -f MINIMAL.md ]] && cp MINIMAL.md /etc/XrayR/
    else
        echo -e "${green}XrayR ${last_version}${plain} 安装完成，已设置开机自启"
        rm -f /etc/XrayR/MINIMAL.md
    fi

    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/HoshinoNeko/XrayR，配置必要的内容"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 重启成功${plain}"
        else
            echo -e "${red}XrayR 可能启动失败，请稍后使用 XrayR log 查看日志信息，若无法启动，则可能更改了配置格式，请前往 wiki 查看：https://github.com/HoshinoNeko/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/HoshinoNeko/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr 2>/dev/null # 小写兼容
    chmod +x /usr/bin/xrayr 2>/dev/null
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "XrayR 管理脚本使用方法 (兼容使用xrayr执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "XrayR                    - 显示管理菜单 (功能更多)"
    echo "XrayR start              - 启动 XrayR"
    echo "XrayR stop               - 停止 XrayR"
    echo "XrayR restart            - 重启 XrayR"
    echo "XrayR status             - 查看 XrayR 状态"
    echo "XrayR enable             - 设置 XrayR 开机自启"
    echo "XrayR disable            - 取消 XrayR 开机自启"
    echo "XrayR log                - 查看 XrayR 日志"
    echo "XrayR update             - 更新 XrayR"
    echo "XrayR update [ver] [type]- 更新 XrayR 指定版本及类型 (standard/minimal)"
    echo "XrayR config             - 显示配置文件内容"
    echo "XrayR install            - 安装 XrayR"
    echo "XrayR install [ver] [type]- 安装 XrayR 指定版本及类型 (standard/minimal)"
    echo "XrayR uninstall          - 卸载 XrayR"
    echo "XrayR version            - 查看 XrayR 版本"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
# install_acme
install_XrayR "$@"
