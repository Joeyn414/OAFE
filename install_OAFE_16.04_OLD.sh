#!/bin/bash -
#===============================================================================
# vim: softtabstop=4 shiftwidth=4 expandtab fenc=utf-8 spell spelllang=en cc=81
#===============================================================================
start=$(date +%s.%N)

#--- FUNCTION ----------------------------------------------------------------
# NAME: __function_defined
# DESCRIPTION: Checks if a function is defined within this scripts scope
# PARAMETERS: function name
# RETURNS: 0 or 1 as in defined or not defined
#-------------------------------------------------------------------------------
__function_defined() {
    FUNC_NAME=$1http://download.virtualbox.org/virtualbox/debian/dists/xenial/contrib/
    if [ "$(command -v $FUNC_NAME)x" != "x" ]; then
        echoinfo "Found function $FUNC_NAME"
        return 0
    fi

    echodebug "$FUNC_NAME not found...."
    return 1
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: __strip_duplicates
# DESCRIPTION: Strip duplicate strings
#-------------------------------------------------------------------------------
__strip_duplicates() {
    echo $@ | tr -s '[:space:]' '\n' | awk '!x[$0]++'
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echoerr
# DESCRIPTION: Echo errors to stderr.
#-------------------------------------------------------------------------------
echoerror() {
    printf "${RC} * ERROR${EC}: $@\n" 1>&2;
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echoinfo
# DESCRIPTION: Echo information to stdout.
#-------------------------------------------------------------------------------
echoinfo() {
    printf "${GC} * INFO${EC}: %s\n" "$@";
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echowarn
# DESCRIPTION: Echo warning informations to stdout.
#-------------------------------------------------------------------------------
echowarn() {
    printf "${YC} * WARN${EC}: %s\n" "$@";
}

#--- FUNCTION ----------------------------------------------------------------
# NAME: echodebug
# DESCRIPTION: Echo debug information to stdout.
#-------------------------------------------------------------------------------
echodebug() {
    if [ $_ECHO_DEBUG -eq $BS_TRUE ]; then
        printf "${BC} * DEBUG${EC}: %s\n" "$@";
    fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __apt_get_install_noinput
#   DESCRIPTION:  (DRY) apt-get install with noinput options
#-------------------------------------------------------------------------------
__apt_get_install_noinput() {
    apt-get install -y -o DPkg::Options::=--force-confold $@; return $?
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __apt_get_upgrade_noinput
#   DESCRIPTION:  (DRY) apt-get upgrade with noinput options
#-------------------------------------------------------------------------------
__apt_get_upgrade_noinput() {
    apt-get upgrade -y -o DPkg::Options::=--force-confold $@; return $?
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __pip_install_noinput
#   DESCRIPTION:  (DRY)
#-------------------------------------------------------------------------------
__pip_install_noinput() {
    pip install --upgrade $@; return $?
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __pip_install_noinput
#   DESCRIPTION:  (DRY)
#-------------------------------------------------------------------------------
__pip_pre_install_noinput() {
    pip install --pre --upgrade $@; return $?
}

__check_apt_lock() {
    lsof /var/lib/dpkg/lock > /dev/null 2>&1
    RES=`echo $?`
    return $RES
}


#__enable_universe_repository() {
#    if [ "x$(grep -R universe /etc/apt/sources.list /etc/apt/sources.list.d/ | grep -v '#')" != "x" ]; then
#        # The universe repository is already enabled
#        return 0
#    fi
#
#    echodebug "Enabling the universe repository"
#
#    # Ubuntu versions higher than 12.04 do not live in the old repositories
#    if [ $DISTRO_MAJOR_VERSION -gt 12 ] || ([ $DISTRO_MAJOR_VERSION -eq 12 ] && [ $DISTRO_MINOR_VERSION -gt 04 ]); then
#        add-apt-repository -y "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe" || return 1
#    elif [ $DISTRO_MAJOR_VERSION -lt 11 ] && [ $DISTRO_MINOR_VERSION -lt 10 ]; then
#        # Below Ubuntu 11.10, the -y flag to add-apt-repository is not supported
#        add-apt-repository "deb http://old-releases.ubuntu.com/ubuntu $(lsb_release -sc) universe" || return 1
#    fi
#
#    add-apt-repository -y "deb http://old-releases.ubuntu.com/ubuntu $(lsb_release -sc) universe" || return 1
#
#    return 0
#}


__enable_docker_repository() {
  apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
  add-apt-repository -y "deb https://apt.dockerproject.org/repo ubuntu-$(lsb_release -sc) main"
}

__check_unparsed_options() {
    shellopts="$1"
    # grep alternative for SunOS
    if [ -f /usr/xpg4/bin/grep ]; then
        grep='/usr/xpg4/bin/grep'
    else
        grep='grep'
    fi
    unparsed_options=$( echo "$shellopts" | ${grep} -E '(^|[[:space:]])[-]+[[:alnum:]]' )
    if [ "x$unparsed_options" != "x" ]; then
        usage
        echo
        echoerror "options are only allowed before install arguments"
        echo
        exit 1
    fi
}

configure_cpan() {
    (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan > /dev/null
}

usage() {
    echo "usage"
    exit 1
}

remove_bad_old_deps() {
    echoinfo "Removing old, conflicting, or bad packages ..."
    apt-get remove -y binplist >> $HOME/oafe-install.log 2>&1 || return 1
    apt-get remove -y unity-webapps-common  >> $HOME/oafe-install.log 2>&1 || return 1
}

install_ubuntu_16.04_deps() {
    echoinfo "Updating your APT Repositories ... "
    apt-get update >> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Installing MySQL Server"
    debconf-set-selections <<< 'mysql-server mysql-server/root_password password changeme!' >> $HOME/oafe-install.log 2>&1  || return 1
    debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password changeme!' >> $HOME/oafe-install.log 2>&1  || return 1
    apt-get update >> $HOME/oafe-install.log 2>&1  || return 1
    apt-get install -y mysql-server >> $HOME/oafe-install.log 2>&1  || return 1

    echoinfo "Installing Python Software Properies ... "
    __apt_get_install_noinput software-properties-common >> $HOME/oafe-install.log 2>&1  || return 1

#    echoinfo "Enabling Universal Repository ... "
#    __enable_universe_repository >> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Enabling Docker Repository ... "
    __enable_docker_repository >> $HOME/oafe-install.log 2>&1 || return 1

#    echoinfo "Adding Ubuntu Tweak Repository"
#    add-apt-repository -y ppa:tualatrix/ppa  >> $HOME/oafe-install.log 2>&1 || return 1

#    echoinfo "Adding SIFT Repository: dev"
#    add-apt-repository -y ppa:sift/dev  >> $HOME/oafe-install.log 2>&1 || return 1

#    echoinfo "Adding GIFT Ropository: Stable"
#    add-apt-repository -y ppa:gift/dev >> $HOME/oafe-install.log 2>&1 || return 1

#    echoinfo "Adding Oracle VirtualBox Repository"
#    echo deb http://download.virtualbox.org/virtualbox/debian xenial contrib | tee /etc/apt/sources.list.d/virtualbox.list >> $HOME/oafe-install.log 2>&1 || return 1
#    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add - >> $HOME/oafe-install.log 2>&1 || return 1
#    wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add ->> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Adding Ntopng stable repository"
	wget -O /home/oafe/apt-ntop-stable.deb http://apt-stable.ntop.org/16.04/all/apt-ntop-stable.deb  >> $HOME/oafe-install.log || return 1
    dpkg -i /home/oafe/apt-ntop-stable.deb

    echoinfo "Enabling Draios repository for Sysdig"
    wget -q -O - https://s3.amazonaws.com/download.draios.com/DRAIOS-GPG-KEY.public | apt-key add -   >> $HOME/oafe-install.log 2>&1 || return 1
    wget -q --output-document /etc/apt/sources.list.d/draios.list http://download.draios.com/stable/deb/draios.list  >> $HOME/oafe-install.log 2>&1 || return 1

#    echoinfo "Enabling the REMnux repository"
#    add-apt-repository -y ppa:remnux/stable >> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Enabling InetSim repository"
    wget -O - http://www.inetsim.org/inetsim-archive-signing-key.asc | apt-key add
    echo "deb http://www.inetsim.org/debian/ binary/" > /etc/apt/sources.list.d/inetsim.list

    echoinfo "Enabling the Oracle Java 8 repository, installing Java8, and setting Oracle Java8 as default java environment"
    add-apt-repository -y ppa:webupd8team/java >> $HOME/oafe-install.log 2>&1 || return 1
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections >> $HOME/oafe-install.log 2>&1 || return 1
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections >> $HOME/oafe-install.log 2>&1 || return 1
    apt-get update >> $HOME/oafe-install.log 2>&1  || return 1
    apt-get install -y oracle-java8-installer
    update-java-alternatives -s java-8-oracle
    apt-get install -y oracle-java8-set-default

    echoinfo "Enabling the MaxMind GeoIP Repository"
    add-apt-repository -y ppa:maxmind/ppa >> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Enabling the Cockpit Repository"
    add-apt-repository -y ppa:cockpit-project/cockpit

    echoinfo "Enabling MongoDB Repository"
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 >> $HOME/oafe-install.log 2>&1 || return 1
    echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list >> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Enabling Neo4j Repository"
    wget -O - https://debian.neo4j.org/neotechnology.gpg.key | sudo apt-key add -  >> $HOME/oafe-install.log || return 1
    echo 'deb http://debian.neo4j.org/repo stable/' >/tmp/neo4j.list
    mv /tmp/neo4j.list /etc/apt/sources.list.d  >> $HOME/oafe-install.log || return 1

    echoinfo "Enabling the Node.js repository"
    apt-key adv --keyserver keyserver.ubuntu.com --recv 68576280 >> $HOME/oafe-install.log || return 1
    apt-add-repository -y 'deb https://deb.nodesource.com/node_4.x precise main' >> $HOME/oafe-install.log || return 1

#echoinfo "Enabling Puppet repository"
#        wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb  >> $HOME/oafe-install.log #|| return 1
#        dpkg -i puppetlabs-release-trusty.deb

    #are we using beats still? If not lets remove it
    echoinfo "Enabling beats repository"
    echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee -a /etc/apt/sources.list.d/beats.list >> $HOME/oafe-install.log || return 1
    wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - >> $HOME/oafe-install.log || return 1

    echoinfo "Updating Repository Package List ..."
    apt-get update >> $HOME/oafe-install.log 2>&1 || return 1

    echoinfo "Upgrading all packages to latest version ..."
    __apt_get_upgrade_noinput >> $HOME/oafe-install.log 2>&1 || return 1

    return 0
}

install_ubuntu_16.04_packages() {
    packages="aeskeyfind
afflib-tools
aircrack-ng
apache2
arp-scan
autoconf
automake
autopsy
bcrypt
binutils
binutils-dev
bison
bkhive
bless
blt
bridge-utils
bro
broctl
build-essential
bundler
byacc
cabextract
ccrypt
chromium-browser
clamav
clamav-daemon
cmospwd
cockpit
cryptcat
cryptsetup
dc3dd
dcfldd
dconf-tools
debconf-utils
dh-autoreconf
dkms
docker-engine
docker.io
dos2unix
driftnet
dsniff
e2fslibs-dev
ent
epic5
etherape
ettercap-graphical
exfat-fuse
exfat-utils
exif
extundelete
fcgiwrap
fdupes
feh
firefox
flare
flasm
flex
foremost
g++
gawk
gcc
gdb
gddrescue
geany
genisoimage
geoipupdate
gettext
ghex
git
git-core
gparted
graphviz
gthumb
gtk2-engines:i386
guymager
gzrt
hexedit
htop
hydra
hydra-gtk
ibus
imagemagick
inetsim
inspircd
iptables-persistent
ipython
knocker
kpartx
lame
landscape-client
lft
lib32stdc++6
libafflib-dev
libbz2-dev
libc6-dev
libc6-dev-i386
libcanberra-gtk-module:i386
libcap-ng-dev
libcap-ng0
libcap2-bin
libcurl4-gnutls-dev
libcurl4-openssl-dev
libdate-simple-perl
libdatetime-perl
libemail-outlook-message-perl
libemu2
libewf-dev
libffi-dev
libfreetype6-dev
libfuse-dev
libfuzzy-dev
libgdbm-dev
libgeoip-dev
libgif-dev
libglib2.0
libgtk2.0-0:i386
libimage-exiftool-perl
libjansson-dev
libjavassist-java
libjpeg8-dev
libjpeg-dev
libjpeg-turbo8
libjpeg-turbo8-dev
libjson-perl
libldns1
libldns-dev
liblzma-dev
liblzma5
libmagic-dev
libmozjs-24-bin
libmysqlclient-dev
libncurses5-dev
libncurses5:i386
libnet1
libnet1-dev
libolecf-dev
libpam0g-dev
libparse-win32registry-perl
libpcap-dev
libpcre++-dev
libpcre3
libpcre3-dev
libpff-dev
libpng-dev
libpq-dev
libre2-dev
libreadline-gplv2-dev
libregf-dev
libsm6:i386
libsqlite3-dev
libssl-dev
libtext-csv-perl
libtool
libv8-dev
libvshadow-dev
libwebkitgtk-1.0-0
libwww-perl
libxml2
libxml2-dev
libxslt1.1
libxslt1-dev
libxxf86vm1:i386
libyaml-0-2
libyaml-dev
libyara3
libzmq3-dev
ltrace
make
maltegoce
masscan
md5deep
meld
mercurial
mongodb-org
mosh
nbd-client
nbtscan
neo4j
netcat
netpbm
netsed
netwox
nfdump
ngrep
nikto
nmap
nodejs
ntopng
okular
open-iscsi
open-vm-tools
openssh-client
openssh-server
openssl
openvpn
ophcrack
ophcrack-cli
oracle-java8-installer
outguess
p0f
p7zip-full
pdfresurrect
pdftk
pev
phantomjs
phonon
phpmyadmin
php7.0-gd
php7.0-fpm
pkg-config
pslist
puppet
pv
pwgen
pyew
python
python-bottle
python-bson
python-capstone
python-cffi
python-chardet
python-crypto
python-dev
python-dnspython
python-dpkt
python-fuse
python-gevent
python-gridfs
python-gtk2
python-gtk2-dev
python-gtksourceview2
python-hachoir-core
python-hachoir-metadata
python-hachoir-parser
python-hachoir-regex
python-hachoir-subfile
python-hachoir-urwid
python-hachoir-wx
python-ipy
python-jinja2
python-levenshtein
python-libvirt
python-m2crypto
python-magic
python-msgpack
python-mysqldb
python-nids
python-nose
python-numpy
python-pcapy
python-pefile
python-pil
python-pillow
python-pip
python-progressbar
python-pyasn1
python-pyclamd
python-pydot
python-pygal
python-pyrex
python-qt4
python-scipy
python-setuptools
python-socks
python-sqlalchemy
python-tk
python-utidylib
python-vte
python-whois
python-yara
python-zmq
qemu
qemu-utils
qpdf
radare2
rar
readpst
redis-server
rhino
rsakeyfind
ruby
ruby-dev
ruby-gtk2
safecopy
samba
samdump2
scalpel
schedtool
scite
sleuthkit
socat
spawn-fcgi
ssdeep
ssldump
sslsniff
strace
stunnel4
subversion
supervisor
swftools
swig
sysdig
system-config-samba
tcl
tcpdump
tcpflow
tcpick
tcpreplay
tcpstat
tcptrace
tcptrack
tcpxtract
tesseract-ocr
testdisk
tig
tofrodos
transmission
unhide
unicode
unity-control-center
unrar
upx-ucl
usbmount
uuid-dev
uwsgi
uwsgi-plugin-python
vbindiff
vim
virtuoso-minimal
vmfs-tools
volatility
winbind
wine
wireshark
wxhexeditor
xdot
xfsprogs
xmlstarlet
xmount
xpdf
xz-utils
zenity
zip
zlib1g
zlib1g-dev
zmap
filebeat
network-manager-openvpn
network-manager-openconnect
apache2-utils
mitmproxy"

#    if [ "$@" = "dev" ]; then
#        packages="$packages"
#    elif [ "$@" = "stable" ]; then
#        packages="$packages"
#    fi

    for PACKAGE in $packages; do
        __apt_get_install_noinput $PACKAGE >> $HOME/oafe-install.log 2>&1
        ERROR=$?
        if [ $ERROR -ne 0 ]; then
            echoerror "Install Failure: $PACKAGE (Error Code: $ERROR)"
        else
            echoinfo "Installed Package: $PACKAGE"
        fi
    done

    return 0
}

install_ubuntu_16.04_pip_packages() {
    pip_packages="alembic==0.8.0 analyzeMFT argparse beautifulsoup4==4.4.1 bitstring bottle cffi==1.2.1 colorama construct cryptography==1.0 cybox distorm distorm3 django dnspython docopt dpkt ecdsa enum34 Flask Flask-SQLAlchemy fluent-logger fuzzywuzzy HTTPReplay idna interruptingcow ioc_writer ipaddress itsdangerous ivre javatools Jinja2 jsbeautifier lxml maec Mako MarkupSafe mitmproxy MySQL-python ndg-httpsclient olefile oletools pbkdf2 pexcept pefile PrettyTable psycopg2 py-unrar2 py3compat pyasn1 pycparser pycrypto pydeep pyelftools pylzma pymisp pymongo pypdns pype32 pyOpenSSL pypssl python-dateutil python-editor python-evtx python-magic python-registry pyv8 pyvmomi r2pipe rarfile rekall requesocks requests request-cache scandir scikit-learn six stix stix-validator SQLAlchemy terminaltables timesketch tlslite-ng unicodecsv virtualenv virustotal-api wakeonlan Werkzeug xortool"
    pip_pre_packages="bitstring"

#    if [ "$@" = "dev" ]; then
#        pip_packages="$pip_packages"
#    elif [ "$@" = "stable" ]; then
#        pip_packages="$pip_packages"
#    fi

    ERROR=0
    for PACKAGE in $pip_pre_packages; do
        CURRENT_ERROR=0
        echoinfo "Installed Python (pre) Package: $PACKAGE"
        __pip_pre_install_noinput $PACKAGE >> $HOME/oafe-install.log 2>&1 || (let ERROR=ERROR+1 && let CURRENT_ERROR=1)
        if [ $CURRENT_ERROR -eq 1 ]; then
            echoerror "Python Package Install Failure: $PACKAGE"
        fi
    done

    for PACKAGE in $pip_packages; do
        CURRENT_ERROR=0
        echoinfo "Installed Python Package: $PACKAGE"
        __pip_install_noinput $PACKAGE >> $HOME/oafe-install.log 2>&1 || (let ERROR=ERROR+1 && let CURRENT_ERROR=1)
        if [ $CURRENT_ERROR -eq 1 ]; then
            echoerror "Python Package Install Failure: $PACKAGE"
        fi
    done

    if [ $ERROR -ne 0 ]; then
        echoerror
        return 1
    fi

    return 0
}


# Global: Works on 12.04 and 16.04
install_perl_modules() {
	# Required by macl.pl script
	perl -MCPAN -e "install Net::Wigle" >> $HOME/oafe-install.log 2>&1
	perl -MCPAN -e "install Net::Server" >> $HOME/oafe-install.log 2>&1
	perl -MCPAN -e "install Net::DNS" >> $HOME/oafe-install.log 2>&1
	perl -MCPAN -e "install IPC::Shareable" >> $HOME/oafe-install.log 2>&1
	perl -MCPAN -e "install Digest::SHA" >> $HOME/oafe-install.log 2>&1
	perl -MCPAN -e "install IO::Socket::SSL" >> $HOME/oafe-install.log 2>&1
}


#install_sift_files() {
#  # Checkout code from sift-files and put these files into place
#  echoinfo "OAFE VM: Installing SANS SIFT Files"
#	CDIR=$(pwd)
#	git clone --recursive https://github.com/sans-dfir/sift-files /tmp/sift-files >> $HOME/oafe-install.log 2>&1
#	cd /tmp/sift-files
#	bash install.sh >> $HOME/oafe-install.log 2>&1
#	cd $CDIR
#	rm -r -f /tmp/sift-files
#}

configure_ubuntu() {
echoinfo "Creating oafe directory in /opt/oafe"
    if [ ! -d /opt/oafe ]; then
        mkdir -p /opt/oafe
        chown $SUDO_USER:$SUDO_USER /opt/oafe
        chmod 775 /opt/oafe
        chmod g+s /opt/oafe
    fi

echoinfo "Cloning Optum OAFE support files to /opt/oafe/OAFE"
    git clone https://github.com/joeyn414/OAFE.git /opt/oafe/OAFE
    chown -R $SUDO_USER:$SUDO_USER /opt/oafe/OAFE
    chmod -R 775 /opt/oafe/OAFE
    chmod -R g+s /opt/oafe/OAFE

echoinfo "Disable IPv6"
    echo "net.ipv6.conf.all.disable_ipv6 = 1
    net.ipv6.conf.default.disable_ipv6 = 1
    net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee /etc/sysctl.d/99-my-disable-ipv6.conf
    service procps reload

echoinfo "Setting OpenVPN to autostart and autorestart"
    cp -f /opt/oafe/OAFE/conf/openvpn/openvpn /etc/default/openvpn
    cp -f /opt/oafe/OAFE/conf/openvpn/openvpn@.service /lib/systemd/system/openvpn@.service

echoinfo "Enabling Cockpit Monitoring Service on port 9090"
    systemctl enable --now cockpit.socket

echoinfo "Enabling NGINX Firewall"
    ufw allow 'Nginx Full'
    systemctl disable apache2
    systemctl enable nginx
    mkdir /etc/nginx/ssl
    echoinfo "OpenSSL Certificate Creation - You will need to enter the details of the server here"
    openssl req -x509 -nodes -days 1460 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
    openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    echoinfo "Please type oafe password and verify"
    htpasswd -c /etc/nginx/conf.d/oafe.htpasswd oafe
    cp -f /opt/oafe/OAFE/conf/nginx/default-nginx /etc/nginx/sites-available/default

echoinfo "Creating GeoIP config and downloading current databases"
    cp /opt/oafe/OAFE/conf/GeoIP/GeoIP.conf /etc/GeoIP.conf >> $HOME/oafe-install.log || return 1
    geoipupdate >> $HOME/oafe-install.log || return 1

echoinfo "Installing Elasticsearch, Kibana, Logstash, and Graylog as services"
    if [ ! -d /opt/oafe/OAFE/Packages/ ]; then
        mkdir -p /opt/oafe/OAFE/Packages/
        chown oafe:oafe /opt/oafe/OAFE/Packages/
        chmod -R 775 /opt/oafe/OAFE/Packages/
        chmod -R g+s /opt/oafe/OAFE/Packages/
    fi
    wget -O /opt/oafe/OAFE/Packages/elasticsearch-5.3.2.deb https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.3.2.deb
    wget -O /opt/oafe/OAFE/Packages/kibana-5.3.2-amd64.deb https://artifacts.elastic.co/downloads/kibana/kibana-5.3.2-amd64.deb
    wget -O /opt/oafe/OAFE/Packages/filebeat-5.3.2-amd64.deb https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-5.3.2-amd64.deb
    dpkg -i /opt/oafe/OAFE/Packages/elasticsearch-5.3.2.deb
    dpkg -i /opt/oafe/OAFE/Packages/filebeat-5.3.2-amd64.deb
    dpkg -i /opt/oafe/OAFE/Packages/kibana-5.3.2-amd64.deb
    if [ ! -d /etc/logstash/conf.d/ ]; then
        mkdir -p /etc/logstash/conf.d/
        chown oafe:oafe /etc/logstash/conf.d/
        chmod -R 775 /etc/logstash/conf.d/
        chmod -R g+s /etc/logstash/conf.d/
    fi
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/logstash_kansa_ingest.conf /etc/logstash/conf.d/logstash_kansa_ingest.conf >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/bro-appstats.conf /etc/logstash/conf.d/bro-appstats.conf  >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/bro-dns.conf /etc/logstash/conf.d/bro-dns.conf  >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/bro-files.conf /etc/logstash/conf.d/bro-files.conf  >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/bro-weird.conf /etc/logstash/conf.d/bro-weird.conf  >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/sensor.conf /etc/logstash/conf.d/logstash_maltrail_sensor.conf  >> $HOME/oafe-install.log
#    cp -f /opt/oafe/OAFE/conf/elasticsearch/elasticsearch.in.sh /usr/share/elasticsearch/bin/ >> $HOME/oafe-install.log
#    cp -f /opt/oafe/OAFE/conf/kibana/kibana.yml /opt/kibana/config/kibana.yml  >> $HOME/oafe-install.log || return 1
    #moving over rc.local file
    cp -f /etc/rc.local /etc/rc.local.backup >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/etc/rc.local /etc/rc.local >> $HOME/oafe-install.log
    systemctl daemon-reload
    systemctl enable elasticsearch
    systemctl enable kibana
    systemctl enable filebeat
    systemctl start elasticsearch
    sleep 1m
    systemctl start kibana
    systemctl start filebeat
    cp -f /opt/oafe/OAFE/etc/elasticsearch/jvm.options /etc/elasticsearch/jvm.options
    wget -O /opt/oafe/OAFE/Packages/logstash-5.3.2.zip https://artifacts.elastic.co/downloads/logstash/logstash-5.3.2.zip
    unzip /opt/oafe/OAFE/Packages/logstash-5.3.2.zip -d /opt/oafe/ >> $HOME/oafe-install.log 2>&1
    mv -f /opt/oafe/logstash-5.3.2/ /opt/oafe/logstash >> $HOME/oafe-install.log 2>&1
    sudo ln -s -f /opt/oafe/logstash/bin/logstash /usr/bin/logstash >> $HOME/oafe-install.log 2>&1
    sudo ln -s -f /opt/oafe/logstash/bin/logstash-plugin /usr/bin/logstash-plugin >> $HOME/oafe-install.log 2>&1
    sudo ln -s -f /opt/oafe/logstash/bin/logstash.lib.sh /usr/bin/logstash.lib.sh >> $HOME/oafe-install.log 2>&1
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/start /opt/oafe/logstash/start  >> $HOME/oafe-install.log
    cp -f /opt/oafe/OAFE/conf/logstash/ingest/stop /opt/oafe/logstash/stop  >> $HOME/oafe-install.log
/opt/oafe/logstash/bin/logstash-plugin install logstash-filter-translate >> $HOME/oafe-install.log 2>&1

echoinfo "Install Kibi"

wget -O /opt/oafe/OAFE/Packages/kibi-community-standalone-5.2.2-beta-1-linux-x64.zip https://download.support.siren.solutions/kibi/community?file=kibi-community-standalone-5.2.2-beta-1-linux-x64.zip
if [ -f "/opt/oafe/OAFE/Packages/kibi-community-standalone-5.2.2-beta-1-linux-x64.zip" ];
    then
      echo "kibi-community-standalone-5.2.2-beta-1-linux-x64.zip found."
      chmod -R 775 /opt/oafe/
      chmod 777 /opt/oafe/OAFE/Packages/kibi-community-standalone-5.2.2-beta-1-linux-x64.zip  >> $HOME/oafe-install.log || return 1
	  unzip /opt/oafe/OAFE/Packages/kibi-community-standalone-5.2.2-beta-1-linux-x64.zip -d /opt/oafe/ >> $HOME/oafe-install.log || return 1
      mv -f /opt/oafe/kibi-community-standalone-5.2.2-beta-1-linux-x64 /opt/oafe/kibi  >> $HOME/oafe-install.log || return 1
      chmod -R 777 /opt/oafe/kibi  >> $HOME/oafe-install.log || return 1
      chown oafe:oafe /opt/oafe/kibi  >> $HOME/oafe-install.log || return 1
      chmod g+s /opt/oafe/kibi  >> $HOME/oafe-install.log || return 1
      cp -f /opt/oafe/OAFE/conf/kibi/kibi.yml /opt/oafe/kibi/config/kibi.yml  >> $HOME/oafe-install.log || return 1
      cp -f /opt/oafe/OAFE/conf/systemd/kibi.service /etc/systemd/system/kibi.service  >> $HOME/oafe-install.log || return 1
#      /opt/oafe/kibi/bin/kibi plugin -i kibana-html-plugin -u https://github.com/raystorm-place/kibana-html-plugin/releases/download/v0.0.3/kibana-html-plugin-v0.0.3.tar.gz
      systemctl daemon-reload  >> $HOME/oafe-install.log || return 1
      systemctl enable kibi  >> $HOME/oafe-install.log || return 1
      systemctl start kibi  >> $HOME/oafe-install.log || return 1
    else
    	echo "kibi-community-standalone-5.2.2-beta-1-linux-x64.zip not found."
fi

echoinfo "Starting BRO IDS"
    cp -f /opt/oafe/OAFE/conf/bro/node.cfg /etc/bro/node.cfg >> $HOME/oafe-install.log
    broctl deploy >> $HOME/oafe-install.log 2>&1
    cp /opt/oafe/OAFE/etc/cron.d/broctl /etc/cron.d/broctl >> $HOME/oafe-install.log

echoinfo "Installing Maltrail"
        if [ ! -d /opt/oafe/maltrail ]; then
		mkdir -p /opt/oafe/maltrail
		chown $SUDO_USER:$SUDO_USER /opt/oafe/maltrail
		chmod -R 775 /opt/oafe/maltrail
		chmod -R g+s /opt/oafe/maltrail
	fi
        if [ ! -d /var/log/maltrailsensor ]; then
		mkdir -p /var/log/maltrailsensor
		chown $SUDO_USER:$SUDO_USER /var/log/maltrailsensor
		chmod -R 775 /var/log/maltrailsensor
		chmod -R g+s /var/log/maltrailsensor
	fi
        if [ ! -d /var/log/maltrailserver ]; then
		mkdir -p /var/log/maltrailserver
		chown $SUDO_USER:$SUDO_USER /var/log/maltrailserver
		chmod -R 775 /var/log/maltrailserver
		chmod -R g+s /var/log/maltrailserver
	fi
        git clone https://github.com/stamparm/maltrail.git /opt/oafe/maltrail >> $HOME/oafe-install.log 2>&1
	cp -f /opt/oafe/OAFE/conf/systemd/maltrailserver.service /lib/systemd/system/maltrailserver.service >> $HOME/oafe-install.log || return 1
        cp -f /opt/oafe/OAFE/conf/systemd/maltrail-sensor.service /lib/systemd/system/maltrail-sensor.service >> $HOME/oafe-install.log || return 1
        cp -f /opt/oafe/OAFE/conf/maltrail/maltrail.conf /opt/oafe/maltrail/maltrail.conf >> $HOME/oafe-install.log || return 1
        systemctl daemon-reload >> $HOME/oafe-install.log || return 1
	systemctl enable maltrailserver.service >> $HOME/oafe-install.log || return 1
        systemctl enable maltrail-sensor >> $HOME/oafe-install.log || return 1

echoinfo "Installing Moloch DPI"
#	sleep 1m
	systemctl start elasticsearch
	wget -O /opt/oafe/OAFE/Packages/moloch_0.18.3-1_amd64.deb https://files.molo.ch/builds/ubuntu-16.04/moloch_0.18.3-1_amd64.deb
  if [ -f "/opt/oafe/OAFE/Packages/moloch_0.18.3-1_amd64.deb" ];
    then
      echo "moloch_0.18.3-1_amd64.deb found."
      dpkg -i /opt/oafe/OAFE/Packages/moloch_0.18.3-1_amd64.deb
      echoinfo "Please choose your capture interface.  On DL380G9, this is eno1.  On mini or Z Workstations, the span port should be the onboard adapter.  It will be eno1"
    	/data/moloch/bin/Configure
    	/data/moloch/db/db.pl http://localhost:9200 init
    	/data/moloch/bin/moloch_add_user.sh admin admin changeme! --admin
    	cp -f /opt/oafe/OAFE/conf/moloch/config.ini /data/moloch/etc/config.inie >> $HOME/oafe-install.log || return 1
      #this line changes the path to ethtool from /usr/sbin/ to just /sbin/
      sed -i.bak 's_ExecStartPre=-/usr/sbin/ethtool_ExecStartPre=-/sbin/ethtool_g' /etc/systemd/system/molochcapture.service
      systemctl daemon-reload
    	systemctl enable molochcapture
    	systemctl enable molochviewer
    	sleep 1m
    	systemctl start molochcapture.service
    	systemctl start molochviewer.service
    cp -f /opt/oafe/OAFE/conf/moloch/daily.sh /data/moloch/db/daily.sh >> $HOME/oafe-install.log || return 1
    echo "0 1 * * * /data/moloch/db/daily.sh" | tee -a /var/spool/cron/root
    else
    	echo "moloch_0.18.3-1_amd64.deb not found."
  fi

echoinfo "Enabling Google Rapid Response Installer"
        if [ ! -d /opt/oafe/grr ]; then
		mkdir -p /opt/oafe/grr
		chown $SUDO_USER:$SUDO_USER /opt/oafe/grr
		chmod -R 775 /opt/oafe/grr
		chmod -R g+s /opt/oafe/grr
	fi
        wget -O /opt/oafe/grr/install_google_rapid_response.sh https://raw.githubusercontent.com/google/grr/master/scripts/install_script_ubuntu.sh  >> $HOME/oafe-install.log || return 1
        chmod -c 775 /opt/oafe/grr/install_google_rapid_response.sh >> $HOME/oafe-install.log || return 1

#echoinfo "Install Kansa Files for Threat Hunting"
#    if [ ! -d /opt/oafe/kansa ]; then
#        mkdir -p /opt/oafe/kansa
#        chown $SUDO_USER:$SUDO_USER /opt/oafe/kansa
#        chmod -R 775 /opt/oafe/kansa
#        chmod -R g+s /opt/oafe/kansa
#    fi
#    cp -f /opt/oafe/OAFE/conf/logstash/ingest/logstash_kansa_ingest.conf /etc/logstash/conf.d/logstash_kansa_ingest.conf
#    git clone https://github.com/davehull/Kansa /opt/oafe/kansa

echoinfo "Install Fast Incident Response Docker Build"
    cd /opt/oafe/OAFE/FIR
    docker build -t fir .

#ecchoinfo "Install FAME"


#echoinfo "Install Viper Framework"
#    git clone https://github.com/viper-framework/viper /opt/oafe/viper >> $HOME/oafe-install.log || return 1
#    chmod -R 775 /opt/oafe/viper >> $HOME/oafe-install.log || return 1
#    chown oafe:oafe /opt/oafe/viper >> $HOME/oafe-install.log || return 1
#    chmod g+s /opt/oafe/viper >> $HOME/oafe-install.log || return 1
#    cp -f /opt/oafe/OAFE/conf/systemd/viperweb.service /etc/systemd/system/viperweb.service >> $HOME/oafe-install.log || return 1
#    cp -f /opt/oafe/OAFE/conf/systemd/viper.service /etc/systemd/system/viper.service >> $HOME/oafe-install.log || return 1

echoinfo "Enabling ntop netflow capture services"
    systemctl daemon-reload >> $HOME/oafe-install.log || return 1
    systemctl enable ntopng >> $HOME/oafe-install.log || return 1

#echoinfo "Installing Cuckoo Sandbox"
#sleep 1m
#        if [ ! -d /opt/oafe/VMs ]; then
#		mkdir -p /opt/oafe/VMs
#		chown $SUDO_USER:$SUDO_USER /opt/oafe/VMs
#	 	chmod -R 775 /opt/oafe/VMs
#		chmod -R g+s /opt/oafe/VMs
#	fi
#        if [ ! -d /opt/oafe/cuckoodeps ]; then
#		mkdir -p /opt/oafe/cuckoodeps
#		chown $SUDO_USER:$SUDO_USER /opt/oafe/cuckoodeps
#	 	chmod -R 775 /opt/oafe/cuckoodeps
#		chmod -R g+s /opt/oafe/cuckoodeps
#	fi
#        if [ ! -d /var/log/cuckooweb ]; then
#		mkdir -p /var/log/cuckooweb
#		chown $SUDO_USER:$SUDO_USER /var/log/cuckooweb
#	 	chmod -R 775 /var/log/cuckooweb
#		chmod -R g+s /var/log/cuckooweb
#	fi
#        if [ ! -d /var/log/cuckoo ]; then
#		mkdir -p /var/log/cuckoo
#		chown $SUDO_USER:$SUDO_USER /var/log/cuckoo
#	 	chmod -R 775 /var/log/cuckoo
#		chmod -R g+s /var/log/cuckoo
#	fi
#        if [ ! -d /var/log/cuckooapi ]; then
#		mkdir -p /var/log/cuckooapi
#		chown $SUDO_USER:$SUDO_USER /var/log/cuckooapi
#	 	chmod -R 775 /var/log/cuckooapi
#		chmod -R g+s /var/log/cuckooapi
#	fi
#        if [ ! -d /opt/oafe/cuckoo ]; then
#        mkdir -p /opt/oafe/cuckoo
#        chown cuckoo:cuckoo /opt/oafe/cuckoo
#        chmod -R 775 /opt/oafe/cuckoo
#        chmod -R g+s /opt/oafe/cuckoo
#    fi
#        usermod -a -G vboxusers oafe
#        usermod -a -G vboxusers cuckoo
#        wget -O /opt/oafe/cuckoodeps/volatility-2.6.zip http://downloads.volatilityfoundation.org/releases/2.6/volatility-2.6.zip
#        cd /opt/oafe/cuckoodeps
#        unzip volatility-2.6.zip
#        mv -f volatility-master .. ; cd ../volatility-master && chmod +x vol.py
#        ln -f -s "${PWD}"/vol.py /usr/local/bin/vol.py
#        sysctl -w net.ipv4.ip_forward=1 >> $HOME/oafe-install.log || return 1
#        setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump >> $HOME/oafe-install.log || return 1
#        mysql -uroot -pchangeme! -e "CREATE DATABASE cuckoo" >> $HOME/oafe-install.log || return 1
#        mysql -uroot -pchangeme! -e "GRANT ALL PRIVILEGES ON *.* TO cuckoo@localhost IDENTIFIED BY 'changeme!'" >> $HOME/oafe-install.log || return 1
#        mysql -uroot -pchangeme! -e "FLUSH PRIVILEGES" >> $HOME/oafe-install.log || return 1
#        pip install -U cuckoo
#        if [ ! -d /opt/oafe/cuckoo/uwsgi ]; then
#        	mkdir -p /opt/oafe/cuckoo/uwsgi
#        	chown $SUDO_USER:$SUDO_USER /opt/oafe/cuckoo/uwsgi
#        	chmod -R 775 /opt/oafe/cuckoo/uwsgi
#        	chmod -R g+s /opt/oafe/cuckoo/uwsgi
#    	fi
#        cuckoo --cwd /opt/oafe/cuckoo
#        wget - O /opt/oafe/cuckoodeps/sdk-tools-linux-3859397.zip https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip#        vboxmanage hostonlyif create >> $HOME/oafe-install.log || return 1
#        ip link set vboxnet0 up >> $HOME/oafe-install.log || return 1
#	    ip addr add 192.168.56.1/24 dev vboxnet0
#       cp -f /opt/oafe/OAFE/conf/cuckoo/rules.v4 /etc/iptables/rules.v4 >> $HOME/oafe-install.log || return 1
#        python /opt/oafe/cuckoo/utils/community.py -a -f -w >> $HOME/oafe-install.log || return 1
#		systemctl daemon-reload >> $HOME/oafe-install.log || return 1

#echoinfo "OAFE VM: Creating Cases Folder"
#    if [ ! -d /cases ]; then
#	mkdir -p /cases
#	chown $SUDO_USER:$SUDO_USER /cases
#	chmod 775 /cases
#	chmod g+s /cases
#    fi

echoinfo "OAFE VM: Creating Mount Folders"
#    for dir in usb vss shadow windows_mount e01 aff ewf bde iscsi
#   do
#	if [ ! -d /mnt/$dir ]; then
#	    mkdir -p /mnt/$dir
#	fi
#    done

#    for NUM in 1 2 3 4 5
#    do
#	if [ ! -d /mnt/windows_mount$NUM ]; then
#		mkdir -p /mnt/windows_mount$NUM
#	fi
#	if [ ! -d /mnt/ewf_mount$NUM ]; then
#		mkdir -p /mnt/ewf_mount$NUM
#	fi
#   done

#    for NUM in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
#    do
#	if [ ! -d /mnt/shadow/vss$NUM ]; then
#		mkdir -p /mnt/shadow/vss$NUM
#	fi
#	if [ ! -d /mnt/shadow_mount/vss$NUM ]; then
#		mkdir -p /mnt/shadow_mount/vss$NUM
#	fi
#   done

echoinfo "OAFE VM: Setting up symlinks to useful scripts"
    if [ ! -L /usr/bin/vol.py ] && [ ! -e /usr/bin/vol.py ]; then
        ln -s /usr/bin/vol.py /usr/bin/vol
    fi
    if [ ! -L /usr/bin/log2timeline ] && [ ! -e /usr/bin/log2timeline ]; then
	ln -s /usr/bin/log2timeline_legacy /usr/bin/log2timeline
    fi
    if [ ! -L /usr/bin/kedit ] && [ ! -e /usr/bin/kedit ]; then
	ln -s /usr/bin/gedit /usr/bin/kedit
    fi
    if [ ! -L /usr/bin/mount_ewf.py ] && [ ! -e /usr/bin/mount_ewf.py ]; then
	ln -s /usr/bin/ewfmount /usr/bin/mount_ewf.py
    fi

    if [ ! -L /usr/local/etc/foremost.conf ]; then
        ln -s /etc/foremost.conf /usr/local/etc/foremost.conf
    fi

    sed -i "s/APT::Periodic::Update-Package-Lists \"1\"/APT::Periodic::Update-Package-Lists \"0\"/g" /etc/apt/apt.conf.d/10periodic

    echoinfo "Start IVRE Depedencies"
    #start IVRE web interface required services
    echoinfo "starting php7.0-fpm service"
    service php7.0-fpm start
    echoinfo "starting fcgiwrap service"
    service fcgiwrap start

    #fixing permissions for systemd services, they should be set to 644
    sudo chmod 0644 /etc/systemd/system/kibi.service
}

complete_message() {
    echo
    echo "Installation Complete!"
    echo
    echo "Obtain an OpenVPN OAFENET configuration file"
    echo "Copy the OAFE vpn configration file to /etc/openvpn/"
    echo "be sure to rename the .ovpn file to .conf"
    echo
    echo "The Google Rapid Response Installer will need to be run after the reboot."
    echo "It is located at /opt/oafe/grr/install_google_rapid_response.sh"
    echo
    echo "Documentation: http://oafe.readthedocs.org"
    echo
    echo "If you installed FIR you will need to change the IP address and hostname, as well as the config files for FIR to match the IP change"
    echo
}

UPGRADE_ONLY=0
CONFIGURE_ONLY=0
SKIN=0
INSTALL=1
YESTOALL=0
CONFIGURE_CUCKOO=0

OS=$(lsb_release -si)
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VER=$(lsb_release -sr)

if [ $OS != "Ubuntu" ]; then
    echo "SIFT is only installable on Ubuntu operating systems at this time."
    exit 1
fi

if [ $ARCH != "64" ]; then
    echo "OAFE is only installable on a 64 bit architecture at this time."
    exit 2
fi

if [ $VER != "16.04" ]; then
    echo "OAFE is only installable on Ubuntu 16.04 at this time."
    exit 3
fi

if [ `whoami` != "root" ]; then
    echoerror "The OAFE Bootstrap script must run as root."
    echoinfo "Preferred Usage: sudo bootstrap.sh (options)"
    echo ""
    exit 3
fi

if [ "$SUDO_USER" = "" ]; then
    echo "The SUDO_USER variable doesn't seem to be set"
    exit 4
fi

while getopts ":hvcsiyudt" opt
do
case "${opt}" in
    h ) usage; exit 0 ;;
    v ) echo "$0 -- Version $__ScriptVersion"; exit 0 ;;
    s ) SKIN=1 ;;
    i ) INSTALL=1 ;;
    c ) CONFIGURE_ONLY=1; INSTALL=0; SKIN=0; ;;
    u ) UPGRADE_ONLY=1; ;;
    y ) YESTOALL=1 ;;
    m ) CONFIGURE_CUCKOO=1 ;;
    \?) echo
        echoerror "Option does not exist: $OPTARG"
        usage
        exit 1
        ;;
