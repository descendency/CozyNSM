### Introduction
CozyNSM was designed and created to be a lightweight Security Onion          
replacement to be deployed in an SELinux Environment. This was tested with   
CentOS 7.2 Minimal, in an offline environment.                           

This version of the CozyStack was designed for one server.                   
Minimum Recommended Specs (1 gbps):                                          
- Modern-ish CPU with physical 16 cores                                     
- 64 GB RAM                                                                  
- As much disk space as possible. (even metadata takes up a lot of disk)

Multiply the above by the number of gbps you want to collect. It should give
an approximate value for what you will NEED.                                 

First, run ```preinstall.sh``` to grab all of the necessary files and then run
```install.sh``` to install everything. This process can be run across two
machines. This will help with air gapped environments.  

### README BELOW
CozyNSM 'requires' the following:
  - INSTALL.md (read this)
  - CentOS 7.2 (Build 1511) Minimal [Feel free to test other environments
    at your own leisure]

### CONTRIBUTORS
* Austin Jackson (https://github.com/vesche)
* Matthew Jarvis (https://github.com/descendency)
* Joseph Winchell (https://github.com/wiinches)

### SPECIAL THANKS
The Missouri National Guard (MoCyber). Their [ROCKNSM](http://rocknsm.io/) platform was the
inspiration for this project. Not only did they provide an awesome platform
and ideas, but also mentorship (and lots of troubleshooting).

Team 90 and Team 93. Members of both teams have contributed greatly to the   
structure, testing, and motivation to work on this project. Thanks for       
breaking and demanding as much as you did, because now it is significantly   
better than before.                                                          


[Install Guide](https://github.com/descendency/CozyNSM/blob/master/INSTALL.md)


[CentOS 7.2 Minimal](https://www.dropbox.com/s/pfoxtar2dpasg5o/CentOS-7-x86_64-Minimal-1511.iso?dl=0)
