#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf- >/dev/null 2>&1
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux >/dev/null 2>&1
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat} >/dev/null 2>&1
    cp src/3proxy /usr/local/etc/3proxy/bin/ >/dev/null 2>&1
    cd $WORKDIR
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 10048
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
flush
authcache user 86400
auth none cache
auth iponly cache
allow 14.224.163.75
deny *

$(awk -F "/" '{print "\n" \
"allow *" $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4}' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

setup_environment() {
    echo "Installing necessary packages"
    yum -y install gcc net-tools bsdtar zip make >/dev/null 2>&1
}

rotate_count=0

rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data >$WORKDIR/data.txt
    gen_ifconfig >$WORKDIR/boot_ifconfig.sh
    bash $WORKDIR/boot_ifconfig.sh
    echo "IPv6 addresses rotated successfully."
    rotate_count=$((rotate_count + 1))
    echo "Rotation count: $rotate_count"
    sleep 3600
}

install_jq() {
  wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
  cp jq /usr/bin
}

download_proxy() {
  local PASS="123"
  zip --password $PASS proxy.zip proxy.txt
  JSON=$(curl -F "file=@proxy.zip" https://file.io)
  URL=$(echo "$JSON" | jq --raw-output '.link')

  echo "Download zip archive from: ${URL}"
  echo "Password: ${PASS}"
}


echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

FIRST_PORT=20000
LAST_PORT=22222

setup_environment
install_3proxy

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.local

bash /etc/rc.local

gen_proxy_file_for_user

rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
echo "So Luong IPv6 Hien Tai:"
ip -6 addr | grep inet6 | wc -l

# Menu loop
while true; do
    echo "1. Thiết Lập Lại 3proxy"
    echo "2. Xoay IPV6"
    echo "3. Download proxy"
    echo "4. Exit"
    echo -n "Nhập Phím Sếp Chọn: "
    read choice
    case $choice in
        1)
            install_3proxy
            ;;
        2)
            rotate_ipv6
            ;;
        3)
            install_jq && download_proxy
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
