# ISP Config 3 Varnish Cache Reverse-Proxy with SSL termination Plugin (WP Rocket & Proxy Cache Purge) for WordPress 5.7 to 6.4.x, CraftCMS 3.x, CraftCMS 4.x, 5.0.0.alpha (CDN Cache & Preload) websites

## v4 - 2024-01-02

### Added
- Introduced `urlmode` mode to clear cache by `url` sent in headers, to resolve problems on some hosts

## v3 - 2023-12-04

- Removed obsolete WP Rocket IPs and made some other changes in `default.vcl`
- Updated the compatible versions of WordPress, Craft CMS, WP Rocket, and Proxy Cache Purge, and others in `README.md`
- Improved the structure and content of `README.md`
- Added information about the brotli compression enabled by default in NGINX
- Changed the license from GPLv2 or GPLv3 to GPLv3 only

## v2 - 2022-11-13 [CRITICAL]

- Secured Varnish services to localhost, this fix in README.md is critical
- Changed nginx upload limit to 150M (you can change it), also critical, because default many times breaks many thing in Craft CMS an WP
- Fixing some WordPress problems of deafult url's of admin, wp-json and more, also critical
- Updated WP Rocket IPs
- Added Craft CMS 3.x and 4.x support, and install instructions
- Force Bortli and Gzip compression
- Updated to ISP Config 3.2.8p1
- Forced Browser Caching for static files, js, css etc. ending on mp4 or webm
- Forced HTTP/2
- Big update of README.md 

## v1 - 2021-02-01

- Fix Wordpress IP Detection
- Fix some internal urls for Wordpress CRON and Previews
- Disable some IPs for Unused CSS and Asynchrous CSS for WP Rocket

## Initial

- Initial commit
