### Software
##### Network Sensor Node
The network sensor processes ingested network traffic. To do this, 3 primary applications are used. Google Stenographer writes full packet capture (PCAP) data to disk, Bro parses metadata out of network traffic and generates logs, and Suricata alerts on rule based signatures. The logs and alerts are forwarded by FileBeat into a datastore Node.
  * Bro NSM
  * Suricata IDS
  * Google Stenographer
  * FileBeat

Required: FileBeat. (While FileBeat is the only required application on the Network Sensor, it would not make sense to disable all of the Network Sensor Node's actual functionality. Bro or Suricata should be enabled.)

##### Datastore Node
The datastore stores and indexes the Bro Logs and Suricata Alerts into an easily searchable format. To ensure no data is lost both Apache Kafka and Logstash (with Persistent Queueing enabled) are set to buffer data from FileBeat. This script provides an easy mechanism to choose between using the full ELK (ElasticSearch, Logstash, Kibana) Stack or Splunk. It is all protected behind an Nginx Reverse Proxy and limited access to by Docker's local internal networking.  
  * Apache Kafka
  * Logstash
  * ElasticSearch (With X-Pack Plugin)
  * Nginx
    * Kibana (With X-Pack Plugin)
    * Splunk
      - BusyBox

Required: Nginx. (Like the Network Sensor Node, it would make no sense to disable the functionality of the Datastore Node, thus either ELK Stack or Splunk must be enabled)

##### Application Node
The application node provides 'nice to have' applications for team collaboration. FreeIPA is a required tool for all services because it provides DNS and LDAP (as well as NTP if desired).
  * FreeIPA
  * Nginx
    * GoGS
    * Rocket.Chat
      - MongoDB
    * OwnCloud (with ldap plugin)
    * TheHive with Cortex and ElasticSearch (no X-Pack supported)

Required: FreeIPA. (everything else is optional)

All servers have been tested with a base of CentOS 7.4 Minimal with DISA STIGs and SELinux enabled. All nodes install IPA client and require authentication against the Application Node. Root access is disabled. Users must sudo to use root level permissions.  

Prior to installation, any piece of software may be disabled from being installed and configured within the installation script.

For performance reasons, all applications run as containerized instances using Docker except Bro NSM, Suricata IDS, and Google Stenographer.

The only paid products in CozyStack are the X-Pack plugin (required for RBAC, SSO via LDAP, and SSL Encryption) and Splunk (required for anything). Both come with short trial periods. Since they are the heart of CozyStack, they are left in (The preference is to use free, open source software). Either may be disabled, but disabling both misses the point of this platform.

To configure Single Sign On, follow the Installation Guide.

### Customizing the Installation Script.
Below will detail how to customize the installation script. Near the top of the installation script, you will see a set of bash variables. This will tell you what to modify and how. **Do _NOT_ put a space between the value and the equal sign!** This will break the scripts.

##### IP Schema
To change the IP schema, simply change the last octet of any address below.

Note: ESDATA *must* be the last IP as it will create all of the ElasticSearch data nodes with that IP and the ones following it.

Also Note: the first 3 octets of the IP Schema are determined by the network interface. (There are two network interfaces, collection and analysis. The analysis NIC determines the IP Schema)

```
export IPA_IP=$IP.5
export ES_IP=$IP.6
export ESSEARCH_IP=$IP.7
export KIBANA_IP=$IP.8
export OWNCLOUD_IP=$IP.9
export GOGS_IP=$IP.10
export CHAT_IP=$IP.11
export SPLUNK_IP=$IP.12
export HIVE_IP=$IP.13
export CORTEX_IP=$IP.14
export KAFKA_IP=$IP.15
export ESDATA_IP=$IP.16
```

##### Network Traffic
The explanation of this requires you to understand what your system architecture is as well as the network to be tapped.

For every 1 Gbps of network traffic expected, it is recommended that you use 4 Bro workers and 1 Stenographer thread (minimum of 2 stenographer threads). To tap a 1Gbps network, 4 Bro workers, 2 Stenographer threads, and 4 Suricata threads (allocated by Suricata) will be needed. These 3 applications will also require around 12GBs of RAM per 1Gbps of network traffic. That means the Network Sensor Node box will need at least 11 cores (1 for system processes) and 16GB of RAM to handle 1 Gbps without loss.

Multiple Network Sensor Nodes may be needed based on the network traffic volume.

```
export BRO_WORKERS=4
```

```
export STENO_THREADS=2
```
##### ElasticSearch Configuration

Much like the Network Sensor Node, there is some balancing of resources that must be done.

```
export ES_RAM=2g
export ES_DATA_NODES=2
```

##### Optional Software

the following is a list of optional software. To disable any software, replace 'true' with 'false'.

```
export ENABLE_STENOGRAPHER=true
export ENABLE_ELK=true
export ENABLE_SPLUNK=true
export ENABLE_GOGS=true
export ENABLE_CHAT=true
export ENABLE_HIVE=true
export ENABLE_OWNCLOUD=true
export ENABLE_SURICATA=true
export ENABLE_BRO=true
```
