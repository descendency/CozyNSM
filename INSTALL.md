# CozyNSM Install
This installation takes me around 2 hours. 1 hour to install CentOS and 1 hour
to run the install script and configure the services. This is being done in a
Virtual Machine on an ESXi server.

Setting up RAID Arrays, Switches, Routers, etc are not part of this and should
be done prior to installation.

### Pre-Install
From another machine (I recommend creating a virtual machine), you must run
```preinstall.sh```. This will download all of the required files for the
installation. Once this has completed, move those files onto the server.

(In the future, this may be a multi-server build for those that need this
capability. The same process will apply.)

### Server Install
Download the latest scripts and install files onto a laptop. If you want to
use you own files, this script may fail. The configurations should work, but
this has only been tested with the supplied files.

This is designed to setup a single server, but the configurations could be
spread across multiple servers with some effort.

##### CentOS
1. Insert CD (or attach the ISO to a VM). Boot the system until the CentOS
menu prompts to Install. Select the first option (by default it is on the
second one).
1. After this, it will ask what language. Select English-US for simplicity.
Click Continue.
1. This is the main page for installation. At the bottom, Click 'Network And
Hostname'
    * In the bottom left, set the hostname. (suggested: server.test.lan if
    you want test.lan as your domain.)
    * In the left, click the interface connected to the Gigamon. Click the
    'On' switch in the top right.
    * In the left, now click the interface connected to a switch (for
    analysts). Click 'Configure' in the bottom right-ish.
    * In the box that pops up, click IPv4 settings. And enter the following
    settings:
        * Method: Manual
        * Address: (server IP)
        * Netmask: 24
        * Gateway: X.X.X.1
        * DNS: (FreeIPA server IP)
        * Additional Search Domains: test.lan (or whatever your domain is
        called.)
    * Click IPv6 Settings.
    * Set method to 'Ignore'
    * Click 'Save'
    * Now Switch the interface on in the top right.
    * Click 'Done' in the top left.
1. Select Kdump.
    * Uncheck 'Enable Kdump'
    * Click Done (in the top left).
1. Select Installation Destination.
    * Ensure the correct install drives are selected.
    * Select 'I will configure partitioning.' (You may need to scroll down)
    * Click 'Click here to create them automatically'
    * Click done in the top left.
    * Select swap and click the minus button in the bottom left.
    * Select /home and click the minus button in the bottom left.
    * Select / and remove the value from "Desired Capacity:"
    * Select /boot and watch / have all of the unallocated space allocated to
    it.
    * Double click Done.
    * Click Accept Changes in the box that pops up.
1. Select 'Security Policy'
    * Select 'Pre-release Draft STIG For CentOS 7 Linux Servers'.
    * Click Select Profile.
    * Click Done.
1. Select Date & Time.
    * Set Region to 'Etc' and City to 'Greenwich Mean Time'
    * Click the cogs on the top right.
    * Type in (FreeIPA server IP). Click
    the plus.
    * Uncheck all of the other boxes.
    * Click Save (or is it done?)
    * Click Done.
1. Click Begin Installation.
1. Click root password and set a root password. You may need to double click
done if your password is weak.
1. Click User Creation and set a user. Make sure 'Make this user
administrator' is checked. You may need to double click done if
your password is weak.
1. Once complete, click restart.

##### install.sh
Once CentOS has finished installing, log in as root.

1. Run the following commands:
    * *From the laptop*: Copy files for Cozy to the server.
    * Enable the install script to run ("chmod +x install.sh").
1. The script currently does not prompt the user. You may need to change
the following values (in install.sh):
    * BRO_WORKERS=4 [Bro workers should be assigned based on the number of gbps
    you are going to need to collect. Generally, 4 workers per 1 gbps. Each
    worker requires 1 CPU core, therefore don't set this to 400 expecting to
    collect 100gbps for free. (Hardware matters). By default, I would suggest 4
    workers for a 1Gbps network.]
    * ES_RAM=30g [The Elasticsearch Heap Size should be between 2g and 31g.
    Do not put more than this. It will cause massive performance degredation due
    to how the JVM (java virtual machine) allocates memory.]
    * ES_DATA_NODES=1
    * And all of the IP schema values.
