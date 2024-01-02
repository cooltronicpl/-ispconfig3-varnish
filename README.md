# Varnish Cache Plugin for WordPress and CraftCMS with NGINX SSL termination for ISPConfig 3

This plugin is developed by [CoolTRONIC.pl sp. z o.o. (LLC)](https://cooltronic.pl) and written by [Pawel Potacki](https://potacki.com). It allows you to use Varnish Cache in ISPConfig 3 for WordPress and CraftCMS sites. It uses Varnish for caching, Apache for the backend, and NGINX for SSL termination. It also supports WP Rocket, Proxy Cache Purge, and CoolTRONIC.pl Varnish Cloudflare & Preload plugins for automatic cache clearing and brotli compression. It respects the .htaccess rules from various WordPress and CraftCMS plugins.

## Table of Contents

- [How plugin works](#how-plugin-works)
- [Compatibility](#compatibility)
- [How to install](#how-to-install)
- [How to fix remote IP detection?](#how-to-fix-remote-ip-detection)
- [Make working WordPress, Craft CMS, and other scripts](#make-working-wordpress-craft-cms-and-other-scripts)
- [Restart services as final step](#restart-services-as-final-step)
- [How to install Craft CMS 4.x and 3.x in ISP Config 3](#how-to-install-craft-cms-4x-and-3x-in-isp-config-3)
- [Notes about plugin ports](#notes-about-plugin-ports)
- [Make redirection to HTTPS](#make-redirection-to-https)
- [For certain domains disable Varnish caching](#for-certain-domains-disable-varnish-caching)
- [Installation services](#installation-services)
- [How to update ISP Config](#how-to-update-isp-config)
- [How to use brotli compression with NGINX](#how-to-use-brotli-compression-with-nginx)
- [Credits and acknowledgements](#credits-and-acknowledgements)
- [License](#license)

## How plugin works

The plugin works with the following scenarios:

- Without SSL: Visitor > Varnish > Apache
- With SSL: Visitor > NGINX 443 > Varnish localhost 7443 > Apache

## Compatibility

The plugin has been tested with the following configuration:

* Debian 11 x64 with kernel from 5.10.0-19 up to 5.10.0-23
* Apache 2.4.56-1
* nginx-common 1.23.2 and 1.18.0-6 (oldstable)
* Varnish 6.5.1-1
* WordPress from 5.7 to 6.4.x
* WP Bakery Builder, Divi Builder and Elementor for WordPress
* ISPConfig from 3.2.8p1 to 3.2.11p1
* WordFence IP Detection (up to 7.11.0)
* WP Rocket from 3.10.6 to 3.15.x with the plugin ["WP Rocket | Alter Varnish's args"](https://docs.wp-rocket.me/article/493-using-varnish-with-wp-rocket)" to change Varnish config to HTTPS on SSL sites
* [Proxy Cache Purge](https://wordpress.org/plugins/varnish-http-purge/) for WordPress 6.4.1
* CraftCMS 3.x with PHP 7.2 (with Composer patch)
* CraftCMS 4.x with PHP 8.0 (with Composer patch)
* PHP from 5.6 to 8.3 from Sury repository
* [CDN Cache & Preload](https://github.com/cooltronicpl/varnishcache/) for CraftCMS 3.x and 4.x with Cloudflare support and sitemap.xml preload
* Cloudflare support on Varnish Powered Servers on WP Rocket (WordPress) and CDN Cache & Preload (Craft CMS 4.x)

CDN Cache & Preload for Craft CMS 3.x and 4.x is available [here at Craft CMS Store](https://plugins.craftcms.com/varnishcache/). You can also find some notes on how to install [CraftCMS in ISPConfig 3](https://github.com/cooltronicpl/-ispconfig3-varnish#craft-cms-4x-and-3x-install-notes-for-isp-config-3) and use it with Plugin Installer and Composer. The plugin also enables GZIP and BROTLI compression on NGINX for all SSL hosts. It works with WP Rocket Varnish add-on and Proxy Cache Purge for cache purging.

The plugin should work fine with Ubuntu and Debian, and may require some adjustments for CentOS & RHEL-based distributions.

## How to install

Install the dependencies:

```
    apt-get install debian-archive-keyring curl gnupg apt-transport-https gnupg2 ca-certificates lsb-release git -y
```

### Install Varnish repo (optional, for older systems)

```
    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish64/script.deb.sh | sudo bash
```

### Install NGINX repo (optional, for older systems)

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

### To install the plugin, you need to follow these steps:

1. Clone the repo from GitHub:

```
    git clone https://github.com/cooltronicpl/-ispconfig3-varnish.git
```

2. Change the Apache2 ports from 80 and 443 to 680 and 6443:

```
    sed -i 's/Listen 80/Listen 680/g' /etc/apache2/ports.conf
    sed -i 's/Listen 443/Listen 6443/g' /etc/apache2/ports.conf
```

Note: If you have used the old script by [manoaratefy](https://github.com/manoaratefy/ispconfig3-varnish), you may need to change the port from 6080 to 680 instead:

```
sed -i 's/Listen 6080/Listen 680/g' /etc/apache2/ports.conf
```

3. Change the Varnish ports from 6081 and 6082 to 80 and 7443:

```
    cp /lib/systemd/system/varnish.service /tmp/varnish.service.old
    perl -pe 's/(\s*)ExecStart(\s*)=(\s*)\/usr\/sbin\/varnishd(.*)/ExecStart=\/usr\/sbin\/varnishd -a :80 -a localhost:7443 -f \/etc\/varnish\/default.vcl -s malloc,512m -p http_resp_hdr_len=42000 -p feature=+http2 \/ /g' /tmp/varnish.service.old | tee /lib/systemd/system/varnish.service > /dev/null
    systemctl daemon-reload
```

Note: You can check the contents of the /lib/systemd/system/varnish.service file to make sure it looks like this:

```
[Unit]
Description=Varnish Cache, a high-performance HTTP accelerator
Documentation=https://www.varnish-cache.org/docs/ man:varnishd

[Service]
Type=simple

# Maximum number of open files (for ulimit -n)
LimitNOFILE=131072

# Locked shared memory - should suffice to lock the shared memory log
# (varnishd -l argument)
# Default log size is 80MB vsl + 1M vsm + header -> 82MB
# unit is bytes
LimitMEMLOCK=85983232
ExecStart=/usr/sbin/varnishd -a :80 -a localhost:7443 -a localhost:6081 -s malloc,512m -p http_resp_hdr_len=42000 -p feature=+http2 -j unix,user=vcache -T localhost:6082 -f /etc/varnish/default.vcl
ExecReload=/usr/share/varnish/varnishreload
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
```

4. Move all the files from the repo to their respective locations:

```
    cd -ispconfig3-varnish
    cp -R etc/* /etc/
    cp -R usr/* /usr/
```

5. Note: You may add your server’s IPv4 and IPv6 addresses (if it has them) in the `/etc/varnish/default.vcl` file in the acl purge section. This may help to fix some cache clearing issues with external plugins like WP Rocket.

6. Remove the default NGINX configuration file and create the necessary folders for the sites:

```
    rm /etc/nginx/conf.d/default.conf
    mkdir /etc/nginx/sites-available
    mkdir /etc/nginx/sites-enabled
```

7. Enable the plugin by creating a symbolic link:

```
    ln -s /usr/local/ispconfig/server/plugins-available/varnish_plugin.inc.php /usr/local/ispconfig/server/plugins-enabled/varnish_plugin.inc.php
```

## How to fix remote IP detection?

To fix the remote IP detection issue, you need to enable the remoteip module in Apache2 and modify the ispconfig.conf file:

```
    a2enmod remoteip
    cp /etc/apache2/sites-available/ispconfig.conf /etc/apache2/sites-available/ispconfig.conf.old
    perl -pe 's/(\s*)LogFormat(\s+)"(.*)%h(.*)"(.*)combined_ispconfig/LogFormat "%v %a %l %u %t \\"%r\\" %>s %O \\"%{Referer}i\\" \\"%{User-Agent}i\\"" combined_ispconfig/g' /etc/apache2/sites-available/ispconfig.conf.old | tee /etc/apache2/sites-available/ispconfig.conf > /dev/null
```

This will replace the %h variable (which shows the IP address of the proxy) with the %a variable (which shows the IP address of the client) in the log format.

## Make working WordPress, Craft CMS, and other scripts

To make sure that the scripts can detect the HTTPS environment and the correct server port, you need to add the following lines to the /etc/apache2/apache2.conf file:

```
echo "<IfModule setenvif_module>" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" X_SERVER_PORT=443" >> /etc/apache2/apache2.conf
echo "    SetEnvIf X-Forwarded-Proto "^https$" X_REQUEST_SCHEME=https" >> /etc/apache2/apache2.conf
echo "</IfModule>" >> /etc/apache2/apache2.conf
```

This will set the HTTPS, X_SERVER_PORT, and X_REQUEST_SCHEME environment variables based on the X-Forwarded-Proto header sent by NGINX.

## Restart services as final step

After you have applied the changes, you need to modify the redirection to HTTPS in the .htaccess file of your site (see the example in the Notes section). Then, you need to rebuild all the vHosts **before restarting the services** (otherwise, Apache may not start and you will not be able to access the ISPConfig control panel). To rebuild the vHosts, go to ``ISPConfig`` > ``Tools`` > ``Sync Tools`` > ``Resync`` > Check ``“Websites”`` > ``Start``. After that, you can restart the services:

```
    systemctl restart apache2
    systemctl restart varnish
    systemctl restart nginx
```

## How to install Craft CMS 4.x and 3.x in ISP Config 3

All cookies are included in this script, so the admin panel in YOUR_DOMAIN.com/admin works. To load CraftCMS from a private folder when not the parent of the web, you need to change:

If you want to use Craft CMS, you need to follow these steps:

1. Install Composer if you want to use the Plugin Store.
2. Download the latest zip or tar.gz file of Craft CMS from its website.
3. Extract the web folder to HOST_ROOT/web, and the rest of the files to HOST_ROOT/private.
4. Edit the HOST_ROOT/web/index.php file and change this line:

```require dirname(__DIR__) . '/bootstrap.php';```.

To this line:

```require dirname(__DIR__) . '/private/bootstrap.php';```

5. Create a database and a user for your site.
6. Follow the installation instructions for your chosen version of Craft CMS: [4](https://craftcms.com/docs/4.x/installation.html) or [3](https://craftcms.com/docs/3.x/installation.html).
7. If you want to install plugins from the admin panel with Composer, add these lines to the end of the HOST_ROOT/private/.env file:

```
COMPOSER_HOME=./private
COMPOSER_CACHE_DIR=./private/cache
```

You can now use the [CoolTRONIC.pl CDN Cache & Preload for CraftCMS](https://plugins.craftcms.com/varnishcache), which is compatible with Craft CMS 3.x and 4.x. It also supports Cloudflare and sitemap.xml preload.

## Notes about plugin ports

Apache ports: 680 (non SSL) / 6433 (dummy SSL)

Varnish ports: 80 (non SSL) / 680 (pseudo SSL, it works fine with ISPConfig SSL certificates)

NGINX ports: N/A (non SSL) / 443 (SSL)

The pseudo-SSL is a special port used by Apache and Varnish to be a backend for the NGINX SSL. The traffic itself is not SSL, but the environment is configured to tell the PHP scripts that we are on an SSL connection (X-Forwarded-Proto and HTTPS environment variables).

## Make redirection to HTTPS

To avoid the loop of redirection from HTTP to HTTPS, you need to modify your existing redirection to HTTPS in the .htaccess file of your site. For example, change this:

```
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteCond %{HTTPS} off 
RewriteRule (.*) https://ssl-site.com/$1 [R=301,L]
</IfModule>
### END HTTPS
```

To this:

```
<IfModule mod_rewrite.c>
RewriteEngine On
# Use the X-Forwarded-Proto header to check the protocol
RewriteCond %{HTTP:X-Forwarded-Proto} !https [NC]
RewriteRule (.*) https://ssl-site.com/$1 [R=301,L]
</IfModule>
### END HTTPS
```

This will use the X-Forwarded-Proto header to check the protocol and redirect to HTTPS.

## For certain domains disable Varnish caching

You can add exceptions for the domains or scripts that you want to bypass Varnish caching. For example, you can add this to the /etc/varnish/default.vcl file:

```
if (req.http.host=="domain-to-disable.com"){
   return(pass);
}
```

This will tell Varnish to pass the request to the backend without caching it.

## Installation services

If you need a sysadmin to install this plugin on your ISPConfig server, we are happy to assist you. You can [contact us](https://cooltronic.pl/contact/) or developer [Pawel Potacki](https://potacki.com/) for more information. We appreciate your feedback and support for our work. If you encounter any problems with this plugin, or you need any help, please let us know.


## How to update ISP Config

To update ISP Config (tested up to 3.2.11p1) and keep the plugin working, you need to follow these steps:

1. Run the ispconfig_update.sh script and choose to keep the vhost files:

```
ispconfig_update.sh
```
2. Remove the NGINX configuration files that may cause conflicts:

```
rm /etc/nginx/sites-enabled/000-apps.vhost
rm /etc/nginx/sites-enabled/999-acme.vhost
```

3. Comment out or remove the line that listens to port 443 in the `/etc/apache2/ports.conf` file. You can use nano or vim to edit the file. For example:

```#Listen 443```

There should not be any active Listen 443 declaration in the ports.conf file.

4. Remove the backup files of the .vhosts files that end with .master. They should be in the `/usr/local/ispconfig/server/conf-custom` folder. You can also use the files from the repo if the backup files are not there when you answer `yes` to rename files.

5. Restart all the services (apache2, Varnish, NGINX):

```
    systemctl restart apache2
    systemctl restart varnish
    systemctl restart nginx
```

6. Resync the vhosts in `ISPConfig`: Go to `Tools` > `Sync Tools` > `Resync` > Check `“Websites”` > `Start`.
7. Note (Optional): Repeat step 5 to restart the web services after the update. Your ISPConfig server should be working fine after the update.
 
## How to use brotli compression with NGINX

Brotli is a compression algorithm that can improve the speed and performance of your web pages. You can either install the brotli modules from the package manager or compile them from the source code. You can find more information about how to compile the brotli modules from the [source code](https://github.com/google/ngx_brotli) and [here instruction for Debian](https://www.howtoforge.com/how-to-add-brotli-support-to-nginx-on-debian-10/).

To load a compiled brotli modules from source, you may need to add these lines at the top of the `/etc/nginx/nginx.conf` file:

```
load_module modules/ngx_http_brotli_filter_module.so;
load_module modules/ngx_http_brotli_static_module.so;

events {
	worker_connections 768;
	# multi_accept on;
}
```

You can adjust the brotli_comp_level and the brotli_types according to your needs. This is lines which enables brotli from in our example:

```
# enable brotli
brotli on;
brotli_comp_level 6;
brotli_types text/xml image/svg+xml application/x-font-ttf image/vnd.microsoft.icon application/x-font-opentype application/json font/eot application/vnd.ms-fontobject application/javascript font/otf application/xml application/xhtml+xml text/javascript  application/x-javascript text/plain application/x-font-truetype application/xml+rss image/x-icon font/opentype text/css image/x-win-bitmap;
```

If you cannot install or compile the brotli modules, you can comment out or remove the lines that load and configure brotli in the /etc/nginx/nginx.conf file. This will disable brotli compression and use the default gzip compression instead.


## Credits and acknowledgements

We would like to thank the following sources for their valuable knowledge and inspiration that helped us develop this plugin:

- [@manoaratefy for his script to set up Varnish Cache in ISPConfig.](https://github.com/manoaratefy/ispconfig3-varnish)
- [@Rackster for his script to set up NGINX as a reverse proxy for SSL termination in ISPConfig.](https://github.com/Rackster/ispconfig3-nginx-reverse-proxy)
- [How to Forge for their tutorials and guides on how to use ISPConfig and other web hosting tools.](https://www.howtoforge.com/community/)

## License

ISPConfig 3 Varnish Plugin

ISPConfig Varnish NGINX Reverse-Proxy Plugin 

Copyright (C) 2024 [CoolTRONIC.pl sp. z o.o. (LLC)](https://cooltronic.pl) by [Pawel Potacki](https://potacki.com).

CoolTRONIC.pl sp. z o.o., hereby holds all copyright interest in the program “ISPConfig 3 Varnish Cache Plugin” written by Pawel Potacki.

ISPConfig 3 Varnish Cache Plugin is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

ISPConfig 3 Varnish Cache Plugin is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with ISPConfig 3 Varnish Cache Plugin. If not, see <https://www.gnu.org/licenses/>.

See files COPYING.GPL3 for more License information.
