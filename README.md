# CozyNSM

CozyNSM is a Network Security Monitoring platform designed to be used by a tactical incident response team. It's a combination of many open-source software tools deployed on several pieces of equipment that provide large-scale data collection, sophisticated visualization, and team communication.

**Disclaimer: CozyNSM is designed to run on a specific hardware set. It is not a dynamic install, and may require some modification to work on other hardware sets.**

## Documentation

* [Installation Guide](docs/INSTALL.md)
* [Recommended Equipment and Methodology](docs/EQUIPMENT.md)
* [Recommended Laptop Software](docs/LAPTOP.md)
* [Additional Information](docs/INFO.md)
* [To-do List](docs/TODO.md)

## Software
* [Docker](https://www.docker.com/) (containerization)
* [Google Stenographer](https://github.com/google/stenographer) (full-packet capture)
* [Bro](https://github.com/bro/bro) (network analyzer)
* [Logstash](https://github.com/elastic/logstash) (data processing)
* [Elasticsearch](https://github.com/elastic/elasticsearch) (datastore)
* [Kibana](https://github.com/elastic/kibana) (data visualization)
* [TopBeat](https://www.elastic.co/downloads/beats/topbeat) (infrastructure metrics)
* [Suricata](https://suricata-ids.org/) (signature-based IDS)
* [FreeIPA](https://www.freeipa.org/page/Main_Page) (DNS, NTP, SSO)
* [Gogs](https://github.com/gogits/gogs) (git and wiki)
* [Openfire](http://www.igniterealtime.org/projects/openfire/) (chat)

## Contributors

Austin Jackson (vesche)  
Matthew Jarvis (descendency)  
Joseph Winchell (wiinches)

## Thanks

CozyNSM relies on a ton of awesome open-source projects. Huge thanks to the open-source community for making this project possible. CozyNSM is a fork of [ROCK NSM](http://rocknsm.io) and CAPES created by [MOCYBER](https://github.com/CyberAnalyticDevTeam). Big hats off to them, this project wouldn't exist without their work.