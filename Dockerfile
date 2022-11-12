FROM debian:bullseye-slim AS build

# ___________________________________________________________________________________
# 
# Notes
#
# The name of the base project is Solaranzeige
# This project was created by Ulrich Kunz and due to the integration
# of an update function, a part of it is still maintained by him!
# The website for further in formation is: solaranzeige.de
#
# The base image for this project is takealug/solaranzeige
# The creator of the base image is Bastian Kleinschmidt <debaschdi@googlemail.com>
#
# The new name of this project is energymanager
#
# This project was initiated by Mario Beisteiner 
# Github Account: mariob119
# Github repository: mariob119/energymanager
# Maintainer: Mario Beisteiner
# ___________________________________________________________________________________

# Labels
LABEL org.label-schema.docker.dockerfile="/Dockerfile" \
      org.label-schema.name="docker.solaranzeige"

# Arguments
ARG BUILD_DEPENDENCIES="build-essential make"
ARG DEPENDENCIES="sudo gnupg2 apt-transport-https ca-certificates cron software-properties-common mcedit nano apache2 sed iproute2 curl wget git net-tools inetutils-ping sqlite3 php-common php-pear php-ssh2 php-xml php7.4 php7.4-cgi php7.4-cli php7.4-common php7.4-curl php7.4-dev php7.4-gd php7.4-json php7.4-opcache php7.4-readline php7.4-sqlite3 php7.4-xml libapache2-mod-php"

# Basic Environment Settings
ENV USER_ID="99" \
    GROUP_ID="100" \
    TIMEZONE="Europe/Berlin" \
    UPDATE="yes" \
    MOSQUITTO="yes" \
    INFLUXDB="yes" \
    DEBIAN_FRONTEND="noninteractive" \
    TERM=xterm \
    LANGUAGE="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    CLEANUP="/tmp/* /var/tmp/* /var/log/* /var/lib/apt/lists/* /var/lib/{apt,dpkg,cache,log}/ /var/cache/apt/archives /usr/share/doc/ /usr/share/man/ /usr/share/locale/ "

# Copy files in the right directory

COPY root/solaranzeige.process /usr/local/bin/solaranzeige.process
COPY root/solaranzeige.update /usr/local/bin/solaranzeige.update
COPY root/solaranzeige.setup /usr/local/bin/solaranzeige.setup
COPY root/pvforecast.update /usr/local/bin/pvforecast.update

RUN apt-get -qy update 

### tweak some apt & dpkg settngs
RUN echo "APT::Install-Recommends "0";" >> /etc/apt/apt.conf.d/docker-noinstall-recommends \
    && echo "APT::Install-Suggests "0";" >> /etc/apt/apt.conf.d/docker-noinstall-suggests \
    && echo "Dir::Cache "";" >> /etc/apt/apt.conf.d/docker-nocache \
    && echo "Dir::Cache::archives "";" >> /etc/apt/apt.conf.d/docker-nocache \
    && echo "path-exclude=/usr/share/locale/*" >> /etc/dpkg/dpkg.cfg.d/docker-nolocales \
    && echo "path-exclude=/usr/share/man/*" >> /etc/dpkg/dpkg.cfg.d/docker-noman \
    && echo "path-exclude=/usr/share/doc/*" >> /etc/dpkg/dpkg.cfg.d/docker-nodoc \
    && echo "path-include=/usr/share/doc/*/copyright" >> /etc/dpkg/dpkg.cfg.d/docker-nodoc 

### install basic packages
RUN apt-get install -qy apt-utils locales tzdata 

### limit locale to en_US.UTF-8
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && locale-gen --purge en_US.UTF-8 

### run dist-upgrade
RUN apt-get dist-upgrade -qy

