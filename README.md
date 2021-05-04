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
