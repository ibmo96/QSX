#!/bin/bash

# Get domain-name
echo ""
echo "==================================================================" 
echo "What is the domain you would like to generate a quantum-safe certificate for?"
echo "=================================================================="
echo ""
read DOMAIN

## Create test certificate using OQS domain
set -x #prints executed commands 
cd $LIB_DIR && mkdir cacert & mkdir pki && 
$LIB_DIR/openssl/apps/openssl req -x509 -new -newkey $SIG_ALG -keyout CA.key -out cacert/CA.crt -nodes -subj "/CN=$DOMAIN" -days 365 -config $LIB_DIR/openssl//apps/openssl.cnf && 
 $LIB_DIR/openssl/apps/openssl req -new -newkey $SIG_ALG -keyout pki/$DOMAIN\_server.key -out $DOMAIN\_server.csr -nodes -subj "/CN=$DOMAIN" -config $LIB_DIR/openssl/apps/openssl.cnf &&
$LIB_DIR/openssl/apps/openssl x509 -req -in $DOMAIN\_server.csr -out pki/$DOMAIN\_server.crt -CA cacert/CA.crt -CAkey CA.key -CAcreateserial -days 365


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

ALGOS= 'kyber512:kyber768:sikep434:sikep503:frodo640aes:frodo640shake:bike1l1cpa:bike1l3cpa'

echo "=================================================================="
echo 'This Nginx reconfiguration supports following algorithms for key exchange: ${ALGOS}. You can visit https://github.com/open-quantum-safe/openssl for a list of all supported algorithms'
echo "=================================================================="
echo ""
	python3 conf_edit.py $PORT $LIB_DIR/pki/$DOMAIN\_server.cert $LIB_DIR/pki/$DOMAIN\_server.key $ALGOS $DOMAIN
