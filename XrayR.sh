#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启XrayR" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/quniu/XrayR-install/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "输入指定版本(默认最新版): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/quniu/XrayR-install/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}更新完成，已自动重启 XrayR，请使用 XrayR log 查看运行日志${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "XrayR在修改配置后会自动尝试重启"
    vi /etc/XrayR/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "XrayR状态: ${green}已运行${plain}"
            ;;
        1)
            echo -e "检测到您未启动XrayR或XrayR自动重启失败，是否查看日志？[Y/n]" && echo
            read -e -rp "(默认: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "XrayR状态: ${red}未安装${plain}"
    esac
}

uninstall() {
    confirm "确定要卸载 XrayR 吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/XrayR/ -rf
    rm /usr/local/XrayR/ -rf

    echo ""
    echo -e "卸载成功"
    echo -e "如果你想删除此脚本，则退出脚本后运行 ${green}rm -rf /usr/bin/XrayR /usr/bin/xrayr ${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}XrayR已运行，无需再次启动，如需重启请选择重启${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 启动成功，请使用 XrayR log 查看运行日志${plain}"
        else
            echo -e "${red}XrayR可能启动失败，请稍后使用 XrayR log 查看日志信息${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop XrayR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}XrayR 停止成功${plain}"
    else
        echo -e "${red}XrayR停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart XrayR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR 重启成功，请使用 XrayR log 查看运行日志${plain}"
    else
        echo -e "${red}XrayR可能启动失败，请稍后使用 XrayR log 查看日志信息${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status XrayR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR 设置开机自启成功${plain}"
    else
        echo -e "${red}XrayR 设置开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR 取消开机自启成功${plain}"
    else
        echo -e "${red}XrayR 取消开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/XrayR -N --no-check-certificate https://raw.githubusercontent.com/quniu/XrayR-install/master/XrayR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/XrayR
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
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

check_nginx() {
    echo -e "-------------------"
    echo -e "检查 Nginx 启动状态"
    echo -e "-------------------"
    systemctl enable nginx
    systemctl daemon-reload
    systemctl stop nginx
    systemctl start nginx
    sleep 1
    temp=$(systemctl status nginx | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        echo -e "${green}Nginx 已启动${plain}"
        echo -e ""
    else
        echo -e "${red}Nginx启动失败${plain}"
        echo -e ""
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}XrayR已安装，请不要重复安装${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装XrayR${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "XrayR状态: ${green}已运行${plain}"
            show_enable_status
            ;;
        1)
            echo -e "XrayR状态: ${yellow}未运行${plain}"
            show_enable_status
            ;;
        2)
            echo -e "XrayR状态: ${red}未安装${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

show_XrayR_version() {
    echo -n "XrayR 版本："
    /usr/local/XrayR/XrayR -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_config_file() {
    echo -e "${yellow}XrayR 配置文件生成向导${plain}"
    echo -e "${red}请阅读以下注意事项：${plain}"
    echo -e "${red}1. 目前该功能正处测试阶段${plain}"
    echo -e "${red}2. 生成的配置文件会保存到 /etc/XrayR/config.yml${plain}"
    echo -e "${red}3. 原来的配置文件会保存到 /etc/XrayR/config.yml.bak${plain}"
    echo -e "-----------------------------------------------------"
    read -rp "是否继续生成配置文件？(y/n)" generate_config_file_continue
    if [[ $generate_config_file_continue =~ "y"|"Y" ]]; then
        echo -e "${yellow}请选择你的面板类型，如未列出则不支持：${plain}"
        echo -e "${green}1. SSpanel ${plain}"
        echo -e "${green}2. V2board ${plain}"
        echo -e "${green}3. PMpanel ${plain}"
        echo -e "${green}4. Proxypanel ${plain}"
        read -rp "请输入面板类型 [1-4，默认2]：" PanelType
        [ -z "${PanelType}" ] && PanelType=2
        case "$PanelType" in
            1 ) PanelType="SSpanel" ;;
            2 ) PanelType="V2board" ;;
            3 ) PanelType="NewV2board" ;;
            4 ) PanelType="PMpanel" ;;
            5 ) PanelType="Proxypanel" ;;
            * ) PanelType="SSpanel" ;;
        esac
        read -rp "请输入Api接口网址：" ApiHost
        read -rp "请输入面板对接API Key：" ApiKey
        read -rp "请输入节点Node ID [默认1]:" NodeID
        [ -z "${NodeID}" ] && NodeID=1
        echo -e "${yellow}请选择节点传输协议，如未列出则不支持：${plain}"
        echo -e "${green}1. Shadowsocks ${plain}"
        echo -e "${green}2. Shadowsocks-Plugin ${plain}"
        echo -e "${green}3. V2ray ${plain}"
        echo -e "${green}4. Trojan ${plain}"
        read -rp "请输入传输协议 [1-4，默认4]：" NodeType
        [ -z "${NodeType}" ] && NodeType=4
        case "$NodeType" in
            1 ) NodeType="Shadowsocks" ;;
            2 ) NodeType="Shadowsocks-Plugin" ;;
            3 ) NodeType="V2ray" ;;
            4 ) NodeType="Trojan";;
            * ) NodeType="Shadowsocks" ;;
        esac
        cd /etc/XrayR
        mv config.yml config.yml.bak
        case $NodeType in
            "Shadowsocks" ) cat_shadowsocks_config ;;
            "V2ray" ) cat_v2ray_config ;;
            "Trojan" ) cat_trojan_config ;;
            * ) cat_shadowsocks_config ;;
        esac
        echo -e "${green}XrayR 配置文件生成完成，正在重新启动 XrayR 服务${plain}"
        restart 0
        before_show_menu
    else
        echo -e "${red}已取消 XrayR 配置文件生成${plain}"
        before_show_menu
    fi
}

