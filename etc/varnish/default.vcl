
#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide for a comprehensive documentation
# at https://www.varnish-cache.org/docs/.

# Marker to tell the VCL compiler that this VCL has been written with the
# 4.0 or 4.1 syntax.
vcl 4.1;

import std;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "127.0.0.1";
    .port = "680";
}

backend secure {
    .host = "127.0.0.1";
    .port = "680";
}

# Add hostnames, IP addresses and subnets that are allowed to purge content
acl purge {
    "localhost";
    "127.0.0.1";
    "::1";
    // here add your server IPv4 adress like "11.22.33.44" and IPv6 (if your server has)
}

sub vcl_recv {
    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
#req.http.x-forwarded-for = client.ip

    if (std.port(server.ip) == 7443) {
        set req.backend_hint = secure;
    } else {
        set req.backend_hint = default;
    }
# DISABLE SOME HOST DOMAIN, which you don't wan't to cache
  if (req.http.host=="some-domain.com"){
   return(pass);
  }

  // disable urls and fixing many problems of WordPress and Craft CMS with default admin dashboard url
  if (
   req.url ~ "^/preview=" ||
   req.url ~ "wp-json" ||
   req.url ~ "staging/wp-json" ||
   req.url ~ "^/wp-json" ||
   req.url ~ "^/index.php?p=admin" ||
   req.url ~ "^/admin" ||
   req.url ~ "^/staging/wp-json" ||
   req.url ~ "(wp-admin|post\.php|edit\.php|wp-login|wp-json)") {
     return(pass);
  }
	# Purge logic to remove objects from the cache. 
    # Tailored to the CDN Cache & Preload for Craft CMS plugin 
	# See https://cooltronic.eu/plugin/cdn-cache-preload/
	# See https://cooltronic.eu/plugin/cdn-cache-preload/method-urlmode/
	# and WP Rocket, Proxy Cache Purge WordPress plugin
    # See https://wordpress.org/plugins/varnish-http-purge/
    if(req.method == "PURGE") {
        if(!client.ip ~ purge) {
            return(synth(405,"PURGE not allowed for this IP address"));
        }
        if (req.http.X-Purge-Method == "regex") {
            ban("obj.http.x-url ~ " + req.url + " && obj.http.x-host == " + req.http.host);
            return(synth(200, "Purged"));
        }
		if (req.http.X-Purge-Method == "urlmode") {
            ban("obj.http.x-url ~ " + req.http.url + " && obj.http.x-host == " + req.http.host);
            return(synth(200, "Purged"));
        }
        ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
        return(synth(200, "Purged"));
    }

    # Remove port number from host header
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # Sorts query string parameters alphabetically for cache normalization purposes
    set req.url = std.querysort(req.url);

    # Remove the proxy header to mitigate the httpoxy vulnerability
    # See https://httpoxy.org/
    unset req.http.proxy;


    # Only handle relevant HTTP request methods
    if (
        req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "PATCH" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE"
    ) {
        return (pipe);
    }

    # Remove tracking query string parameters used by analytics tools
    if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=") {
        set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
        set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
    }

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        set req.http.X-Cacheable = "NO:REQUEST-METHOD";
        return(pass);
    }

    # Mark static files with the X-Static-File header, and remove any cookies
    # X-Static-File is also used in vcl_backend_response to identify static files
    if (req.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        set req.http.X-Static-File = "true";
        unset req.http.Cookie;
        return(hash);
    }

    # No caching of special URLs, logged in users and some plugins of WordPress and Craft CMS 3 or 4 cookies
    if (
        req.http.Cookie ~ "wordpress_(?!test_)[a-zA-Z0-9_]+|wp-postpass|comment_author_[a-zA-Z0-9_]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+|wordpress_logged_in_|comment_author|PHPSESSID" ||
        req.http.Cookie ~ "CRAFT_CSRF_TOKEN" ||
		req.http.Cookie ~ "[a-zA-Z0-9_]+|_identity" ||
        req.http.Cookie ~ "[a-zA-Z0-9_]+|_username" ||
		req.http.Cookie ~ "__stripe_mid" ||
		req.http.Cookie ~ "CraftSessionId" ||
		req.http.Authorization ||
        req.url ~ "add_to_cart" ||
        req.url ~ "edd_action" ||
        req.url ~ "nocache" ||
        req.url ~ "^/wp-json" ||
        req.url ~ "^/addons" ||
        req.url ~ "^/bb-admin" ||
        req.url ~ "^/bb-login.php" ||
        req.url ~ "^/bb-reset-password.php" ||
        req.url ~ "^/cart" ||
        req.url ~ "^/checkout" ||
        req.url ~ "^/control.php" ||
        req.url ~ "^/login" ||
        req.url ~ "^/logout" ||
        req.url ~ "^/lost-password" ||
        req.url ~ "^/my-account" ||
        req.url ~ "^/product" ||
        req.url ~ "^/register" ||
        req.url ~ "^/register.php" ||
        req.url ~ "^/server-status" ||
        req.url ~ "^/signin" ||
        req.url ~ "^/signup" ||
        req.url ~ "^/stats" ||
        req.url ~ "^/wc-api" ||
        req.url ~ "^/wp-admin" ||
        req.url ~ "^/wp-comments-post.php" ||
        req.url ~ "^/wp-cron.php" ||
        req.url ~ "^/wp-login.php" ||
        req.url ~ "^/wp-activate.php" ||
        req.url ~ "^/wp-mail.php" ||
        req.url ~ "^/wp-login.php" ||
        req.url ~ "^\?add-to-cart=" ||
        req.url ~ "^\?_locale=" ||
        req.url ~ "^\?wc-api=" ||
        req.url ~ "^\?preview_id" ||
		req.url ~ "^\?post" ||
        req.url ~ "^/preview=" ||
        req.url ~ "^/\.well-known/acme-challenge/"
    ) {
	     set req.http.X-Cacheable = "NO:Logged in/Got Sessions";
	     if(req.http.X-Requested-With == "XMLHttpRequest") {
		     set req.http.X-Cacheable = "NO:Ajax";
	     }
        return(pass);
    }

    # Remove any cookies left
    unset req.http.Cookie;
    return(hash);
}

