# CozyNSM Installation Guide

### Pre-Installation
Download RPM files needed to install needed services and dependencies.

Download Sensor and Application Server files: https://drive.google.com/open?id=0B2Oi1KHMHUVJTnRrejhTWHM2UWs

### Sensor files
After downloading sensor.tar.gz, place that file into the sensor/ folder.

### Application files
After downloading apps.tar.gz, place that file into the application/ folder.

### Sensor Server Install Guide

Copy "sensor" folder to target server /tmp directory.
```
scp -r sensor <username>@<serverIP>:/tmp/
```
ssh into target server
```
ssh <username>@<serverIP>
```
Change Directory to /tmp/sensor
```
cd /tmp/sensor
```
Run Sensor server installation script
```
sudo bash SensorServer_deploy.sh
```

### Application Server Install Guide

Copy "application" folder to target server /tmp directory.
```
scp -r application <username>@<serverIP>:/tmp/
```
ssh into target server.
```
ssh <username>@<serverIP>
```
Change Directory to /tmp/application
```
cd /tmp/application
```
Run Application server installation script
```
sudo bash ApplicationServer_deploy.sh
```

### Post Installation

Verify docker images are running.
```
docker ps -a
```