esac
done

shift $(($OPTIND-1))

if [ "$#" -eq 0 ]; then
    ITYPE="stable"
else
    __check_unparsed_options "$*"
    ITYPE=$1
    shift
fi
  export DEBIAN_FRONTEND=noninteractive

  remove_bad_old_deps || echoerror "Removing Old Depedencies Failed"
  install_ubuntu_${VER}_deps $ITYPE || echoerror "Updating Depedencies Failed"
  install_ubuntu_${VER}_packages $ITYPE || echoerror "Updating Packages Failed"
  install_ubuntu_${VER}_pip_packages $ITYPE || echoerror "Updating Python Packages Failed"
  install_perl_modules || echoerror "Updating Perl Packages Failed"
  #install_sift_files || echoerror "Installing/Updating SIFT Files Failed"

  echo ""
  echoinfo "SIFT Upgrade Complete"
  exit 0
fi

# Check installation type
if [ "$(echo $ITYPE | egrep '(dev|stable)')x" = "x" ]; then
    echoerror "Installation type \"$ITYPE\" is not known..."
    exit 1
fi

echoinfo "This script will now proceed to configure your system."

if [ "$YESTOALL" -eq 1 ]; then
    echoinfo "You supplied the -y option, this script will not exit for any reason"
fi

echoinfo "OS: $OS"
echoinfo "Arch: $ARCH"
echoinfo "Version: $VER"

if [ "$SKIN" -eq 1 ] && [ "$YESTOALL" -eq 0 ]; then
    echo
    echo "You have chosen to apply the SIFT skin to your ubuntu system."
    echo
    echo "You did not choose to say YES to all, so we are going to exit."
    echo
    echo "Your current user is: $SUDO_USER"
    echo
    echo "Re-run this command with the -y option"
    echo
    exit 10
fi

if [ "$INSTALL" -eq 1 ] && [ "$CONFIGURE_ONLY" -eq 0 ]; then
    export DEBIAN_FRONTEND=noninteractive
    install_ubuntu_${VER}_deps $ITYPE
    install_ubuntu_${VER}_packages $ITYPE
    install_ubuntu_${VER}_pip_packages $ITYPE
    configure_cpan
    install_perl_modules
    install_sift_files
fi

if [ "$CONFIGURE_CUCKOO" -eq 1 ]; then
	install_cuckoo_sandbox
fi

# Configure for SIFT
configure_ubuntu

complete_message

apt-get remove -y whoopsie
end=$(date +%s.%N)
runtime=$(python -c "print(${end} - ${start})")
echo "Runtime was $runtime" >> $HOME/oafe-install.log
