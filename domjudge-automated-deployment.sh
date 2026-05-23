# /usr/bin/bash

prefix=$(basename "$(pwd)")"_"

source .env

#prefix=""

dbname=$prefix"dj-mariadb-1"
servername=$prefix"domserver-1"
jhostname=$prefix"judgehost"

# setting backup path
base_volume=/var/backups/$prefix"domjudge"
server_volume=$base_volume/server
db_volume=$base_volume/db_
ssl_certs_volume_mapping=""
ssl_conf_volume_mapping=""

#Host port to map with container
dom_server_port=$HOST_HTTP_SERVER_PORT
db_port=$DB_PORT
dom_server_ssl_port_mapping=$HOST_HTTPS_SERVER_PORT
no_of_judgehosts=$NO_OF_JUDGE_HOSTS

base_url=$BASE_URL$dom_server_port/

# secrets
db_root_pass=$DB_ROOT_PASS
db_pass=$DB_PASS

# stop and remove containers
host=0;
jhostslist="";
while [ $host -lt $no_of_judgehosts ]; do
        jhostslist=$jhostslist"$jhostname-$host ";
        host=$(( host + 1 ));
done

if [[ -n $1 && $1 == "-dt" ]]; then
        sudo docker stop $dbname $servername $jhostslist
        sudo docker rm $dbname $servername $jhostslist
        exit 0;

# just stop containers
elif [[ -n $1 && $1 == "-sp"  ]]; then
        sudo docker stop $dbname $servername $jhostslist
        exit 0;

# starting containers
elif [[ -n $1 && $1 == "-st" ]]; then
        sudo docker start $dbname $servername $jhostslist
        sleep 3
        sudo docker exec $servername supervisorctl restart nginx
        exit 0;
fi


read -p "\nDo you want to enable ssl as well? (y/n): " ssl

if [[ -n $ssl && $ssl =~ ^[Yy]$  ]]; then

        sudo mkdir -p $server_volume/ssl/conf/
        sudo chown -R $USER:$USER $server_volume/ssl/conf

        ssl_certs_path=$server_volume/ssl/certs/domjudge

        sudo mkdir -p $ssl_certs_path
        sudo chown -R $USER:$USER $ssl_certs_path

        ssl_certs_volume_mapping=" -v $server_volume/ssl/certs:/etc/ssl/certs/"
        ssl_conf_volume_mapping=" -v $server_volume/ssl/conf:/etc/nginx/conf.d/"
        dom_server_ssl_port_mapping=" -p 443:443"

        cat <<- SSL_CONF > $server_volume/ssl/conf/ssl.conf
                #use HTTPS and redirect HTTP to HTTPS:
                server {
                       listen   80;
                       listen   [::]:80;
                       server_name $DOMAIN_NAME;

                       include /etc/nginx/snippets/domjudge-inner;
                       #return 308 https://$host$request_uri;  # enforce https
                }


                server {
                        listen   443 ssl http2;
                        listen   [::]:443 ssl http2;
                        server_name $DOMAIN_NAME;

                    # See https://ssl-config.mozilla.org/ to generate good TLS settings for your server
                        ssl_certificate /etc/ssl/certs/domjudge/domain_ssl.crt;
                        ssl_certificate_key /etc/ssl/certs/domjudge/domain_ssl.key;
                        ssl_session_timeout 5m;
                        ssl_prefer_server_ciphers on;

                        # Strict-Transport-Security is not set by default since it will break
                        # installations without a valid TLS certificate. Enable it if your
                        # DOMjudge installation only runs with a valid TLS certificate.
                #       add_header Strict-Transport-Security max-age=31556952;

                        # If you are reading from the event feed, make sure this is large enough.
                        # If you have a slow event feed reader, nginx needs to keep the connection
                        # open long enough between two write operations
                        send_timeout 36000s;
                        fastcgi_read_timeout 200s;
                        include /etc/nginx/snippets/domjudge-inner;
                }
SSL_CONF

        if [[ ! -e "./ssl/domain_ssl.crt" || ! -e "./ssl/domain_ssl.key" ]]; then
                cat <<- EOF

                SSL files are missing please ensure that your ssl certificates are placed in ./ssl directory

                        *************************************************************************
                        * Your ssl_certificate(.crt) file should be of name domain_ssl.crt      *
                        * Your ssl_certificate_key(.key) file be of name domain_ssl.key         *
                        * Alternatively, you may update the ssl.conf file at
 *
                        *       $server_volume/nginx/conf/ssl.conf                *
                        *************************************************************************

EOF
                echo -e "Exiting ..."
                exit 1;
        fi

        sudo cp ./ssl/* "$ssl_certs_path/"

fi

sudo docker run \
  -d --name $dbname \
  -v $base_volume:/backup -v $base_volume/db_:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=$db_root_pass -e MYSQL_USER=domjudge -e MYSQL_PASSWORD=$db_pass -e MYSQL_DATABASE=domjudge \
  -p $db_port:3306 \
   mariadb --max-connections=1000 --max-allowed-packet=67108864

#sleep 4

sudo docker run \
  -d --name $servername \
  --cpus=18 \
  --link $dbname:mariadb \
  -v $server_volume:/backups $ssl_certs_volume_mapping $ssl_conf_volume_mapping \
  -v ./.secrets/initial_admin_password.secret:/opt/domjudge/domserver/etc/initial_admin_password.secret \
  -e MYSQL_HOST=mariadb -e MYSQL_USER=domjudge -e MYSQL_DATABASE=domjudge -e MYSQL_PASSWORD=$db_pass -e MYSQL_ROOT_PASSWORD=$db_root_pass \
  -p $dom_server_port:80 $dom_server_ssl_port_mapping \
  domjudge/domserver:8.2.0

sleep 5

#admin_pass=$(cat ./.secrets/initial_admin_password.secret)

if [ -s secrets.txt ]; then

admin_pass=$(head -1 secrets.txt)
api_secret=$(tail -1 secrets.txt)

else

admin_pass=$(sudo docker exec $servername /opt/domjudge/domserver/webapp/bin/console domjudge:reset-user-password admin | awk 'NF {line = $NF} END {print line}')
api_secret=$(sudo docker exec $servername grep -m 1 -E '\bjudgehost\b' /opt/domjudge/domserver/etc/restapi.secret | awk '{print $4}')

cat << SECRETS > secrets.txt
$admin_pass
$api_secret
SECRETS

fi

#admin_pass=$(cat ./.secrets/initial_admin_password.secret)
#api_secret=$(tail -1 ./.secrets/restapi.secret)

echo $admin_pass
echo $api_secret


host=0;
while [ $host -lt $no_of_judgehosts ]; do
        sudo docker run -d \
        --privileged \
        --cpus=1.25 \
        --restart unless-stopped \
        -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
        --name $jhostname-$host \
        --link $servername:$servername \
        --hostname $prefix"judgedaemon-$host" \
        -e DOMSERVER_BASEURL=$base_url \
        -e DAEMON_ID=$host \
        -e JUDGEDAEMON_PASSWORD=$api_secret  \
        domjudge/judgehost:8.2.0

        host=$(( host + 1));
done
