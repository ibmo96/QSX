#!/bin/bash

# Copyright (C) OQX.

#Script to setup prerequesites for an OQS-enabled NGINX server - for DEBIAN-based systems.

# FUNCTIONS

## Dependencies needed

function get_dependencies {
	sudo apt install cmake gcc libtool libssl-dev make ninja-build git doxygen python3-pip
	
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
  ## NGINX VERSION (please specify the latest stable version, currently this tool is experiencing compatability issues with the  mainline version)
NGINX_VER='1.18.0'
MAKE_PARAM='-j 2'
LIBOQS_BUILD_PARAM ='-DOQS_DIST_BUILD=ON'
SIG_ALG='dilithium2'

#USER INPUT FOR VARIABLES

echo 'This is the setup script for the OQS-MOFF tool!'
echo 'Please make sure you are on root user, as some necessary dependencies will be installed' 

#Liboqs directory

echo 'Specify a directory for installing liboqs, openssl and nginx sourcefiles. If you dont wish to, press enter and they will be installed in /opt"' 

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

#Nginx Version

echo 'Input the desired NGINX version in the following format: \"1.xx.x\", else press enter and version 1.18.0 will be used'

read VER_RES

if [[ -z $VER_RES ]]
then
	echo 'using nginx version:  $NGINX_VER'
	get_nginx
else
	NGINX_VER=$VER_RES
	echo 'nginx ver is set to: $NGINX_VER'
	cd $LIB_DIR && get_nginx
fi


get_dependencies


## Build liboqs 
cd $LIB_DIR/liboqs && mkdir build && cd build && cmake -G"Ninja" LIBOQS_BUILD_PARAM -DBUILD_SHARED_LIBS=OFF -DOQS_USE_CPU_EXTENTIONS=OFF -DCMAKE_INSTALL_PREFIX=$LIB_DIR/openssl/oqs .. && ninja && ninja install 


# Retrieve current NGINX config arguments, append arguments for redirect openssl to OQS openssl

echo 'Retrieving current NGINX configuration arguments...'

my_command=$(nginx -V  2>&1 | grep 'configure arguments:' | awk '{print $2}' FS='configure arguments:')
echo $my_command


## Build nginx (will also build OQS-openssl) 
cd $LIB_DIR/nginx-$NGINX_VER && ./configure $my_command --with-debug --with-http_ssl_module --with-openssl=$LIB_DIR/openssl --without-http_gzip_module --with-cc-opt=-I$LIB_DIR/openssl/oqs/include --with-ld-opt="-L$LIB_DIR/openssl/oqs/lib" --without-http-rewrite_module && sed -i 's/libcrypto.a/libcrypto.a -loqs/g' objs/Makefile && make $MAKE_PARAM && make install &&

#upgrade new binary file
sudo mv /usr/sbin/nginx /usr/sbin/nginx_old
sudo mv /usr/local/nginx/sbin/nginx /usr/sbin/nginx


# Get domain-name (credit: https://gist.github.com/Tucker-Eric/c9341e1e75aac3213963a17018a1b6e0) 
echo "What is the domain you would like to generate a quantum-safe certificate for?"
read DOMAIN

'''
# check the domain is valid!   
PATTERN="^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$";
if [[ "$DOMAIN" =~ $PATTERN ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating hosting for:" $DOMAIN
else
	echo "invalid domain name"
	exit 1
fi
'''

## Create test certificate using OQS domain
set -x #prints executed commands 
cd $LIB_DIR && mkdir cacert & mkdir pki && 
$LIB_DIR/openssl/apps/openssl req -x509 -new -newkey $SIG_ALG -keyout CA.key -out cacert/CA.crt -nodes -subj "/CN=$DOMAIN" -days 365 -config $LIB_DIR/openssl//apps/openssl.cnf && 
 $LIB_DIR/openssl/apps/openssl req -new -newkey $SIG_ALG -keyout pki/$DOMAIN\_server.key -out $DOMAIN\_server.csr -nodes -subj "/CN=$DOMAIN" -config $LIB_DIR/openssl/apps/openssl.cnf &&
$LIB_DIR/openssl/apps/openssl x509 -req -in $DOMAIN\_server.csr -out pki/$DOMAIN\_server.crt -CA cacert/CA.crt -CAkey CA.key -CAcreateserial -days 365



# Read which port user wants to run quantum-safe server on
echo "What port would you like the quantum-safe server to listen on? You can specify either an already used port and we will update the certificate, or an unused port. If you are unsure, press enter and port 443 will be used."
PORT=443
read TMP_PORT

if [[ -z $TMP_PORT ]]
then
	echo 'No port specified, using port 443..'
else
	PORT=$TMP_PORT
        echo 'Port set to: ${PORT}'
fi


## Input generated certs and other necessary directives into nginx.conf file

ALGOS= 'kyber512:kyber768:sikep434:sikep503:frodo640aes:frodo640shake:bike1l1cpa:bike1l3cpa'

echo 'Using ${ALGOS} as supported key exchange algorithms, but you can visit https://github.com/open-quantum-safe/openssl for a list of all supported algorithms'

	python3 conf_edit.py $PORT $LIB_DIR/pki/$DOMAIN\_server.cert $LIB_DIR/pki/$DOMAIN\_server.key $ALGOS $DOMAIN

# Send signals to NGINX to enforce the upgraded binary and conf files: 

# Upgrade binary
	# Extract old PID of master process (needed for graceful shutdown after upgrade) which exists in /run/nginx.pid as was specified in the ./configure params
	OLD_NGX_PID=cat /run/nginx.pid
	#Sends USR2 signal to NGINX master process (PID of master process) to upgrade executable on the fly 
	kill -SIGUSR2 $OLD_NGX_PID

	#kill old master process
	kill -QUIT $OLD_NGX_PID

# Reload configuration
	MASTER_PID=cat /run/nginx.pid
	kill -HUP $MASTER_PID

echo 'Congratulations! Your NGINX server is now capable of handling quantum-resistant TLS sessions, which for now is enabled on port ${PORT}'
echo 'Would you like to run a test with a version of the curl software that supports quantum-resistant algorithms? (y/n)'

read ANS

if [[ -z $ANS ]]
then
	echo 'no answer specified, skipping test..'
else
	if $ANS = 'y'
        echo 'Running curl test...'
		#Install oqs demo of curl with docker and run test
	elif $ANS = 'n'
		echo 'Skipping test..'
fi

## --END --
