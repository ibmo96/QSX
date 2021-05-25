## This script performs the necessary modifications to the nginx.conf file

## Arguments needed: Port, installation directory for all libs (nginx + OQS openssl)  

import common
import os
import json
import fileinput #edit file
import shutil #copy files/folders
import re
import traceback
import sys

# Script assumes nginx to have been built for this platform using build-ubuntu.sh

############# Configuration section starting here
#Default nginx.conf file location
NGX_CONF="/etc/nginx/nginx.conf"

# This is where the explanation HTML code is
TEMPLATE_FILE="index-template"

# Path where tool was cloned down and this script is running from
TOOL_PATH = os.path.dirname(os.path.realpath(__file__))

# This is where all libraries are located, default is /opt
BASEPATH="/opt"

# This is the (relative to BASEPATH) path of all certificates
PKIPATH="pki"

# This is the port where all algorithms start to be present(ed)
STARTPORT=6000

# This is the local location of the OQS-enabled OpenSSL
OPENSSL=BASEPATH+"/openssl/apps/openssl"

# This is the local OQS-OpenSSL config file
OPENSSL_CNF=BASEPATH+"/openssl/apps/openssl.cnf"

# This is the fully-qualified domain name of the server to be set up
# Ensure this is in sync with contents of ext-csr.conf file
TESTFQDN="test.openquantumsafe.org"

# This is the local folder where the root CA (key and cert) resides
CAROOTDIR="root"

# This is the file containing the SIG/KEM/port assignments
ASSIGNMENT_FILE="assignments.json"

#Template server directive file
SERVER_DIRECTIVE_FILE="/templates/server_directive.txt"


############# Functions starting here

# Generate cert chain (server and CA for a given sig alg:
# srv crt/key wind up in '<path>/<sigalg>_srv.crt|key
def gen_cert(sig_alg):
   # first check whether we already have a root CA; if not create it
   if not os.path.exists(CAROOTDIR):
           os.mkdir(CAROOTDIR)
           common.run_subprocess([OPENSSL, 'req', '-x509', '-new',
                                     '-newkey', "rsa:4096",
                                     '-keyout', os.path.join(CAROOTDIR, "CA.key"),
                                     '-out', os.path.join(CAROOTDIR, "CA.crt"),
                                     '-nodes',
                                         '-subj', '/CN=oqstest_CA',
                                         '-days', '500',
                                     '-config', OPENSSL_CNF])
           print("New root cert residing in %s." % (os.path.join(CAROOTDIR, "CA.crt")))

   # now generate suitable server keys signed by that root; adapt algorithm names to std ossl 
   if sig_alg == 'rsa3072':
       ossl_sig_alg_arg = 'rsa:3072'
   elif sig_alg == 'ecdsap256':
       common.run_subprocess([OPENSSL, "ecparam", "-name", "prime256v1", "-out", os.path.join(PKIPATH, "prime256v1.pem")])
       ossl_sig_alg_arg = 'ec:{}'.format(os.path.join(PKIPATH, "prime256v1.pem"))
   else:
       ossl_sig_alg_arg = sig_alg
   # generate server key and CSR
   common.run_subprocess([OPENSSL, 'req', '-new',
                              '-newkey', ossl_sig_alg_arg,
                              '-keyout', os.path.join(PKIPATH, '{}_srv.key'.format(sig_alg)),
                              '-out', os.path.join(PKIPATH, '{}_srv.csr'.format(sig_alg)),
                              '-nodes',
                              '-subj', '/CN='+TESTFQDN,
                              '-config', OPENSSL_CNF])
   # generate server cert off common root
   common.run_subprocess([OPENSSL, 'x509', '-req',
                                  '-in', os.path.join(PKIPATH, '{}_srv.csr'.format(sig_alg)),
                                  '-out', os.path.join(PKIPATH, '{}_srv.crt'.format(sig_alg)),
                                  '-CA', os.path.join(CAROOTDIR, 'CA.crt'),
                                  '-CAkey', os.path.join(CAROOTDIR, 'CA.key'),
                                  '-CAcreateserial',
                                  '-extfile', 'ext-csr.conf', 
                                  '-extensions', 'v3_req',
                                  '-days', '365'])



def rev_line_search(data, strings_to_search, index): 
   for i,line in reversed(list(enumerate(data))): 
       if all(x in line for x in strings_to_search): 
	      if line.strip().startswith("#"):
		      continue
	      else:
		      return i,line
   return None

def line_search(data, strings_to_search, index):
   for i, line in enumerate(data, index):
      if all(x in line for x in strings_to_search):
	      if line.strip().startswith("#"):  #section is commented out, continue to find a section that isnt
		      continue
	      else:
		      return i, line
   return None


