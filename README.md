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


## Prerquesites 
- Debian/Ubuntu machine. 
- Having an Nginx installation of >=14.1.2
- For enabling a post-quantum  endpoint you should already have HTTPS enabled ([Certbot](https://github.com/certbot/certbot) is a great tool to enable HTTPS on Nginx.

### HOWTO

#### 1: Setup 

On the build machine run the following to download and build the necessary dependencies and libraries: 


```sudo bash build_setup.sh ``` or ```./build_setup.sh```

Once successfully built, the build script will ask for optional certificate generation using the `gen_cert.sh` script. 

If HTTPS is enabled then `gen_cert.sh` will edit the `nginx.conf` file using `conf_edit.py`. Finally `./build_setup.sh` calls `nginx_signal.sh` which will send the `USR2` and `HUP` signals to the Nginx master process. Documentation on Nginx processes can be found [here](http://nginx.org/en/docs/control.html)


### TESTING

If a self-signed certificate was generated and a post-quantum endpoint/port was created, then this port can be tested with a post-quantum TLS session using one of two tools. 
1. Requesting the certificate from the server using the built in OpenSSL `s_client` by running the following: 

    `apps/openssl s_client -connect host:port-curves <KEM>`
 
    List of supported algorithms that can be passed to `<KEM>` are the following default algorithms:        `kyber512:kyber768:sikep434:sikep503:frodo640aes:frodo640shake:bike1l1cpa:bike1l3cpa'
   
2. Requesting a page from server on that port using an OQS modified version of curl. Installation and usage can be found [here](https://github.com/open-quantum-safe/oqs-demos/tree/main/curl).
