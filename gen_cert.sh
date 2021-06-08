#!/bin/bash

# Get domain-name
echo ""
echo "==================================================================" 
echo "What is the domain you would like to generate a quantum-safe certificate for?"
echo "=================================================================="
echo ""
read DOMAIN

## Create test certificate using OQS domain

#if [ -d "$LIB_DIR/cacert" ] 
#then
 #   echo "Directory $LIB_DIR/cacert already exists, overriding any existing certificate.." 
#else
 #  cd $LIB_DIR && mkdir cacert && mkdir pki
  #  echo "Generating certificates.."
#fi


cd $LIB_DIR && mkdir -p cacert && mkdir -p pki && set -x #prints executed commands  &&
cd $LIB_DIR/openssl/apps &&

#function gen_cert{ 
./openssl req -x509 -new -newkey $SIG_ALG -keyout $LIB_DIR/cacert/CA.key -out $LIB_DIR/cacert/CA.crt -nodes -subj "/CN=$DOMAIN" -days 365 -config openssl.cnf && 
./openssl req -new -newkey $SIG_ALG -keyout $LIB_DIR/pki/$DOMAIN\_server.key -out $LIB_DIR/pki/$DOMAIN\_server.csr -nodes -subj "/CN=$DOMAIN" -config openssl.cnf &&
./openssl x509 -req -in $LIB_DIR/pki/$DOMAIN\_server.csr -out $LIB_DIR/pki/$DOMAIN\_server.crt -CA $LIB_DIR/cacert/CA.crt -CAkey $LIB_DIR/cacert/CA.key -CAcreateserial -days 365
#}
set +x #turns off printing of executed commands

# Read which port user wants to run quantum-safe server on
echo ""
echo "=================================================================="
echo "What port would you like the quantum-safe server to listen on?"
echo " You can specify either an already used port and we will update the certificate, or an unused port."
echo "If you are unsure, press enter and port 443 will be used."
echo "=================================================================="
echo ""
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

ALGOS='kyber512:kyber768:sikep434:sikep503:frodo640aes:frodo640shake:bike1l1cpa:bike1l3cpa'

echo "=================================================================="
echo 'This Nginx reconfiguration supports following algorithms for key exchange: ${ALGOS}. You can visit https://github.com/open-quantum-safe/openssl for a list of all supported algorithms'
echo "=================================================================="
echo ""
	python3 $TOOL_DIR/conf_edit.py $PORT $LIB_DIR/pki/$DOMAIN\_server.crt $LIB_DIR/pki/$DOMAIN\_server.key $ALGOS $DOMAIN