def append_new_server_directive(filename, data, port, server_name, cert, key, algos, html_dir, html_index):
   try:
      #create copy of server directive template file
      tmp_file =  '{}_server_directive.txt'.format(port)
      shutil.copy(TOOL_PATH+'/templates/server_directive.txt' , tmp_file)
      #do a search and replace for the values already encoded therin
      with open(tmp_file, 'r') as file:
         new_server_directive = file.read()
         new_server_directive = new_server_directive.replace('PORTTOBESPECIFIED', port)
         new_server_directive = new_server_directive.replace('SERVERNAMETOBE', server_name)
         new_server_directive = new_server_directive.replace('SSLCERTTOBESPECIFIED', cert)
         new_server_directive = new_server_directive.replace('SSLCERTKEYTOBESPECIFIED', key)
         new_server_directive = new_server_directive.replace('SSLCURVEALGORITHMS', algos)
         new_server_directive = new_server_directive.replace('ROOTHTMLFILELOCATION', html_dir)
         new_server_directive = new_server_directive.replace('HTMLFILENAME', html_index)

         #Insert into origin nginx.conf file (data list) right before the last '}' which ends the http directive
        res = rev_line_search(data, "}", 0)
	data[res[0]:res[0]] = new_server_directive

      #delete tmp server directive file
      os.remove(tmp_file)
      return data
   except Exception as e:
	   #print(e)
      traceback.print_exc()


def modify_conf(filename, port, cert, key, algos,  server_name):
   try:
      with open(filename, "r") as f:
         lines = f.readlines()
         #First check if HTTPS is enabled on the server
         https_is_enabled = line_search(lines, '443 ssl',0)
         if https_is_enabled is not None:

            #move on to check if desired port exists
            port_match = ["listen", port] 
            port_search_res = line_search(lines, port_match, 0)
            if port_search_res is not None:
               print('Port {} is enabled on the server, changing the certificate to a self-signed post-quantum certificate...'.format(port))
            #find ssl_certificate & ssl_certificate_key directives, input cert and key location
               cert_search_res = line_search(lines[port_search_res[0]:], 'ssl_certificate', port_search_res[0])
               if cert_search_res is not None:
                  #if 'ssl_certificate' directive is found, we input the cert and cert key locations
                  ssl_certificate = '        ssl_certificate     ' + cert + ';\n'
                  lines[cert_search_res[0]] = ssl_certificate
                  ssl_certificate_key = '        ssl_certificate_key     ' + key + ';\n'
                  lines[cert_search_res[0]+1] = ssl_certificate_key
               else:
                  raise Exception('ssl_certificate directive not found, control that you have HTTPS enabled on your server..')
            # find ssl_ecdh_curve and input desired algos
               curves = line_search(lines[port_search_res[0]:], 'ssl_ecdh_curve', port_search_res[0])
               if curves is not None: 
                  ssl_ecdh_curve = '        ssl_ecdh_curve \' ' + algos + '\';\n'
                  lines[curves[0]] = ssl_ecdh_curve
                  with open(filename, "w") as i: 
                     i.writelines(lines)
                     i.close()
               else: 
                  #input ss_ecdh_curve directive just before 'location' directive
                  location = line_search(lines[port_search_res[0]:], 'location /', port_search_res[0])
                  lines[location[0]-1:location[0]-1] = 'ssl_ecdh_curve'
                  with open(filename, "w") as i: 
                     i.writelines(lines)
                     i.close()
            else: #If we dont find the given port in the conf file, we create a whole new server directive
               print('Creating new server directive for port {}...'.format(port))
               new_data = append_new_server_directive(filename, lines, port, server_name, cert, key, algos, TOOL_PATH + '/templates/html', 'index.html index.html')
               with open(filename, "w") as i: 
                  i.writelines(new_data)
                  i.close()

                  """  
                  #  --- AUTOMATION OF FINDING SERVER NAME BY SCANNING CONF FILE -------

               if server_name is None:
                  i, str = line_search(lines, 'server_name', 0)
                  res = re.search('server_name(.*);', str)
                  server = res.group(1).strip()
                  #generate new conf file with appended server directive
                  new_data = append_new_server_directive(filename, lines, port, server, cert, key, algos, TOOL_PATH + '/templates/html', 'index.html index.html')
                  with open(filename, "w") as i: 
                     i.writelines(new_data)
                     i.close()
               else:
                  new_data = append_new_server_directive(filename, lines, port, server_name, cert, key, algos, TOOL_PATH + '/templates/html', 'index.html index.html')
                  with open(filename, "w") as i: 
                     i.writelines(new_data)
                     i.close() """


         else:
            raise Exception('Please control that HTTPS is enabled on the server...(Certbot is a good tool for that)')

   except Exception as e:
	   #print(e)
      traceback.print_exc()

