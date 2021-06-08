
#!/bin/bash

#Script to setup prerequesites for an OQS-enabled NGINX server - for DEBIAN-based systems.

echo ""
echo "=================================================================="
echo 'This is the setup script for the QSX tool!'
echo 'Please make sure you are on root and have Nginx installed' 
echo "=================================================================="

#Check for root user
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

#Check for Nginx installation 
if ! [ -x "$(command -v nginx)" ]; then
  echo 'Error: Nginx is not installed.' >&2
  exit 1
fi

# FUNCTIONS

## Dependencies needed
function get_dependencies {
	echo ""
	echo "Checking/installation dependencies..."
	echo ""
	INSTALL_PKGS="cmake gcc libtool libssl-dev make ninja-build git doxygen python3-pip libpcre3 libpcre3-dev libxslt1-dev libxml2-dev libxml2 libgd-dev libgeoip-dev"
        for i in $INSTALL_PKGS; do
  		sudo apt-get install -y $i
	done
	
	wget sourceforge.net/projects/libpng/files/zlib/1.2.9/zlib-1.2.9.tar.gz && tar -xvf zlib-1.2.9.tar.gz && cd zlib-1.2.9 && ./configure && make && make install && cd /lib/x86_64-linux-gnu && ln -s -f /usr/local/lib/libz.so.1.2.9/lib libz.so.1 && cd ~ && rm -rf zlib-1.2.9 || exit 1
	pip3 install common
}

## Clone down liboqs and OQS-OpenSSL
function get_libs {
    echo ""
    echo "Cloning down OQS libraries..."
    echo ""
    git clone --branch OQS-OpenSSL_1_1_1-stable https://github.com/open-quantum-safe/openssl.git
    git clone --branch main https://github.com/open-quantum-safe/liboqs.git
}

## Retrieve the NGINX sourcefiles
function get_nginx {
     echo ""
    echo "Getting Nginx source..."
    echo ""
    wget nginx.org/download/nginx-$NGINX_VER.tar.gz && tar -zxvf nginx-$NGINX_VER.tar.gz;
}

# variables for directories and build params:

TOOL_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LIB_DIR='/opt'
NGINX_VER=$(nginx -V  2>&1 | grep 'nginx version:' | awk '{print $2}' FS='nginx version: nginx/' | sed 's/\s.*$//')
MAKE_PARAM='-j 2'
LIBOQS_BUILD_PARAM="-DOQS_DIST_BUILD=ON -DBUILD_SHARED_LIBS=OFF -DOQS_USE_CPU_EXTENTIONS=OFF -DCMAKE_INSTALL_PREFIX=$LIB_DIR/openssl/oqs .."
SIG_ALG='dilithium2'


#Directory selection
echo ""
echo "=================================================================="
echo 'Specify a directory for installing liboqs, openssl and nginx sourcefiles. If you dont wish to, press enter and they will be installed in /opt"' 
echo "=================================================================="

read DIR_RES

if [[ -z $DIR_RES ]]
then
	cd $LIB_DIR && get_libs
	#test_echo
else
	LIB_DIR=$DIR_RES
	cd $LIB_DIR && get_libs
	#test_echo
fi

get_dependencies
get_nginx

echo ""
echo "Building liboqs..."
## Build liboqs 
cd $LIB_DIR/liboqs && mkdir build && cd build && cmake -G"Ninja" $LIBOQS_BUILD_PARAM && ninja && ninja install 


# Retrieve current NGINX config arguments, append arguments for redirect openssl to OQS openssl

echo ""
echo 'Retrieving current NGINX configuration arguments...'

my_command=$(nginx -V  2>&1 | grep 'configure arguments:' | awk '{print $2}' FS='configure arguments:')

#Create array of configure arguments
#concat_commands=$(echo $my_command | sed 's|--|\n|g')
#counter=1 #start at 1, 0 is whitespace
#readarray -t array <<<"$concat_commands"

#found_prefix=false
#found_conf=false
#found_cc_opt=false
#found_ld_opt=false

#make sure prefix is set to share/usr/nginx

#configure_arguments=()
#for i in "${array[@]}"
#do
 #   configure_arguments[$counter]="--$i"
 #   counter=$((counter + 1))
#done

#remove first whitespace element
#unset configure_arguments[1]

#append OQS-OpenSSL location to list of arguments
#configure_arguments+=("--with-openssl=$LIB_DIR/openssl")

#input OQS openssl compiler refference in nginx configure arguments
my_command=$(sed "s|--with-cc-opt='.*'|--with-cc-opt='-I$LIB_DIR/openssl/oqs/include' --with-ld-opt='-L$LIB_DIR/openssl/oqs/lib'|"<<< $my_command)
#my_command=$(sed "s|--with-ld-opt='.*'|--with-ld-opt='-L$LIB_DIR/openssl/oqs/lib'|"<<< $my_command)
my_command=$(sed "s|--add-dynamic-module.*||" <<< $my_command) #omits dynamic modules is they can cause issues when configuring

## Build nginx (will also build OQS-openssl)
cd $LIB_DIR/nginx-$NGINX_VER && ./configure $my_command --with-openssl=$LIB_DIR/openssl && sed -i 's/libcrypto.a/libcrypto.a -loqs/g' objs/Makefile && make $MAKE_PARAM && make install || exit 1
#cd $LIB_DIR/nginx-$NGINX_VER && ./configure --prefix=/usr/share/nginx --pid-path=/run/nginx.pid --conf-path=/etc/nginx/nginx.conf --with-http_ssl_module --with-openssl=$LIB_DIR/openssl --with-cc-opt="-I$LIB_DIR/openssl/oqs/include" --with-ld-opt="-L$LIB_DIR/openssl/oqs/lib" && sed -i 's/libcrypto.a/libcrypto.a -loqs/g' objs/Makefile && make $MAKE_PARAM && make install || exit 1

#upgrade new binary file 
sudo mv /usr/sbin/nginx /usr/sbin/nginx_old
sudo mv /usr/share/nginx/sbin/nginx /usr/sbin/nginx

echo ""
echo "=================================================================="
echo "Do you wish to generate a post-quantum certificate (self-signed)?"
echo "=================================================================="
select yn in "Yes" "No"; do
    case $yn in
        Yes ) source $TOOL_DIR/gen_cert.sh; break;;
        No ) break;;
    esac
done

# Send Nginx sourcefiles
source $TOOL_DIR/nginx_signal.sh


echo ""
echo "=================================================================="
echo 'Congratulations! Your NGINX server is now capable of handling quantum-resistant TLS sessions!'
echo "=================================================================="



## --END --