cat_shadowsocks_config() {
    echo -e "-----------------------"
    echo -e "创建 shadowsocks 配置文件"
    echo -e "-----------------------"
    cat <<EOF > /etc/XrayR/config.yml
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 10 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "${PanelType}" # Panel type: SSpanel, NewV2board, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "${ApiHost}" # 修改这里
      ApiKey: "${ApiKey}" # 修改这里
      NodeID: ${NodeID}
      NodeType: Shadowsocks # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings
      DeviceLimit: 0 # Local settings will replace remote settings
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns
        CertDomain: "ss${NodeID}.test.com" # Domain to cert
        CertFile: /etc/XrayR/cert/ss${NodeID}.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/ss${NodeID}.test.com.pem
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF
}

cat_v2ray_config() {
    echo -e "-----------------------"
    echo -e "创建 v2ray 配置文件"
    echo -e "-----------------------"
    cat <<EOF > /etc/XrayR/config.yml
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 10 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "${PanelType}" # Panel type: SSpanel, NewV2board, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "${ApiHost}" # 修改这里
      ApiKey: "${ApiKey}" # 修改这里
      NodeID: ${NodeID}
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: true # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      DisableSniffing: false # Disable domain sniffing 
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs: # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "v2ray${NodeID}.test.com" # Domain to cert
        CertFile: /etc/XrayR/cert/v2ray${NodeID}.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/v2ray${NodeID}.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF
}

cat_trojan_config() {
    echo -e "-----------------------"
    echo -e "创建 trojan 配置文件"
    echo -e "-----------------------"
    cat <<EOF > /etc/XrayR/config.yml
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 10 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "${PanelType}" # Panel type: SSpanel, NewV2board, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "${ApiHost}" # 修改这里
      ApiKey: "${ApiKey}" # 修改这里
      NodeID: ${NodeID}
      NodeType: Trojan # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: true # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 127.0.0.1 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      DisableSniffing: false # Disable domain sniffing 
      EnableProxyProtocol: true # Only works for WebSocket and TCP
      EnableFallback: true # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: none # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        RejectUnknownSni: false # Reject unknown SNI
        CertDomain: "trojan${NodeID}.test.com" # Domain to cert
        CertFile: /etc/XrayR/cert/trojan${NodeID}.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/trojan${NodeID}.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS pro
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF
}

