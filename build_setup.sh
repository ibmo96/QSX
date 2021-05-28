#!/bin/bash

# Copyright (C) OQX.

#Script to setup prerequesites for an OQS-enabled NGINX server - for DEBIAN-based systems.

# FUNCTIONS

## Dependencies needed

function get_dependencies {
	sudo apt install cmake gcc libtool libssl-dev make ninja-build git doxygen python3-pip libpcre3 libpcre3-dev
	
	pip install common
}

## Clone down liboqs and OQS-OpenSSL
function get_libs {
    git clone --branch OQS-OpenSSL_1_1_1-stable https://github.com/open-quantum-safe/openssl.git
    git clone --branch main https://github.com/open-quantum-safe/liboqs.git
}

## Retrieve the NGINX sourcefiles
function get_nginx {
    wget nginx.org/download/nginx-$NGINX_VER.tar.gz && tar -zxvf nginx-$NGINX_VER.tar.gz;
}


function test_echo {
echo "dir variable is set to: $LIB_DIR"

}


# variables for directories and build params:

LIB_DIR='/opt'
NGINX_VER=$(nginx -V  2>&1 | grep 'nginx version:' | awk '{print $2}' FS='nginx version: nginx/')
MAKE_PARAM='-j 2'
LIBOQS_BUILD_PARAM ='-DOQS_DIST_BUILD=ON'
SIG_ALG='dilithium2'

#USER INPUT FOR VARIABLES


echo ""
echo "=================================================================="
echo 'This is the setup script for the QSX tool!'
echo 'Please make sure you are on root user, as some necessary dependencies will be installed' 
echo "=================================================================="

#Liboqs directory

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

echo 'working directory is set to: ${LIB_DIR}'

get_dependencies
get_nginx

## Build liboqs 
cd $LIB_DIR/liboqs && mkdir build && cd build && cmake -G"Ninja" LIBOQS_BUILD_PARAM -DBUILD_SHARED_LIBS=OFF -DOQS_USE_CPU_EXTENTIONS=OFF -DCMAKE_INSTALL_PREFIX=$LIB_DIR/openssl/oqs .. && ninja && ninja install 


# Retrieve current NGINX config arguments, append arguments for redirect openssl to OQS openssl


echo ""
echo 'Retrieving current NGINX configuration arguments...'

my_command=$(nginx -V  2>&1 | grep 'configure arguments:' | awk '{print $2}' FS='configure arguments:')

#input OQS openssl compiler refference in nginx configure arguments
my_command=$(sed "s/--with-cc-opt='/--with-cc-opt='-I$LIB_DIR/openssl/oqs/include /"<<< $my_command)
my_command=$(sed "s/--with-ld-opt='/--with-ld-opt='-L$LIB_DIR/openssl/oqs/lib/"<<< $my_command)
my_command=$(sed "s/\--add-dynamic-module.*//" <<< $my_command) #omits dynamic modules is they can cause issues when configuring

## Build nginx (will also build OQS-openssl)
cd $LIB_DIR/nginx-$NGINX_VER && ./configure --with-openssl=$LIB_DIR/openssl $my_command && sed -i 's/libcrypto.a/libcrypto.a -loqs/g' objs/Makefile && make $MAKE_PARAM && make install

#upgrade new binary file
sudo mv /usr/sbin/nginx /usr/sbin/nginx_old
sudo mv /usr/local/nginx/sbin/nginx /usr/sbin/nginx


echo ""
echo "=================================================================="
echo "Do you wish to generate a post-quantum certificate (self-signed)?"
echo "=================================================================="
select yn in "Yes" "No"; do
    case $yn in
        Yes ) source gen_cert.sh; break;;
        No ) exit;;
    esac
done

echo ""
echo "Sending Nginx signals to gracefully upgrade your Nginx binary/configuration...."
source nginx_signal.sh



echo ""
echo "=================================================================="
echo 'Congratulations! Your NGINX server is now capable of handling quantum-resistant TLS sessions!'
echo "=================================================================="



## --END --
