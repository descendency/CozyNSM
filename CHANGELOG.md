Changelog:

03 JAN 2019
- Updated version numbers in pre-install.
- Changed elif to else in install.sh (was a syntax error)
- Updated preinstall.sh with new names for TheHive and Cortex docker images. Added version number controls for them.
- Updated IPA to correctly remove the unnecessary DNS entries for docker IPs.
- Removed blocking communication log from Bro. Was it removed?
- Fixed how Splunk picks the initial user.
- Bro AF_Packet setup during install (add lb)
- Removed /data/bro/current volume link from splunk. This isn't necessary with the forwarder. (and it was breaking Broctl deploy)
- Added vim-common & dos2unix to preinstall to have access to xxd & dos2unix in the build.
- Fixed Network Manager with Docker.
- Made Firewalld play nice with docker. No more disabling it from the start.

Need to fix:
- need to add switch to enable/disable X-Pack
- Fix universal forwarder
- Test multi-server case. 