def write_nginx_config(f, i, port, sig, k):
           f.write("server {\n")
           f.write("    listen              0.0.0.0:"+str(port)+" ssl;\n\n")
           f.write("    server_name         "+TESTFQDN+";\n")
           f.write("    access_log          "+BASEPATH+"logs/"+sig+"-access.log;\n")
           f.write("    error_log           "+BASEPATH+"logs/"+sig+"-error.log;\n\n")
           f.write("    ssl_certificate     "+BASEPATH+PKIPATH+"/"+sig+"_srv.crt;\n")
           f.write("    ssl_certificate_key "+BASEPATH+PKIPATH+"/"+sig+"_srv.key;\n\n")
           f.write("    ssl_protocols       TLSv1.3;\n")
           if k!="*" :  
              f.write("    ssl_ecdh_curve      "+k+";\n")
           f.write("    location / {\n")
           f.write("            ssi    on;\n")
           if k!="*" :  
              f.write("            set    $oqs_alg_name \""+sig+"-"+k+"\";\n")
           f.write("            root   html;\n")
           f.write("            index  success.html;\n")
           f.write("    }\n\n")
           # activate for more boring links-only display:
           #i.write("<li><a href=https://"+TESTFQDN+":"+str(port)+">"+sig+"/"+k+" ("+str(port)+")</a></li>\n")

           # deactivate if you don't like tables:
           i.write("<tr><td>"+sig+"</td><td>"+k+"</td><td>"+str(port)+"</td><td><a href=https://"+TESTFQDN+":"+str(port)+">"+sig+"/"+k+"</a></td></tr>\n")

           f.write("}\n\n")

# generates nginx config
def gen_conf(filename, indexbasefilename):
   port = STARTPORT
   assignments={}
   i = open(indexbasefilename, "w")
   with open(TEMPLATE_FILE, "r") as tf:
     for line in tf:
       i.write(line)

   with open(filename, "w") as f:
     # baseline config
     f.write("worker_processes  auto;\n")
     f.write("worker_rlimit_nofile  10000;\n")
     f.write("events {\n")
     f.write("    worker_connections  32000;\n")
     f.write("}\n")
     f.write("\n")
     f.write("http {\n")
     f.write("    include       conf/mime.types;\n");
     f.write("    default_type  application/octet-stream;\n")
     f.write("    keepalive_timeout  65;\n\n")
     # plain server for base information
     f.write("server {\n")
     f.write("    listen      80;\n")
     f.write("    server_name "+TESTFQDN+";\n")
     f.write("    access_log  /opt/nginx/logs/80-access.log;\n")
     f.write("    error_log   /opt/nginx/logs/80-error.log;\n\n")
     f.write("    location / {\n")
     f.write("            root   html;\n")
     f.write("            index  "+indexbasefilename+";\n")
     f.write("    }\n")
     f.write("}\n")
     f.write("server {\n")
     f.write("    listen      443 ssl;\n")
     f.write("    server_name "+TESTFQDN+";\n")
     f.write("    access_log  /opt/nginx/logs/443-access.log;\n")
     f.write("    error_log   /opt/nginx/logs/443-error.log;\n\n")
     f.write("    ssl_certificate     /etc/letsencrypt/live/"+TESTFQDN+"/fullchain.pem;\n")
     f.write("    ssl_certificate_key /etc/letsencrypt/live/"+TESTFQDN+"/privkey.pem;\n\n")
     f.write("    location / {\n")
     f.write("            root   html;\n")
     f.write("            index  "+indexbasefilename+";\n")
     f.write("    }\n")
     f.write("}\n")

     f.write("\n")
     for sig in common.signatures:
        assignments[sig]={}
        assignments[sig]["*"]=port
        write_nginx_config(f, i, port, sig, "*")
        port = port+1
        for kex in common.key_exchanges:
           # replace oqs_kem_default with X25519:
           k = "X25519" if kex=='oqs_kem_default' else kex
           write_nginx_config(f, i, port, sig, k)
           assignments[sig][k]=port
           port = port+1
     f.write("}\n")
   # deactivate if you don't like tables:
   i.write("</table>\n")

   i.write("</body></html>\n")
   i.close()
   with open(ASSIGNMENT_FILE, 'w') as outfile:
      json.dump(assignments, outfile)

def main():
   #modify_conf(TOOL_PATH + '/test.conf','9003', 'v2/example.com/cert.pem','v2/example.com/cert.key' ,'kyber512:kyber768:kyber1024', 'www.quantumsafenginx.com quantumsafenginx.com')
   modify_conf('/etc/nginx/nginx.conf', sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
  # If the argument at [1] is a '1' it means the user wants to retain their certs on that port
#append_new_server_directive('/etc/nginx/nginx.conf', None, , server_name, cert, key, algos, html_dir, html_index)
  # If the argument at [1] is a '2' then it means that the user wants to override the cert already defined for that port

main()
