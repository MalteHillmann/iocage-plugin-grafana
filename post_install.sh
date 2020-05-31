#!/bin/sh

# Enable the services
echo "Enabling services"
sysrc -f /etc/rc.conf influxd_enable="YES" 2>/dev/null
sysrc -f /etc/rc.conf grafana_enable="YES" 2>/dev/null

# Start the services
echo -n "Starting InfluxDB..."
service influxd start > /dev/null
curl -sL -I localhost:8086/ping?wait_for_leader=30s
echo " done"
echo -n "Starting Grafana..."
service grafana start > /dev/null
while [ "$(curl -I -s -o /dev/null -w 200 http://localhost:3000/api/health)" != "200" ]; do sleep 1; done
echo " done"

# Configure InfluxDB
echo "Configuring InfluxDB:"
echo "Creating random password"
INFLUXPW=$(openssl rand -base64 18)
echo "Creating user with random password"
influx -execute "CREATE USER root WITH PASSWORD '$INFLUXPW' WITH ALL PRIVILEGES"
echo "Creating default database grafana"
influx -execute "CREATE DATABASE grafana"
echo "Enabling auth"
sed -i.conf 's/# auth-enabled = false/auth-enabled = true/g' /usr/local/etc/influxd.conf
echo -n "Restarting InfluxDB..."
service influxd restart > /dev/null
curl -sL -I 'http://localhost:8086/ping?wait_for_leader=30s' > /dev/null
echo " done"

# Configure Grafana
echo "Configuring Grafana:"
echo "Creating random password"
GRAFANAPW=$(openssl rand -base64 18)
echo "Configuring InfluxDB as default datasource"
curl --silent --user admin:admin 'http://localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"InfluxDB","isDefault":true,"type":"influxdb","url":"http://localhost:8086","access":"proxy","basicAuth":true,"basicAuthUser":"root","database":"grafana","secureJsonData":{"basicAuthPassword":"'$INFLUXPW'"}}' > /dev/null
echo "Setting random generated admin password"
curl --silent --user admin:admin 'http://localhost:3000/api/admin/users/1/password' -X PUT -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"password":"'$GRAFANAPW'"}' > /dev/null
echo "Creating missing directorys"
mkdir -p /var/db/grafana/provisioning/datasources 
mkdir -p /var/db/grafana/provisioning/notifiers
mkdir -p /var/db/grafana/provisioning/dashboards
echo -n "Restarting Grafana..."
service grafana restart > /dev/null
while [ "$(curl -I -s -o /dev/null -w 200 'http://localhost:3000/api/health')" != "200" ]; do sleep 1; done
echo " done"


# Save data
echo "InfluxDB Username: root" >> /root/PLUGIN_INFO
echo "InfluxDB Password: $INFLUXPW" >> /root/PLUGIN_INFO
echo "InfluxDB Database: grafana" >> /root/PLUGIN_INFO
echo "Grafana User: admin" >> /root/PLUGIN_INFO
echo "Grafana Password: $GRAFANAPW" >> /root/PLUGIN_INFO