cat_ubuntu_nginx_config() {
    cat > /etc/nginx/nginx.conf<<-EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    # multi_accept on;
}

stream {
    server {
        listen             443 ssl;
        ssl_protocols      TLSv1 TLSv1.1 TLSv1.2;
        ssl_certificate     /etc/nginx/ssl/xrayr/cert.pem; # 证书地址
        ssl_certificate_key /etc/nginx/ssl/xrayr/key.pem; # 秘钥地址
        # ssl_certificate     /etc/XrayR/cert/certificates/cert.crt; # 证书地址
        # ssl_certificate_key /etc/XrayR/cert/certificates/key.key; # 秘钥地址
        # ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:50m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;
        proxy_protocol    on; # 开启proxy_protocol获取真实ip
        proxy_pass        127.0.0.1:${NodePort}; # 后端Trojan监听端口
    }
}

http {
    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 200m;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##

    # ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
    # ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;

    # gzip_vary on;
    # gzip_proxied any;
    # gzip_comp_level 6;
    # gzip_buffers 16 8k;
    # gzip_http_version 1.1;
    # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}

EOF
}

cat_centos_nginx_config() {
    cat > /etc/nginx/nginx.conf<<-EOF
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

stream {
    server {
        listen             443 ssl;
        ssl_protocols      TLSv1 TLSv1.1 TLSv1.2;
        ssl_certificate     /etc/nginx/ssl/xrayr/cert.pem; # 证书地址
        ssl_certificate_key /etc/nginx/ssl/xrayr/key.pem; # 秘钥地址
        # ssl_certificate     /etc/XrayR/cert/certificates/cert.crt; # 证书地址
        # ssl_certificate_key /etc/XrayR/cert/certificates/key.key; # 秘钥地址
        # ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:50m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;
        proxy_protocol    on; # 开启proxy_protocol获取真实ip
        proxy_pass        127.0.0.1:${NodePort}; # 后端Trojan监听端口
    }
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
}

EOF
}

# 创建Nginx配置文件
nginx_config_file() {
    echo -e "${yellow}Nginx 配置文件生成向导${plain}"
    read -rp "是否继续生成配置文件？(y/n)" nginx_config_file_continue
    if [[ $nginx_config_file_continue =~ "y"|"Y" ]]; then
        read -rp "请输入节点端口 [默认10082]:" NodePort
        [ -z "${NodePort}" ] && NodePort=10082
        mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        if [[ x"${release}" == x"centos" ]]; then
            echo -e "---------CentOS-------------"
            yum install -y nginx-mod-stream
            cat_centos_nginx_config
        elif [[ x"${release}" == x"ubuntu" ]]; then
            echo -e "---------Ubuntu-------------"
            cat_ubuntu_nginx_config
        else
            echo -e "${red}未匹配 nginx 系统文件！${plain}\n" && exit 1
        fi
        sleep 2
        echo -e "----------------------"
        echo -e "正在重新启动 Nginx 服务"
        echo -e "----------------------"
        check_nginx
        echo -e "${green}正在重新启动 XrayR 服务${plain}"
        restart 0
        before_show_menu
    else
        echo -e "${red}已取消 Nginx 配置文件生成${plain}"
        before_show_menu
    fi
}

