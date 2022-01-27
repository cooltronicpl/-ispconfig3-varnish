# README Wordpress Varnish Cacher for Wordpress sites on ISP Config

This ISPConfig plugin is built for those who wants setup Varnish Cache in ISPConfig for Wordpress sites. We use Varnish for cache, Apache for the backend, and we added NGINX for SSL termination.

So, we can have two scenario :

- Without SSL: `Visitor > Varnish > Apache`
- With SSL: `Visitor > NGINX > Varnish > Apache`

I've done test with the following configuration:

- Debian 11 x64
- Apache 2.4.52
- nginx-common 1.18.0
- Varnish 6.5.1
- Wordpress 5.8.2, 5.9
- WP Bakery Builder and Elementor
- ISPConfig Version 3.2.7p1

It works with WP Rocket 3.10.6 Varnish add-on cache clearing with this config. Also cache purging are working with Proxy Cache Purge 5.0.3.

This should work fine with Ubuntu, and may requires small adjustments to work well on CentOS & RHEL-based distributions.

## Installation steps

Install dependancies:

    apt-get install debian-archive-keyring curl gnupg apt-transport-https gnupg2 ca-certificates lsb-release git -y

### Install Varnish repo

    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish64/script.deb.sh | sudo bash

### Install NGINX repo

    echo "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -

### Install Varnish and NGINX

    apt-get update
    apt-get install nginx varnish -y

Clone the repo:

    git clone https://github.com/cooltronicpl/-ispconfig3-varnish.git

Change Apache2 ports:

    sed -i 's/Listen 80/Listen 680/g' /etc/apache2/ports.conf
    sed -i 's/Listen 443/Listen 6443/g' /etc/apache2/ports.conf

If you applied before manoaratefy script you may need (only if you applied <https://github.com/manoaratefy/ispconfig3-varnish>:

```
sed -i 's/Listen 6080/Listen 680/g' /etc/apache2/ports.conf
```

Change Varnish ports:

    cp /lib/systemd/system/varnish.service /tmp/varnish.service.old
    perl -pe 's/(\s*)ExecStart(\s*)=(\s*)\/usr\/sbin\/varnishd(.*)/ExecStart=\/usr\/sbin\/varnishd -a :80 -a :7443 -f \/etc\/varnish\/default.vcl -s malloc,512m -p http_resp_hdr_len=42000 \/ /g' /tmp/varnish.service.old | tee /lib/systemd/system/varnish.service > /dev/null
    systemctl daemon-reload

Move all files to its place:

    cd ispconfig3-varnish
    cp -R etc/* /etc/
    cp -R usr/* /usr/

Avoid NGINX to listen to port 80 and prepare folders:

    rm /etc/nginx/conf.d/default.conf
    mkdir /etc/nginx/sites-available
    mkdir /etc/nginx/sites-enabled

Enable the plugin:

    ln -s /usr/local/ispconfig/server/plugins-available/varnish_plugin.inc.php /usr/local/ispconfig/server/plugins-enabled/varnish_plugin.inc.php

Fix remote IP detection:

    a2enmod remoteip
    cp /etc/apache2/sites-available/ispconfig.conf /etc/apache2/sites-available/ispconfig.conf.old
    perl -pe 's/(\s*)LogFormat(\s+)"(.*)%h(.*)"(.*)combined_ispconfig/LogFormat "%v %a %l %u %t \\"%r\\" %>s %O \\"%{Referer}i\\" \\"%{User-Agent}i\\"" combined_ispconfig/g' /etc/apache2/sites-available/ispconfig.conf.old | tee /etc/apache2/sites-available/ispconfig.conf > /dev/null

For many scripts like Wordpress:

```
echo "<IfModule setenvif_module>" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" X_SERVER_PORT=443" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" X_REQUEST_SCHEME=https" >> /etc/apache2/apache2.conf
echo "</IfModule>" >> /etc/apache2/apache2.conf
```

When this is applied the redirection to HTTPS in .htaccess must be modified (example in Notes section) 

Then, rebuild all vHost **BEFORE RESTARTING SERVICES** (in other case, Apache may not start then you'll not be able to open ISPConfig control panel).

    ISPConfig > Tools > Sync Tools > Resync > Check "Websites" > Start
After that, you can restart all services:

    systemctl restart apache2
    systemctl restart varnish
    systemctl restart nginx

## Notes

Apache ports: 680 (non SSL) / 6433 (dummy SSL)

Varnish ports: 80 (non SSL) / 680 (pseudo SSL, it works fine with ISPConfig SSL certificates)

NGINX ports: N/A (non SSL) / 443 (SSL)

The pseudo-SSL is a particular port used by Apache & Varnish to be a back-end for the NGINX SSL. The traffic itself is not SSL but the environment is configured to say to PHP scripts that we are on SSL connection (X-Forwarded-Proto & HTTPS environment variable).

### Redirection loop in many systems like Wordpress

### Redirection to HTTPS

You may need modify our redirection to HTTPS:

```
## START HTTPS

<IfModule mod_rewrite.c>
# ensure https
RewriteEngine On
# RewriteCond %{HTTPS} off 
#<- Apache2
# below line for nginx varnish
RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]
# First rewrite to HTTPS:
# Don't put www. here. If it is already there it will be included, if not
# the subsequent rule will catch it.
RewriteRule (.*) https://ssl-site.com/$1 [R=301,L]
</IfModule>
### END HTTPS
```

## For certain domains and scripts which may not be used with varnish

You may add multiple of domain host which you want to pass through Varnish, example is included in /etc/varnish/default.vcl.

```
if (req.http.host=="domain-to-disable.com"){
   return(pass);
  }
```

## What needed to be improved?

I'm not a ISPConfig developer. I don't know if the way I do thing is good enough to have long-term compatibility with ISPConfig. I'm just making things working. So, I'm calling other developers to review my code and to adjust things that I do wrong.

Here is a short list of things I think I'm not doing great:

- **Full caching management interface on ISPConfig**
Admins and users may requires an interface to use Varnish correctly (advanced caching rules, flushing the cache, caching rules template, ...) It is relatively easy to implement it with an external software (means outside ISPConfig control panel) as the proposed Varnish configuration doesn't depend on any ISPConfig functionnality. Theorically, we can use any Varnish Control Panel without interference. But it would be great if someones found a way to integrate in under the ISPConfig interface itself.

There may be other improvements. Just open an issue/request a feature.

## Installation services

Do you need a sysadmin to install this module into your ISPConfig? I'm available for you. [Contact us](https://cooltronic.pl/) or [Or developer](<https://potacki.com/>).

If my work was useful for your business, or you have problems with this script, and you need help contact me.

## Credits & Sponsors

I've found very useful information in the following URL:

- manoaratefy: <https://github.com/manoaratefy/ispconfig3-varnish>
- <https://github.com/Rackster/ispconfig3-nginx-reverse-proxy>
- <https://www.howtoforge.com/community/>
