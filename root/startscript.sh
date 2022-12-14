#!/bin/bash
set -e
set -f

USERNAME="root"

if [[ -z "${TIMEZONE}" ]]; then
  TIMEZONE='Europe/Berlin'
fi

if [[ -z "${GROUP_ID}" ]]; then
  GROUP_ID='100'
fi

if [[ -z "${USER_ID}" ]]; then
  USER_ID='99'
fi

if [[ -z "${UPDATE}" ]]; then
  UPDATE='no'
fi

if [[ -z "${MOSQUITTO}" ]]; then
  MOSQUITTO='yes'
fi

if [[ -z "${INFLUXDB}" ]]; then
  INFLUXDB='yes'
fi

ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

echo "${USERNAME}:x:${USER_ID}:${GROUP_ID}:${USERNAME}:/:/bin/nologin" >> /etc/passwd
echo "${USERNAME}:!::0:::::" >> /etc/shadow

if ! getent group ${GROUP_ID}; then
  echo "${USERNAME}:x:${GROUP_ID}:" >> /etc/group
fi

# If there is no 1.user.config.php, then it is a first 
# time run and the setup has to be done!
if [[ ! -f /var/www/html/1.user.config.php ]]; then
  cd /usr/local/bin
  sed -i -e 's/\r$//' solaranzeige.setup
  /usr/local/bin/solaranzeige.setup
fi

echo ""
echo "Create missing files afterpossible Container Update"
echo ""
#Install Missing Files after possible Container Update
if [[ ! -f /var/www/html/pheditor.php ]]; then
  echo "create new files/directories..."
  if [[ -f /var/www/html/database ]]; then
    rm /var/www/html/database
  fi
  if [[ -f /var/www/html/css ]]; then
    rm /var/www/html/css
  fi
  mkdir -p /tmp/git
  mkdir -p /var/www/html
  mkdir -p /var/www/html/phpinc
  mkdir -p /var/www/html/css
  mkdir -p /var/www/html/database
  mkdir -p /var/www/html/images
  mkdir -p /var/www/log
  mkdir -p /var/www/pipe
  mkdir -p /solaranzeige
  mkdir -p /solaranzeige/config
  mkdir -p /var/www/log/apache2
  mkdir -p /pvforecast
  mkdir -p /run/mosquitto
  cd /tmp/git && git clone https://github.com/DeBaschdi/solar_config.git
  mv /solaranzeige/solaranzeige_cron /tmp
  cp -R /tmp/git/solar_config/solaranzeige /
  mv /tmp/solaranzeige_cron /solaranzeige
  cd /var/www/html && rm -rf /tmp/git
  cd /usr/local/bin
  sed -i -e 's/\r$//' solaranzeige.update
  su -s /bin/bash -c "TERM=xterm /usr/local/bin/solaranzeige.update"
  cd /usr/local/bin
  curl -s 'https://raw.githubusercontent.com/DeBaschdi/solar_config/master/html/index.php' > /var/www/html/index.php
  curl -s 'https://raw.githubusercontent.com/DeBaschdi/solar_config/master/html/pheditor.php' > /var/www/html/pheditor.php
  UPDATE='no'
fi

if [[ "${UPDATE}" = "yes" ]]; then
  /usr/local/bin/solaranzeige.update
  curl -s 'https://raw.githubusercontent.com/DeBaschdi/solar_config/master/html/index.php' > /var/www/html/index.php
fi

# Restore Config Files
cp /solaranzeige/config/grafana/grafana.ini /etc/grafana/ &>/dev/null
cp /solaranzeige/config/grafana/grafana-server /etc/default/ &>/dev/null
cp /solaranzeige/config/influxdb/influxdb.conf /etc/influxdb/ &>/dev/null
cp /solaranzeige/config/mosquitto/mosquitto.conf /etc/mosquitto/ &>/dev/null

#alter Premissions
mkdir -p /run/mosquitto 
chown -R ${USER_ID}:${GROUP_ID} /solaranzeige
chown -R ${USER_ID}:${GROUP_ID} /var/www
chown -R ${USER_ID}:${GROUP_ID} /pvforecast
chown -R ${USER_ID}:${GROUP_ID} /var/lib/influxdb
chown -R ${USER_ID}:${GROUP_ID} /var/lib/grafana
chmod -R 777 /solaranzeige
chmod -R 777 /pvforecast
chmod -R 777 /var/www
chmod -R 777 /var/lib/influxdb
chmod -R 777 /var/lib/grafana
chmod -R 777 /run/mosquitto

# Start SSH
service ssh start

echo ""
echo "Run solaranzeige.process"
cd /usr/local/bin
sed -i -e 's/\r$//' solaranzeige.process
su -s /bin/bash -c "TERM=xterm /usr/local/bin/solaranzeige.process"
