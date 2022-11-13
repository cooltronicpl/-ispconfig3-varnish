# WordPress and CraftCMS 3, Craft CMS 4 Varnish Cache Plugin with Nginx SSL to cache www sites on ISP Config 3.8.2p1

With ❤️ [CoolTRONIC.pl sp. z o.o.](https://cooltronic.pl) presents caching solution written by [Pawel Potacki](https://potacki.com)

This ISPConfig 3 plugin is built for those who want to set up Varnish Cache in ISPConfig for WordPress, and CraftCMS sites. We use Varnish for the cache, Apache for the backend, and we added NGINX for SSL termination.
Your site is fast as rocket also with WP Rocket, Proxy Cache Purge on WordPress, and CoolTRONIC.pl Varnish Cache Purge on CraftCMS.

So, we can have two scenarios:

Without SSL: Visitor > Varnish > Apache
With SSL: Visitor > NGINX 443 > Varnish localhost 7443 > Apache

I've done the test with the following configuration:

* Debian 11 x64
* Apache 2.4.52
* nginx-common 1.18.0
* Varnish 6.5.1
* Wordpress from 5.7, 5.8.2, 5.9, 6.0.x to 6.1
* WP Bakery Builder and Elementor for WordPress
* Now compatible with ISPConfig Version 3.2.8p1
* WordFence IP Detection
* WP Rocket from 3.10.6 up to 3.12.x with the plugin "WP Rocket | Alter Varnish's args" to change Varnish Addr on SSL sites
* Proxy Cache Purge for WordPress
* Softacolous with uncached staging in this example in /staging subfolder
* CraftCMS 3.x with PHP 7.2 (with Composer patch)
* CraftCMS 4.x with PHP 8.0 (with Composer patch)
* Varnish Cache Purge 1.0.0-dev is now working now with CraftCMS 3.x and clears Varnish when we change data on SSL websites

Now in alfa testing, it will be published [here](https://github.com/cooltronicpl/varnishcache/) we can share it before if you want, please [contact us through the company site](https://cooltronic.pl/contact/). Notes at the end on [how to install CraftCMS in ISPConfig 3](https://github.com/cooltronicpl/-ispconfig3-varnish#craft-cms-4x-and-3x-install-notes-for-isp-config-3) and using with Plugin Installer and Composer are at the bottom. Now also with WP Rocket Nginx is using GZIP and BROTLI for all SSL hosts. It works with WP Rocket 3.10.6 up to 3.12.x Varnish add-on cache clearing with this config. Also, cache purging is working with Proxy Cache Purge 5.0.3 and to newest on v2.

This should work fine with Ubuntu, on Debian 11 also, and may requires small adjustments to work well on CentOS & RHEL-based distributions.

## Installation steps

Install dependancies:

```
    apt-get install debian-archive-keyring curl gnupg apt-transport-https gnupg2 ca-certificates lsb-release git -y
```

### Install Varnish repo (for me unnecessary on Debian 11, for old systems, needs testing)

```
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish64/script.deb.sh | sudo bash
```

### Install NGINX repo (for me unnecessary on Debian 11, for old systems, needs testing)

```
    echo "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
```

### Install Varnish and NGINX (this is the second step in Debian 11)

```
    apt-get update
    apt-get install nginx varnish -y
```

Clone the repo:

```
    git clone https://github.com/cooltronicpl/-ispconfig3-varnish.git
```

Change Apache2 ports:

```
    sed -i 's/Listen 80/Listen 680/g' /etc/apache2/ports.conf
    sed -i 's/Listen 443/Listen 6443/g' /etc/apache2/ports.conf
```

You may need other instruction if you applied old script by [manoaratefy](https://github.com/manoaratefy/ispconfig3-varnish):

```
sed -i 's/Listen 6080/Listen 680/g' /etc/apache2/ports.conf
```

Change Varnish ports:

```
    cp /lib/systemd/system/varnish.service /tmp/varnish.service.old
    perl -pe 's/(\s*)ExecStart(\s*)=(\s*)\/usr\/sbin\/varnishd(.*)/ExecStart=\/usr\/sbin\/varnishd -a :80 -a localhost:7443 -f \/etc\/varnish\/default.vcl -s malloc,512m -p http_resp_hdr_len=42000 \/ /g' /tmp/varnish.service.old | tee /lib/systemd/system/varnish.service > /dev/null
    systemctl daemon-reload
```

Move all files to its place:

```
    cd -ispconfig3-varnish
    cp -R etc/* /etc/
    cp -R usr/* /usr/
```

(Optional) You may add your server IPv4 and IPv6 (if server has) in default.vcl in acl purge, sometimes it fix some purge problems.

Avoid NGINX to listen to port 80 and prepare folders:

```
    rm /etc/nginx/conf.d/default.conf
    mkdir /etc/nginx/sites-available
    mkdir /etc/nginx/sites-enabled
```

Enable the plugin:

```
    ln -s /usr/local/ispconfig/server/plugins-available/varnish_plugin.inc.php /usr/local/ispconfig/server/plugins-enabled/varnish_plugin.inc.php
```

Fix remote IP detection:

```
    a2enmod remoteip
    cp /etc/apache2/sites-available/ispconfig.conf /etc/apache2/sites-available/ispconfig.conf.old
    perl -pe 's/(\s*)LogFormat(\s+)"(.*)%h(.*)"(.*)combined_ispconfig/LogFormat "%v %a %l %u %t \\"%r\\" %>s %O \\"%{Referer}i\\" \\"%{User-Agent}i\\"" combined_ispconfig/g' /etc/apache2/sites-available/ispconfig.conf.old | tee /etc/apache2/sites-available/ispconfig.conf > /dev/null
```

## For many scripts like Wordpress, Craft etc.

```
echo "<IfModule setenvif_module>" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" X_SERVER_PORT=443" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" X_REQUEST_SCHEME=https" >> /etc/apache2/apache2.conf
echo "</IfModule>" >> /etc/apache2/apache2.conf
```

When this is applied the redirection to HTTPS in .htaccess must be modified (example in the Notes section)
Then, rebuild all vHost **before restarting services** (in other cases, Apache may not start then you'll not be able to open the ISPConfig control panel). ISPConfig > Tools > Sync Tools > Resync > Check "Websites" > Start. 
After that, you can restart all services:


```
    systemctl restart apache2
    systemctl restart varnish
    systemctl restart nginx
```
## Craft CMS 4.x and 3.x Install notes for ISP Config 3

All cookies are included in this script, so the admin panel in YOUR_DOMAIN.com/admin works. To load CraftCMS from a private folder when not the parent of the web, you need to change:

1. If you want to use your Craft CMS you possibly need Composer installed to use Plugin Store
2. You must download the latest zip or tar.gz of CraftCMS
3. Copy web to web, and rest of files to private
4. Make a change in index.php from:```require dirname(__DIR__) . '/bootstrap.php';```. To:```require dirname(__DIR__) . '/private/bootstrap.php';```
5. Create database and user
6. Setup craft like on documentation of chosen version [4](https://craftcms.com/docs/4.x/installation.html) or [3](https://craftcms.com/docs/3.x/installation.html) 
6. If you want to install plugins from the admin panel with Composer add on the end of private/.env:

```
COMPOSER_HOME=/private
COMPOSER_CACHE_DIR=/private/cache
```

You now can use [CoolTRONIC.pl Varnish Cache Plugin for CraftCMS](https://github.com/cooltronicpl/varnishcache/), it will be soon available for 3.x and maybe for 4.x later. When you want to test it please, [contact us through the company site](https://cooltronic.pl/contact/).

## Notes

Apache ports: 680 (non SSL) / 6433 (dummy SSL)

Varnish ports: 80 (non SSL) / 680 (pseudo SSL, it works fine with ISPConfig SSL certificates)

NGINX ports: N/A (non SSL) / 443 (SSL)

The pseudo-SSL is a particular port used by Apache & Varnish to be a back-end for the NGINX SSL. The traffic itself is not SSL but the environment is configured to say to PHP scripts that we are on an SSL connection (X-Forwarded-Proto & HTTPS environment variable).

### Custom redirection to HTTPS.

It fixes the loop of redirection in many systems with .htaccess, redirecting from HTTP to HTTPS.
You must need to modify our existing redirection to HTTPS:

```
<IfModule mod_rewrite.c>
# ensure https
RewriteEngine On
# Your old redirect in Apache2 below:
# RewriteCond %{HTTPS} off 
# Below for nginx varnish caching:
RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]
# First rewrite to HTTPS:
# Don't put www. here. If it is already there it will be included, if not
# the subsequent rule will catch it.
RewriteRule (.*) https://ssl-site.com/$1 [R=301,L]
</IfModule>
### END HTTPS
```

## For certain domains or scripts which may not be used with varnish caching

You may add multiple domain hosts which you want to pass through Varnish, an example is included in /etc/varnish/default.vcl.

```
if (req.http.host=="domain-to-disable.com"){
   return(pass);
  }
```

## What needed to be improved?

I'm not an ISPConfig developer. I don't know if the way I do a thing is good enough to have long-term compatibility with ISPConfig. I'm just making things work. So, I'm calling other developers to review my code and to adjust things that I do wrong.
Here is a short list of things I think I'm not doing great:

- **Full caching management interface on ISPConfig**

Admins and users may require an interface to use Varnish correctly (advanced caching rules, flushing the cache, caching rules template, ...) It is relatively easy to implement it with external software (means outside ISPConfig control panel) as the proposed Varnish configuration doesn't depend on any ISPConfig functionality. Theoretically, we can use any Varnish Control Panel without interference. But it would be great if someone found a way to integrate it under the ISPConfig interface itself. We made big changes from the [repository](https://github.com/manoaratefy/ispconfig3-varnish).

There may be other improvements. Just open an issue/request a feature.

## Installation services

Do you need a sysadmin to install this module into your ISPConfig? We are available for you. [Contact us](https://cooltronic.pl/contact/) or [developer](<https://potacki.com/>). If my work was useful for your business, or you have problems with this script, and you need help contact me.

## Credits for contributors and knowledge sharing

I've found very useful knowledge in the following URL:

- [@manoaratefy](https://github.com/manoaratefy/ispconfig3-varnish)
- [@Rackster](https://github.com/Rackster/ispconfig3-nginx-reverse-proxy)
- [How to Forge](https://www.howtoforge.com/community/)

## License

ISPConfig 3 Varnish Cache Plugin

Copyright (c) 2022 CoolTRONIC.pl sp. z o.o. by Pawel Potacki

More about [CoolTRONIC.pl sp. z o.o. Interactive Agency](https://cooltronic.pl/)

More about [main developer Pawel Potacki](https://potacki.com/)

CoolTRONIC.pl sp. z o.o., hereby holds all copyright interest in the program “ISPConfig 3 Varnish Cache Plugin” written by Pawel Potacki.

ISPConfig 3 Varnish Cache Plugin is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 or 3 of the License, or (at your option) any later version.

ISPConfig 3 Varnish Cache Plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with ISPConfig 3 Varnish Cache Plugin. If not, see <https://www.gnu.org/licenses/>.

See files COPYING.GPL2 and COPYING.GPL3 for more License information.