1. Run install.sh.
1. This script will prompt the installer for a few things.
Answer them like this:
    * The collection interface is the interface plugged into the tap.
    * The analyst interface is the one connected to the analyst side.
    * Domain name is the desired domain (ex: test.lan, example.com, me.io,
    etc)
    * The first username (also an administrator). This can not have spaces,
    periods, hyphens, etc. Only numbers and letters.
    * The IPA administrator password will be the password for the 'admin'
    user in FreeIPA and for basic domain management. This should be complex.
    (You will need this again... so write it down.)

This will take approximately an hour. This will start the manual part of the
setup.

##### FreeIPA
Before anyone can log into FreeIPA, you must edit your local host file
(ex: on a laptop) to include an entry for ipa.domain.name to point to
the ipa server (Example: 172.16.124.4 ipa.test.lan ipa).

After this is done, all workstations should have their NTP set to point at
the same IP. (Look up how to set a time server on Google for your OS) This
will be necessary for events in Kibana to appear as if they happened when
they actually did.

Finally, set your local (laptop) DNS to point at your FreeIPA server.

At this point you can create all of your users or you can wait for later. But
for now, there are more services to setup.

### Single Sign On (SSO) Setup
Single Sign On setup will enable you to create, manage, and remove accounts
from inside of FreeIPA, instead of using multiple different administrator
panels.

**Gogs username is 'cozyadmin' and password is 'password'. Change this.**

##### Rocket.Chat
Due to a bug in RocketChat, I can't script this part. [as soon as the bug is
fixed, it will automatically work]

Log in as cozyadmin (same password as IPA's admin).

1. Click the profile name in the top left. This will drop down a menu shade.
1. Click "Administration". On the left side, under settings, click "LDAP". You
may have to scroll down.
1. In this form, edit the following lines:
    * Domain Search Object Class: (empty)
    * Domain Search Object Category: (empty)
    * Username Field: (empty)
1. Click "SAVE CHANGES" in the top right corner. Once the green box appears
with changes saved, click "TEST CONNECTION." If that passes, CLICK "SYNC
USERS".
1. Sign out and try signing in with an account you made in FreeIPA. This
should successful sign in.

##### Splunk
Login as admin (first time password is 'changeme'). Change the password to a
more secure (non-default) password and log this somewhere. This is the local
Splunk administrator.

(Note: in this example the domain is 'test.lan', so dc=test,dc=lan will need to
be changed to fit your domain.)

1. Settings > Access Controls
1. Authentication Method
1. Set 'external' to 'LDAP'
1. Click LDAP Settings (This will say something else)
1. Click 'NEW'
1. Set the following values:
    * Give your configuration a name.
    * Host: (FreeIPA server IP)
    * Port: 389
    * Bind DN: uid=admin,cn=users,cn=accounts,dc=test,dc=lan
    * Bind DN Password & Confirm password should be the IPA Admin password.
    * User base DN: cn=users,cn=accounts,dc=test,dc=lan
    * User name attribute: uid
    * Real name attribute: cn
    * Email attribute: mail
    * Group mapping attribute: uid
    * Group base DN: cn=groups,cn=compat,dc=test,dc=lan
    * Group name attribute: cn
    * Static member attribute: memberuid
    * Check 'Advanced Settings' (change nothing below.)
1. Click save.
1. Actions > Map groups.
1. Set each group with appropriate accesses (as set by organizational policy)
This might also be a good time to define the appropriate groups for your
organization (in FreeIPA). Giving universal administrator functions may be a bad
idea.

Side node: I have no idea why Splunk needs the compat version of groups. That
annoys me, but whatever. It works.
