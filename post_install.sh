#!/bin/sh

# Enable the services
sysrc -f /etc/rc.conf influxd_enable="YES" 2>/dev/null
sysrc -f /etc/rc.conf grafana_enable="YES" 2>/dev/null

# Start the services
service influxd start 2>/dev/null
sleep 5
service grafana start 2>/dev/null
sleep 5

# Configure InfluxDB
INFLUXPW=$(openssl rand -base64 18)
influx -execute "CREATE USER root WITH PASSWORD '$INFLUXPW' WITH ALL PRIVILEGES"
influx -execute "CREATE DATABASE grafana"
sed -i.conf 's/# auth-enabled = false/auth-enabled = true/g' /usr/local/etc/influxd.conf
service influxd restart 2>/dev/null
sleep 5

# Configure Grafana
GRAFANAPW=$(openssl rand -base64 18)
curl --user admin:admin 'http://localhost:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"InfluxDB","isDefault":true,"type":"influxdb","url":"http://localhost:8086","access":"proxy","basicAuth":true,"basicAuthUser":"root","database":"grafana","secureJsonData":{"basicAuthPassword":"'$INFLUXPW'"}}'
curl --user admin:admin 'http://localhost:3000/api/admin/users/1/password' -X PUT -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"password":"'$GRAFANAPW'"}'

# Save data
echo "InfluxDB Username: root" >> /root/PLUGIN_INFO
echo "InfluxDB Password: $INFLUXPW" >> /root/PLUGIN_INFO
echo "InfluxDB Database: grafana" >> /root/PLUGIN_INFO
echo "Grafana User: admin" >> /root/PLUGIN_INFO
echo "Grafana Password: $GRAFANAPW" >> /root/PLUGIN_INFO
