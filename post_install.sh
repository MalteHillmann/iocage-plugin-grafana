#!/bin/sh

# Enable the services
echo "Enabling services"
sysrc -f /etc/rc.conf influxd_enable="YES" 2>/dev/null
sysrc -f /etc/rc.conf grafana_enable="YES" 2>/dev/null

# Start the services
echo "Starting InfluxDB..."
service influxd start 2>/dev/null
curl -sL -I localhost:8086/ping?wait_for_leader=30s
echo "Done"
echo "Starting Grafana..."
service grafana start 2>/dev/null
while [ "$(curl -I -s -o /dev/null -w 200 http://localhost:3000/api/health)" != "200" ]; do sleep 1; done
echo "Done"

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
echo "Restarting InfluxDB..."
service influxd restart 2>/dev/null
curl -sL -I localhost:8086/ping?wait_for_leader=30s
echo "Done"

# Configure Grafana
echo "Configuring Grafana:"
echo "Creating random password"
GRAFANAPW=$(openssl rand -base64 18)
echo "Configuring InfluxDB as default datasource"
curl --user admin:admin 'http://localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"InfluxDB","isDefault":true,"type":"influxdb","url":"http://localhost:8086","access":"proxy","basicAuth":true,"basicAuthUser":"root","database":"grafana","secureJsonData":{"basicAuthPassword":"'$INFLUXPW'"}}'
echo "Setting random generated admin password"
curl --user admin:admin 'http://localhost:3000/api/admin/users/1/password' -X PUT -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"password":"'$GRAFANAPW'"}'
echo "Creating missing directorys"
mkdir -p /var/db/grafana/provisioning/datasources 
mkdir -p /var/db/grafana/provisioning/notifiers
mkdir -p /var/db/grafana/provisioning/dashboards
echo "Restarting Grafana..."
service grafana restart 2>/dev/null
while [ "$(curl -I -s -o /dev/null -w 200 http://localhost:3000/api/health)" != "200" ]; do sleep 1; done
echo "Done"


# Save data
echo "InfluxDB Username: root" >> /root/PLUGIN_INFO
echo "InfluxDB Password: $INFLUXPW" >> /root/PLUGIN_INFO
echo "InfluxDB Database: grafana" >> /root/PLUGIN_INFO
echo "Grafana User: admin" >> /root/PLUGIN_INFO
echo "Grafana Password: $GRAFANAPW" >> /root/PLUGIN_INFO