### install solaranzeige dependencies
RUN apt-get install -qy ${BUILD_DEPENDENCIES} ${DEPENDENCIES} \
    && curl -fsSL  https://packages.grafana.com/gpg.key | apt-key add - \
    && echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list \
    && curl -fsSL  https://repos.influxdata.com/influxdb.key | apt-key add - \
    && echo "deb https://repos.influxdata.com/debian buster stable" | tee -a /etc/apt/sources.list.d/influxdb.list \
    && curl -fsSL  http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add - \
    && echo "deb https://repo.mosquitto.org/debian buster main" | tee -a /etc/apt/sources.list.d/mosquitto.list \
    && apt-get update

### install solaranzeige dependencies
RUN apt install -y influxdb grafana mosquitto mosquitto-clients libmosquitto-dev \
    && pecl install Mosquitto-alpha \
    && echo "extension=mosquitto.so" | tee -a /etc/php/7.4/mods-available/mosquitto.ini 

### install pyhton
RUN apt-get install -qy python3-pip python3-elementpath python3-protobuf netcdf-bin python3-bs4 python3-requests python3-numpy python3-pandas python3-h5py python3-tables python3-netcdf4 python3-scipy python3-influxdb python3-setuptools python3-astral python3-wheel python3-wrapt python3-yaml python3-isodate \
    && python3 -m pip install pip --upgrade \
    && python3 -m pip install pysolcast \
    && python3 -m pip install astral --upgrade \
    && python3 -m pip install siphon --upgrade \
    && python3 -m pip install pvlib 

### configure system
RUN update-ca-certificates --fresh \
    && phpenmod mosquitto \
    && a2enmod php7.4 \
    && sed -i 's/\/var\/log/\/var\/www\/log/g' /etc/apache2/envvars \
    && sed -i 's/\/var\/log/\/var\/www\/log/g' /etc/default/grafana-server \
    && sed -i 's/ulimit/#ulimit/g' /etc/init.d/influxdb \
    && echo "STDERR=/var/www/log/influxdb.log" > /etc/default/influxdb 

### install grafana plugins
RUN grafana-cli plugins install fetzerch-sunandmoon-datasource \
    && grafana-cli plugins install briangann-gauge-panel \
    && grafana-cli plugins install agenty-flowcharting-panel 

### alter permissions
RUN chmod +x /usr/local/bin/solaranzeige.process \
    && chmod +x /usr/local/bin/solaranzeige.update \
    && chmod +x /usr/local/bin/solaranzeige.setup \
    && chmod +x /usr/local/bin/pvforecast.update 

### cleanup
RUN apt-get remove --purge -qy ${BUILD_DEPENDENCIES} \
    && apt-get -qy autoclean \
    && apt-get -qy clean \
    && apt-get -qy autoremove --purge \
    && rm -rf ${CLEANUP}

# Copy files
COPY root/update /usr/local/bin/update
COPY root/truncate_log /usr/local/bin/truncate_log
COPY root/solaranzeige_cron /etc/cron.d/solaranzeige_cron

# Get permissions
RUN chmod +x /usr/local/bin/update \
    && chmod +x /usr/local/bin/truncate_log \
    && chmod 0644 /etc/cron.d/solaranzeige_cron \
    && crontab /etc/cron.d/solaranzeige_cron

# Copy tempFiles into linux
COPY tempFiles/ /tempFiles

# Create startscript
COPY root/startscript.sh /
RUN chmod +x startscript.sh
RUN cp startscript.sh /usr/local/bin
RUN chmod +x /usr/local/bin/startscript.sh

# Directory cleanup
RUN rm startscript.sh

# Install ssh
RUN apt-get update
RUN apt-get install systemctl
RUN apt-get install openssh-server -y
COPY root/sshd_config /etc/ssh/sshd_config

# Set password
RUN echo "root:root" | chpasswd

# Set entrypoint
ENTRYPOINT [ "/usr/local/bin/startscript.sh" ]

VOLUME /solaranzeige
VOLUME /pvforecast
VOLUME /var/www
VOLUME /var/lib/influxdb
VOLUME /var/lib/grafana

EXPOSE 3000
EXPOSE 1883
EXPOSE 22