# 申请自动通配符证书
create_nginx_ssl() {
    echo -e "${yellow}SSL 通配符证书生成向导${plain}"
    read -rp "是否继续生成配置文件？(y/n)" nginx_config_ssl_continue
    if [[ $nginx_config_ssl_continue =~ "y"|"Y" ]]; then
        read -rp "请输入节点域名（主域名）:" PrimaryDomain
        read -rp "请输入ACME密钥（freessl.cn 获取）:" Acme_Key
        echo -e "开始申请证书..."
        /root/.acme.sh/acme.sh --issue -d *.${PrimaryDomain} -d ${PrimaryDomain} --dns dns_dp --server https://acme.freessl.cn/v2/DV90/directory/$Acme_Key --force --debug
        if [[ $? -ne 0 ]]; then
            echo -e "${red}SSL证书申请失败${plain}"
            exit 1
        fi
        echo -e "----------------------"
        echo -e "${green}SSL证书申请完成${plain}"
        echo -e "----------------------"
        sleep 1
        echo -e "----------------------"
        echo -e "开始替换证书..."
        echo -e "----------------------"
        rm -rf /etc/nginx/ssl/xrayr
        mkdir -p /etc/nginx/ssl/xrayr
        /root/.acme.sh/acme.sh --install-cert -d *.${PrimaryDomain} \
        --key-file       /etc/nginx/ssl/xrayr/key.pem  \
        --fullchain-file /etc/nginx/ssl/xrayr/cert.pem \
        --reloadcmd     "systemctl restart nginx"
        sleep 1
        echo -e "----------------------"
        echo -e "正在重新启动 Nginx 服务"
        echo -e "----------------------"
        check_nginx
        echo -e "${green}正在重新启动 XrayR 服务${plain}"
        restart 0
        before_show_menu
    else
        echo -e "${red}已取消 SSL 证书生成${plain}"
        before_show_menu
    fi
}

# 放开防火墙端口
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}放开防火墙端口成功！${plain}"
}

show_usage() {
    echo "XrayR 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "XrayR              - 显示管理菜单 (功能更多)"
    echo "XrayR start        - 启动 XrayR"
    echo "XrayR stop         - 停止 XrayR"
    echo "XrayR restart      - 重启 XrayR"
    echo "XrayR status       - 查看 XrayR 状态"
    echo "XrayR enable       - 设置 XrayR 开机自启"
    echo "XrayR disable      - 取消 XrayR 开机自启"
    echo "XrayR log          - 查看 XrayR 日志"
    echo "XrayR generate     - 生成 XrayR 配置文件"
    echo "XrayR nginx        - 生成 Nginx 配置文件"
    echo "XrayR ssl          - 生成 SSL 通配符证书"
    echo "XrayR update       - 更新 XrayR"
    echo "XrayR update x.x.x - 安装 XrayR 指定版本"
    echo "XrayR install      - 安装 XrayR"
    echo "XrayR uninstall    - 卸载 XrayR"
    echo "XrayR version      - 查看 XrayR 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}XrayR 后端管理脚本，${plain}${red}不适用于docker${plain}
----------------
  ${green}0.${plain} 修改配置
————————————————
  ${green}1.${plain} 安装 XrayR
  ${green}2.${plain} 更新 XrayR
  ${green}3.${plain} 卸载 XrayR
————————————————
  ${green}4.${plain} 启动 XrayR
  ${green}5.${plain} 停止 XrayR
  ${green}6.${plain} 重启 XrayR
  ${green}7.${plain} 查看 XrayR 状态
  ${green}8.${plain} 查看 XrayR 日志
————————————————
  ${green}9.${plain} 设置 XrayR 开机自启
 ${green}10.${plain} 取消 XrayR 开机自启
————————————————
 ${green}11.${plain} 一键安装 bbr (最新内核)
 ${green}12.${plain} 查看 XrayR 版本 
 ${green}13.${plain} 升级 XrayR 维护脚本
 ${green}14.${plain} 生成 XrayR 配置文件
 ${green}15.${plain} 放行 VPS 的所有网络端口
 ${green}16.${plain} 生成 Nginx 配置文件
 ${green}17.${plain} 配置 Nginx SSL
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -rp "请输入选择 [0-17]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_XrayR_version ;;
        13) update_shell ;;
        14) generate_config_file ;;
        15) open_ports ;;
        16) nginx_config_file ;;
        17) create_nginx_ssl ;;
        *) echo -e "${red}请输入正确的数字 [0-17]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "nginx") nginx_config_file ;;
        "ssl") create_nginx_ssl ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_XrayR_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi
