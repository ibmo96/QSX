#!/bin/bash

# Send signals to NGINX to enforce the upgraded binary and conf files: 

echo ""
echo "=================================================================="
echo "upgrading Nginx binary...."
# Upgrade binary
	# Extract old PID of master process (needed for graceful shutdown after upgrade) which exists in /run/nginx.pid as was specified in the ./configure params
	OLD_NGX_PID=$(sudo cat /run/nginx.pid)
	#Sends USR2 signal to NGINX master process (PID of master process) to upgrade executable on the fly 
	sudo kill -SIGUSR2 $OLD_NGX_PID

	#kill old master process
	sudo kill -QUIT $OLD_NGX_PID
echo ""
echo "Reloading Nginx configuration..."

# Reload configuration
	MASTER_PID$(sudo cat /run/nginx.pid)
	sudo kill -HUP $MASTER_PID

echo ""
echo "Nginx signals sent successfully!"
echo "
