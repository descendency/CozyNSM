# Note: Some settings may not be relevant to the type of install you are trying
# to do. You can skip those settings. IE, you do not have to specify the number
# of Bro workers if you are only installing a datastore.
################################################################################
# Repository                                                                   #
################################################################################
export LOCAL_REPO="false"           # Do you want to use a local RPM repository?
################################################################################
# Server Roles                                                                 #
################################################################################
# Note: A server can be 1, 2 or all 3 of these roles.
export IS_SENSOR="true"           # Is the server a sensor (Bro, Suricata, etc)
export IS_DATASTORE="true"        # Is the server a datastore (ELK/Splunk)
export IS_APP_SERVER="true"       # Is the server an application server (Gogs, Chat, etc.)
################################################################################
# IP Schema                                                                    #
################################################################################
# Note: You only need to change these if your environment requires custom IPs.
# DNS is enabled so you can use the DNS names to access these services.

# Warning: THESE MUST BE ".XX"! IT WILL BREAK WITHOUT IT!
export SENSOR_IP=".3"
export DATA_IP=".4"
export APP_IP=".99"
export IPA_IP=".5"                       # FreeIPA IP
export ES_IP=".6"                        # ES Master Node IP
export ESSEARCH_IP=".7"                  # ES Search Head - Attached to Kibana
export KIBANA_IP=".8"                    # Kibana IP - attached to ES Search Head
export OWNCLOUD_IP=".9"                  # OwnCloud IP
export GOGS_IP=".10"                     # Gogs IP
export CHAT_IP=".11"                     # RocketChat IP
export SPLUNK_IP=".12"                   # Splunk IP
export HIVE_IP=".13"                     # TheHive IP
export CORTEX_IP=".14"                   # Cortex IP
export ESDATA_IP=".15"                   # The Starting IP for ES Data Nodes
################################################################################
# Tool Selection                                                               #
################################################################################
# 'true' means it will be installed on this server IF this server is the right kind of server. EX: Bro on a Sensor.
# 'false' means it will not be loaded on this server.
export ENABLE_STENOGRAPHER="true"
export ENABLE_ELK="true"
export ENABLE_SPLUNK="true"
export ENABLE_GOGS="true"
export ENABLE_CHAT="true"
export ENABLE_HIVE="true"
export ENABLE_OWNCLOUD="true"
export ENABLE_SURICATA="true"
export ENABLE_BRO="true"
################################################################################
# Bro Config                                                                   #
################################################################################
# Number of Bro workers to process traffic.
# 4 workers per 1 Gbps of traffic.
export BRO_WORKERS="4"      # For VMs
################################################################################
# Stenographer Config                                                          #
################################################################################
# Number of stenographer collection threads.
# 1 thread per 1 Gbps of traffic, minimum 2 threads.
export STENO_THREADS="2"
################################################################################
# ElasticSearch Config                                                         #
################################################################################
# Heap Space Allocation for Elasticsearch (do NOT use over 31g)
export ES_RAM="2g"     # 2GiB Heap Space for Elasticsearch (For VMs)
# How many ElasticSearch Data nodes do you want? (Remember: there is 1 Master
# and 1 Search Node, already.)
export ES_DATA_NODES="6"
# Configure which ElasticSearch services you need on a datastore server.
export IS_ELK_DATA_NOTE="true"        # Install a Data Node?
export IS_ELK_SEARCH_NOTE="true"      # Install Kibana and a Search Node?
export IS_ELK_MASTER_NOTE="true"      # Install 'the' Master Node?
# Coinfugre if you are using the paid version of Elastic products or not
export ENABLE_XPACK="true"            # Set to false if you are not using the
                                      # paid version of Elastic's XPACK.
