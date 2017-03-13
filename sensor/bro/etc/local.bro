#! Local site policy. Customize as appropriate.
##!
##! This file will not be overwritten when upgrading or reinstalling!

# Redis Writer
#@load /usr/local/bro/lib/bro/plugins/Bro_Redis/scripts/init.bro
#@load /usr/local/bro/lib/bro/plugins/Bro_Redis/scripts/Bro/Redis/logs-to-redis.bro

# This script logs which scripts were loaded during each run.
@load misc/loaded-scripts

# Apply the default tuning scripts for common tuning settings.
@load tuning/defaults

# Estimate and log capture loss.
@load misc/capture-loss

# Enable logging of memory, packet and lag statistics.
@load misc/stats

# Load the scan detection script.
@load misc/scan

# Detect traceroute being run on the network. This could possibly cause
# performance trouble when there are a lot of traceroutes on your network.
# Enable cautiously.
@load misc/detect-traceroute

# Generate notices when vulnerable versions of software are discovered.
# The default is to only monitor software found in the address space defined
# as "local".  Refer to the software framework's documentation for more
# information.
@load frameworks/software/vulnerable

# Detect software changing (e.g. attacker installing hacked SSHD).
@load frameworks/software/version-changes

# This adds signatures to detect cleartext forward and reverse windows shells.
@load-sigs frameworks/signatures/detect-windows-shells

# Load all of the scripts that detect software in various protocols.
@load protocols/ftp/software
@load protocols/smtp/software
@load protocols/ssh/software
@load protocols/http/software
# The detect-webapps script could possibly cause performance trouble when
# running on live traffic.  Enable it cautiously.
#@load protocols/http/detect-webapps

# This script detects DNS results pointing toward your Site::local_nets
# where the name is not part of your local DNS zone and is being hosted
# externally.  Requires that the Site::local_zones variable is defined.
@load protocols/dns/detect-external-names

# Script to detect various activity in FTP sessions.
@load protocols/ftp/detect

# Scripts that do asset tracking.
@load protocols/conn/known-hosts
@load protocols/conn/known-services
@load protocols/ssl/known-certs

# This script enables SSL/TLS certificate validation.
# @load protocols/ssl/validate-certs

# This script prevents the logging of SSL CA certificates in x509.log
# @load protocols/ssl/log-hostcerts-only

# Uncomment the following line to check each SSL certificate hash against the ICSI
# certificate notary service; see http://notary.icsi.berkeley.edu .
# @load protocols/ssl/notary

# If you have libGeoIP support built in, do some geographic detections and
# logging for SSH traffic.
@load protocols/ssh/geo-data
# Detect hosts doing SSH bruteforce attacks.
@load protocols/ssh/detect-bruteforcing
# Detect logins using "interesting" hostnames.
@load protocols/ssh/interesting-hostnames

# Detect SQL injection attacks.
@load protocols/http/detect-sqli

#### Network File Handling ####

# Enable MD5 and SHA1 hashing for all files.
@load frameworks/files/hash-all-files

# Detect SHA1 sums in Team Cymru's Malware Hash Registry.
@load frameworks/files/detect-MHR

# Uncomment the following line to enable detection of the heartbleed attack. Enabling
# this might impact performance a bit.
# @load policy/protocols/ssl/heartbleed

# Uncomment the following line to enable logging of connection VLANs. Enabling
# this adds two VLAN fields to the conn.log file.
@load policy/protocols/conn/vlan-logging

# Uncomment the following line to enable logging of link-layer addresses. Enabling
# this adds the link-layer address for each connection endpoint to the conn.log file.
@load policy/protocols/conn/mac-logging

# Uncomment the following line to enable the SMB analyzer.  The analyzer
# is currently considered a preview and therefore not loaded by default.
@load policy/protocols/smb
@load tuning/json-logs

redef LogAscii::json_timestamps = JSON::TS_ISO8601;
redef LogAscii::use_json = T;
# md5party extract files

export
{
        const ext_map: table[string] of string = {
                ["application/msword"] = "doc",
                ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"] = "docx",
                ["application/x-dmg"] = "dmg",
                ["application/x-dosexec"] = "exe",
                ["application/x-msdownload"] = "exe",
		            ["application/x-msdos-program"] = "exe",
		            ["application/octet-stream"] = "exe",
                ["application/java-archive"] = "jar",
                ["application/x-java-applet"] = "jar",
                ["text/x-perl"] = "pl",
                ["application/pdf"] = "pdf",
                ["application/mspowerpoint"] = "ppt",
                ["application/powerpoint"] = "ppt",
                ["application/vnd.openxmlformats-officedocument.presentationml.presentation"] ="pptx",
                ["text/x-script.python"] = "py",
                ["text/x-ruby"] = "rb",
                ["application/x-bsh"] = "sh",
                ["application/x-sh"] = "sh",
                ["application/x-font-ttf"] = "ttf",
                ["application/excel"] = "xls",
                ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"] = "xlsx",
                ["application/xml"] = "xml"
        } &redef &default="";
}

redef FileExtract::prefix = "/data/md5party/extract";

event file_sniff(f: fa_file, meta: fa_metadata)
{
        local ext = "";

        if ( meta?$mime_type )
        {
                ext = ext_map[meta$mime_type];
        }

        if ( ext == "" )
        {
                return;
        }

        # Files::add_analyzer(f, Files::ANALYZER_MD5);

        local fname = fmt("%s-%s-%s", f$source, f$id, ext);
        Files::add_analyzer(f, Files::ANALYZER_EXTRACT, [$extract_filename=fname, $extract_limit=100]);

        local cmd = fmt("bash /data/md5party/md5party.sh /data/md5party/extract/%s-%s-%s", f$source, f$id, ext);
        system(cmd);
}

event bro_init() &priority=-10
{
        Log::disable_stream(CaptureLoss::LOG);
        Log::disable_stream(Cluster::LOG);
        Log::disable_stream(Communication::LOG);
        Log::disable_stream(LoadedScripts::LOG);
        Log::disable_stream(PacketFilter::LOG);
        Log::disable_stream(Stats::LOG);
        Log::disable_stream(Unified2::LOG);
        Log::disable_stream(DPD::LOG);
        Log::disable_stream(Software::LOG);
}