sub vcl_hash {
    if(req.http.X-Forwarded-Proto) {
        # Create cache variations depending on the request protocol       
        hash_data(req.http.X-Forwarded-Proto);
    }
}

sub vcl_backend_response {
    # Inject URL & Host header into the object for asynchronous banning purposes
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    # If we dont get a Cache-Control header from the backend
    # we default to 1h cache for all objects
    if (!beresp.http.Cache-Control) {
        set beresp.ttl = 1h;
        set beresp.http.X-Cacheable = "YES:Forced";
    }

    # If the file is marked as static we cache it for 1 day
    if (bereq.http.X-Static-File == "true") {
        unset beresp.http.Set-Cookie;
        set beresp.http.X-Cacheable = "YES:Forced";
        set beresp.ttl = 31d;
    }

	# Remove the Set-Cookie header when a specific Wordfence cookie is set
    if (beresp.http.Set-Cookie ~ "wfvt_|wordfence_verifiedHuman") {
	    unset beresp.http.Set-Cookie;
	 }
	
    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Cacheable = "NO:Got Cookies";
    } elseif(beresp.http.Cache-Control ~ "private") {
        set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    }	
}

sub vcl_deliver {
    # Debug header
    if(req.http.X-Cacheable) {
        set resp.http.X-Cacheable = req.http.X-Cacheable;    
    } elseif(obj.uncacheable) {
        if(!resp.http.X-Cacheable) {
            set resp.http.X-Cacheable = "NO:UNCACHEABLE";        
        }
    } elseif(!resp.http.X-Cacheable) {
        set resp.http.X-Cacheable = "YES";
    }
    
    # Cleanup of headers
    unset resp.http.x-url;
    unset resp.http.x-host;    
}

sub vcl_purge {
    set req.method = "GET";
    set req.http.X-Purger = "Purged";

    #return (synth(200, "Purged"));
    return (restart);
}



