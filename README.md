# Wordpress and CraftCMS 3.x, Craft CMS 4.x Varnish Cache Plugin with nginx SSL to cache www sites on ISP Config 3.8.2p1

With ❤️ [CoolTRONIC.pl sp. z o.o.](https://cooltronic.pl) presents caching solution written by [Pawel Potacki](https://potacki.com)

This ISPConfig 3 plugin is built for those who wants setup Varnish Cache in ISPConfig for Wordpress, CraftCMS sites. We use Varnish for cache, Apache for the backend, and we added NGINX for SSL termination.

Your sites is fast as rocket also with WP Rocket, Proxy Cache Purge on WordPress and CoolTRONIC.pl Varnish Cache Purge on CraftCMS.

So, we can have two scenario :

- Without SSL: `Visitor > Varnish > Apache`
- With SSL: `Visitor > NGINX 443 > Varnish localhost 7443 > Apache`

I've done test with the following configuration:

- Debian 11 x64
- Apache 2.4.52
- nginx-common 1.18.0
- Varnish 6.5.1
- Wordpress 5.7, 5.8.2, 5.9, 6.0.x, 6.1
- WP Bakery Builder and Elementor for WordPress
- Comaptibile with ISPConfig Version 3.2.8p1
- WordFence IP Detection
- WP Rocket from 3.10.6 up to 3.12.x with modification plugin to change Varnish Addr on SSL sites
- Proxy Cache Purge
- Softacolous with uncached staging in this example in `/staging` subfolder
- CraftCMS 3.x with PHP 7.2 (with Composer patch)
- CraftCMS 4.x with PHP 8.0 (with Composer patch)
- Varnish Cache Purge 1.0.0-dev is now working now with CraftCMS 3.x and clears Varnish when we change data of SSL websites

Now in alfa testing, it will be published [here](https://github.com/cooltronicpl/varnishcache/) we can share it if you want, please [contact us](https://cooltronic.pl/contact/).
Notes at end how to install CraftCMS in ISPConfig 3 and using with Plugin Installer and Composer are at the bottom.
Now also with WP Rocket nginx is using GZIP and BROTLI for all SSL hosts.
It works with WP Rocket 3.10.6 up to 3.12.x Varnish add-on cache clearing with this config. Also cache purging are working with Proxy Cache Purge 5.0.3.

This should work fine with Ubuntu, on Debian 11 also, and may requires small adjustments to work well on CentOS & RHEL-based distributions.

## Installation steps

Install dependancies:

```
    apt-get install debian-archive-keyring curl gnupg apt-transport-https gnupg2 ca-certificates lsb-release git -y
```

### Install Varnish repo (for me unecessary on Debian 11, for old systems, needs testing)

```
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish64/script.deb.sh | sudo bash
```

### Install NGINX repo (for me unecessary on Debian 11, for old systems, needs testing)

```
    echo "deb http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
```

### Install Varnish and NGINX (this is second step in Debian 11)

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

##For many scripts like Wordpress, Craft etc.

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


```
    systemctl restart apache2
    systemctl restart varnish
    systemctl restart nginx
```

## Notes

Apache ports: 680 (non SSL) / 6433 (dummy SSL)

Varnish ports: 80 (non SSL) / 680 (pseudo SSL, it works fine with ISPConfig SSL certificates)

NGINX ports: N/A (non SSL) / 443 (SSL)

The pseudo-SSL is a particular port used by Apache & Varnish to be a back-end for the NGINX SSL. The traffic itself is not SSL but the environment is configured to say to PHP scripts that we are on SSL connection (X-Forwarded-Proto & HTTPS environment variable).

## Craft CMS 4.x and 3.x Install notes

All cookies are included in this script, so admin panel in `YOUR_DOMAIN.com/admin` works.
For load CraftCMS from private folder in web change:

1. If you want use your Craft CMS you possibly need Composer installed to use Plugin Store
2. You must download latest zip or tar.gz of CraftCMS
3. Copy web to web, and rest of files to private
4. Make change in index.php from:```require dirname(__DIR__) . '/bootstrap.php';```. To:```require dirname(__DIR__) . '/private/bootstrap.php';```
5. If you want to install plugins from admin panel with Composer add on end of private/.env:

```
COMPOSER_HOME=/private
COMPOSER_CACHE_DIR=/private/cache
```

You can use my CraftCMS Varnish Cache Plugin for CraftCMS, it will be soon available for 3.x and maybe for 4.x.

### Custom redirection to HTTPS.

It fixes loop of redirection in many systems with .htaccess, redirect from HTTP to HTTPS

You must need modify our redirection to HTTPS:

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

I made many changes from repository <https://github.com/manoaratefy/ispconfig3-varnish>.

There may be other improvements. Just open an issue/request a feature.

## Installation services

Do you need a sysadmin to install this module into your ISPConfig? I'm available for you. [Contact us](https://cooltronic.pl/contact/) or [Or developer](<https://potacki.com/>).

If my work was useful for your business, or you have problems with this script, and you need help contact me.

## Credits for contributors

I've found very useful information in the following URL:

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

You should have received a copy of the GNU General Public License along with OpenETV. If not, see <https://www.gnu.org/licenses/>.

See files COPYING.GPL2 and COPYING.GPL3 for more License information.
