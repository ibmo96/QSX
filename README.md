# Quantum-Safe Nginx (QSX) 

This is the official QSX tool for setting up and prototpying a quantum-secure NGINX server. 


## PREFIX 

- QSX is an extension of the **Open Quantum Safe (OQS)** project led by [Douglas Stebila](https://www.douglas.stebila.ca/research/) and [Michele Mosca](http://faculty.iqc.uwaterloo.ca/mmosca/), which aims to develop and integrate into applications quantum-safe cryptography to facilitate deployment and testing in real world contexts. In particular, OQS provides prototype integrations of liboqs into TLS and SSH, through [OpenSSL](https://github.com/open-quantum-safe/openssl) and [OpenSSH](https://github.com/open-quantum-safe/openssh-portable). 
- More information on OQS can be found [here](https://openquantumsafe.org/) and in the [associated](https://openquantumsafe.org/papers/SAC-SteMos16.pdf) [whitepapers](https://openquantumsafe.org/papers/NISTPQC-CroPaqSte19.pdf).


## Overview 

- QSX builds and configures NGINX using quantum-secure version of [OpenSSL](https://github.com/open-quantum-safe/openssl).
- The appends necessary build parameters to the NGINX configuration arguments, to the user's already existing configuration arguments. 
- NGINX is configured to use HTTPS to enabled SSL, with TLS version 1.3.
- The tool provides a test script for generating a quantum-secure self-signed (or part of a chain) certificate.


### HOWTO

#### 1: Setup 

On the build machine run the following to download and build the necessary dependencies and libraries: 

```
./build_setup.sh
```

Once successfully built, the build script will ask for optional certificate generation using the `gen_cert.sh` script. `gen_cert.sh` will then edit the `nginx.conf` file using `conf_edit.py`. Finally `./build_setup.sh` calls `nginx_signal.sh` which will send the `USR2` and `HUP` signals to the Nginx master process. Documentation on Nginx processes can be found [here](http://nginx.org/en/docs/control.html)


### TESTING


