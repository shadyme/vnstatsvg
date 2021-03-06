

# vnStatSVG installation on Busybox based embedded system

* Author: Wu Zhangjin <wuzhangjin@gmail.com> of TinyLab.org
* Update: Sun Jul 28 22:23:13 CST 2013

## Introduction

vnStatSVG is a very lightweight web fronted to the vnStat traffic logger, it
not only works very well on standard Linux distributions but also works
perfectly on Busybox based embedded systems.

As we know, embedded systems have the critical requirement to reduce
disk/memory footprint, so, most of them will not provide a full-featured web
server like apache2, but only provide a lightweight httpd server. So, no
possibility to enable PHP or the other powerful but recourse-cost web
languages.

Differ from the other vnStat frontends, vnStatSVG doesn't need the support of
PHP, It only requires the basic CGI support, so, no apache2 required, no PHP
required.

For the detailed design principle of vnStatSVG, see
<http://ieeexplore.ieee.org/xpl/mostRecentIssue.jsp?punumber=4562771>

In the coming sections, we will introduce its usage on Busybox based embedded
systems.

## Configure

vnStatSVG provides 3 methods to dump the XML data of the traffic information,
to simplify the installation procedure, we only introduce the 3rd method, which
will compile the --dumpxml support into the original vnstat package(I name it
'patch' method), currently, the supported vnstat version is 1.6.

    $ ./configure -m p

Note: the lastest version of vnStat also provide a --xml option to dump all of
the data in one file, but it is not compatible with the XML format of
vnstatSVG, so, our own --dumpxml is required currently.

## Compile

To demonstrate the usage of it on ARM target device, we use cross compile here:

    $ make CFLAGS=" -static " CROSS_COMPILE=arm-linux-gnueabi-

Now should be able to find the 'vnstat' binary:

    $ file src/cgi-bin/vnstatxml-1.6/src/vnstat
    src/cgi-bin/vnstatxml-1.6/src/vnstat: ELF 32-bit LSB executable, ARM, version 1 (SYSV), statically linked, BuildID[sha1]=0x823f0e6389132eb41ba5c6abbcd9774063e24820, stripped

## Installation

### Install vnStat

The above section compiled the vnStat binary, this is the tool which can
monitor network interfaces through the /proc/net/dev interfaces and can save
the data to a specified directory with default /var/lib/vnstat/.

So, we must install 'vnstat' to our target device at first, for example, we
install it to /usr/bin/vnstat.

And then, create a directory '/var/lib/vnstat/':

    $ mkdir /var/lib/vnstat/

To start monitor and save the network traffic data, we can simply issue:

    $ ./vnstat -u -i eth0

This will monitor the 'eth0' interaface and create a file named
/var/lib/vnstat/eth0.

To monitor the other network interfaces, please replace 'eth0' with their name,
for example, 'lo'.

To monitor network traffic all the time, a simple script or cron task should be
created, herein, we write a simple update script which will monitor every 5
seconds:

    #!/bin/sh
    # vnstat-update.sh
    
    while :;
    do
    	/usr/bin/vnstat -u -i eth0
    	sleep 5
    done

To monitor your embedded system network traffic, you can add the above script
in your /etc/rc.local, for example:

    /bin/vnstat-update.sh &

This is required to collect data for vnStatSVG, after getting enough data, it's
time to install vnStatSVG now.

### Install vnStatSVG

vnStatSVG requires a simple httpd service with CGI support, firstly, Let's
start httpd service.

Busybox itself provides a very lightweight httpd server, we can use it directly.

But by default, httpd doesn't know the files with .xml and .xsl extensions, to
use the files in vnStatSVG, we must tell httpd about the related 'MIME Type
Mappings' via the httpd conf file, see src/conf/busybox-httpd.conf as an
example:

    .xml:text/xml
    .xhtml:text/xml
    .xsl:text/xml

Afterwards, we must tell which directory used for the web root directory, for
example: /data/www/. Our administration files: src/admin must be installed in
this directory.

Busybox httpd will use the cgi-bin directory of the web root directory as the
default cgi-bin directory, so, our cgi-bin files: src/cgi-bin must be installed
into this directory.

Now, Let's start httpd service with port 8080:

    $ httpd -h /data/www/ -p 8080 -c /data/httpd.conf

Then, install some files under src/admin/ and src/cgi-bin/ to the target devices.

The following files must be installed to /data/www:

    index.xhtml  index.xsl           -- For home page
    sidebar.xml  sidebar.xsl         -- For sidebard
    vnstat.css  vnstat.js  vnstat.xsl	-- For main window

For single host monitoring, only need to install vnstat-p.sh to
/data/www/cgi-bin/ and rename it to vnstat.sh.

For multi hosts monitoring, must install the other two files: httpclient
and proxy.sh, and accordingly, must use the sidebar template:
sidebar.xml-template-4-multihosts to add the hosts want to monitor.

The other hosts only need to install vnstat-p.sh to /cgi-bin/vnstat.sh, no need
to install the administration files.

## Configuration

Firstly, let's introduce single host monitoring.

### Administration configuration

To monitor a host, the network interface, host description, ip address of domain name
should be provided, see src/admin/sidebase.xml as an example:

    <?xml version='1.0' encoding='UTF-8' standalone='no' ?>
    <sidebar id="sidebar">
    <!-- if want to get help, please read the *-template-* file in the source code vnstatsvg-<version>/src/admin  -->
    <iface><name>eth0</name><description>host</description><host>localhost</host><dump_tool>/cgi-bin/vnstat.sh</dump_tool></iface>
    </sidebar>
    
Since we are monitoring our target device, we must replace the 'localhost'
string to the domain name or ip address of the target device, for example:
192.168.0.2.

And must replace 'eth0' with the real network interface name, for example, eth1.

For the host description, give a short description of the target device means
useful.

### CGI binary configuration

For the dump_tool part, it is the relative path of the installed vnstat.sh, for
example, if have installed vnstat.sh to /data/www/cgi-bin/vnstat/vnstat.sh, it
must be replaced with /cgi-bin/vnstat/vnstat.sh.

And If 'vnstat' is not installed to /usr/bin/vnstat, must specify the real
path in the installed vnstat.sh file:

    # indicate several commands
    VNSTAT="/usr/bin/vnstat"

Now, we get a new sidebar.xml like this:

    <?xml version='1.0' encoding='UTF-8' standalone='no' ?>
    <sidebar id="sidebar">
    <!-- if want to get help, please read the *-template-* file in the source code vnstatsvg-<version>/src/admin  -->
    <iface>
    	<name>eth1</name>
    	<host>192.168.0.1</host>
    	<dump_tool>/cgi-bin/vnstat/vnstat.sh</dump_tool>
    	<description>Busybox based embedded system</description>
    </iface>
    </sidebar>

With the above configuration, should be able to access vnStatSVG now,
open the following URL via any of the following browsers: chromium-browser,
Firefox and IE. crhomium-browser is recommended.

    http://192.168.0.1:8080/index.xhtml

For multi interfaces or multi hosts, please refert to the template:
sidebar.xml-template-4-multihosts and add more nodes to sidebar.xml.

That's all.
