set :nginx_configuration, fetch(:nginx_configuration, {})
set :base_domain, ->{fetch(:base_domain,ask(:base_domain,nil))}
set :prelaunch_domain, ->{fetch(:prelaunch_domain,ask(:prelaunch_domain,nil))}
set :site_domains, ->{fetch(:site_domains,ask(:site_domains,nil))}
set :basic_auth_required, fetch(:basic_auth_required, false)
set :ssl_required, fetch(:ssl_required, false)
set :deploy_domain, ->{fetch(:deploy_domain,ask(:deploy_domain,nil))}

namespace :nginx do
  desc "Check the config exists, and generate if it doesn't"
  task :check_config do
    set :nginx_sites_available, "/etc/nginx/sites-available/#{fetch(:deploy_domain)}"
    set :nginx_sites_enabled, "/etc/nginx/sites-enabled/#{fetch(:deploy_domain)}"
    on roles(:web) do
      unless test("[ -f #{"/etc/nginx/sites-enabled/#{fetch(:deploy_domain)}"} ]")
        invoke "nginx:generate_config"
      end
    end
  end

  desc "Generate an Nginx config from a template, with a few prerequisite tasks"
  task :generate_config => [
         :generate_ssl,
         :generate_cloudflare_real_ips,
         :generate_php,
         :generate_upstream_proxy,
         :generate_redirects,
         :add_basic_auth,
         :generate_rewrites,
         :generate_custom_rules,
         :generate_custom_aliases,
         :generate_cors,
         :generate_path_redirects,
         :generate_proxy_cache
       ] do
    file = File.join(File.dirname(__FILE__), "templates","nginx", "nginx_vhost.conf.erb")

    buffer = ERB.new(File.read(file)).result(binding)
    on roles(:web) do
      upload! StringIO.new(buffer), "#{shared_path}/#{fetch(:deploy_domain)}"
      execute "mv #{shared_path}/#{fetch(:deploy_domain)} #{"/etc/nginx/sites-available/#{fetch(:deploy_domain)}"}"
      execute "ln -nfs #{"/etc/nginx/sites-available/#{fetch(:deploy_domain)}"} #{"/etc/nginx/sites-enabled/#{fetch(:deploy_domain)}"}"
      invoke 'nginx:reload'
    end
  end

  desc "Add basic auth to the nginx config"
  task :add_basic_auth do
    #set up the basic auth if the vars are defined
    if fetch(:basic_auth_required, false)
      set :basic_auth_realm, "Your username and password are required"
      # set :basic_auth_username, ->{fetch(:basic_auth_username,ask(:basic_auth_username,nil))}
      # set :basic_auth_password, ->{fetch(:basic_auth_password,ask(:basic_auth_password,nil))}
      on roles :web do
        encrypted_password = `openssl passwd -apr1 #{fetch(:basic_auth_password)}`
        execute :echo, "'#{fetch(:basic_auth_username)}:#{encrypted_password.chomp}'", "> #{shared_path}/.htpasswd"
      end
      file = File.join(File.dirname(__FILE__), "templates","nginx", "basic_auth.erb")
      basic_auth = {basic_auth: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration).merge(basic_auth)
      invoke "deploy:set_ownership"
    end
  end

  desc "Reload Nginx"
  task :reload do
    on roles(:web) do
      sudo "/usr/sbin/invoke-rc.d nginx reload"
    end
  end

  desc "Generate CORS headers for nginx"
  task :generate_cors do
    if fetch(:include_nginx_cors, false)
      file = File.join(File.dirname(__FILE__), "templates","nginx", "cors.erb")
      # generate a hash which is the content of the nginx redirects, with a key
      cors = {cors: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration).merge(cors)
    end
  end

  desc "Generate custom rules from a hash of rules. NB this is inside the main server block"
  task :generate_custom_rules do
    file = File.join(File.dirname(__FILE__), "templates","nginx", "custom_rules.erb")
    # generate a hash which is the content of the nginx redirects, with a key
    rules = {custom_rules: ERB.new(File.read(file)).result(binding)}
    set :nginx_configuration, fetch(:nginx_configuration).merge(rules)
  end

  desc "Generate custom aliases from a hash. NB this is inside the main server block"
  task :generate_custom_aliases do
      file = File.join(File.dirname(__FILE__), "templates","nginx", "custom_aliases.erb")
      # generate a hash which is the content of the nginx redirects, with a key
      aliases = {custom_aliases: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration).merge(aliases)
  end

  desc "Generate 301 path redirects from a hash. NB this is inside the main server block"
  task :generate_path_redirects do
    file = File.join(File.dirname(__FILE__), "templates","nginx", "path_redirects.erb")
    # generate a hash which is the content of the nginx redirects, with a key
    aliases = {path_redirects: ERB.new(File.read(file)).result(binding)}
    set :nginx_configuration, fetch(:nginx_configuration).merge(aliases)
  end

  desc "Generate PHP-FPM proxy and headers"
  task :generate_php => :generate_ssl do
    if fetch(:php_required, false)
      file = File.join(File.dirname(__FILE__), "templates","nginx", "php.erb")
      php = {php: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration,{}).merge(php)
    end
  end

  desc "Generate upstream proxy and headers"
  task :generate_upstream_proxy => :generate_ssl do
    if fetch(:upstream_proxy_required, false)
      file = File.join(File.dirname(__FILE__), "templates","nginx", "upstream_proxy.erb")
      upstream = {upstream: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration,{}).merge(upstream)
    end
  end

  desc "Generate proxy cache settings"
  task :generate_proxy_cache => :generate_upstream_proxy do
    if fetch(:upstream_proxy_cache, false)
      set :cache_zone, "#{fetch(:application)}_#{fetch(:stage)}"
      file = File.join(File.dirname(__FILE__), "templates","nginx", "proxy_cache_path.erb")
      cache_path = {proxy_cache_path: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration,{}).merge(cache_path)
      file = File.join(File.dirname(__FILE__), "templates","nginx", "location_proxy_cache.erb")
      location_proxy_cache = {location_proxy_cache: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration,{}).merge(location_proxy_cache)
    end
  end

  desc "Generate redirects in separate server blocks"
  task :generate_redirects => :generate_ssl do
    file = File.join(File.dirname(__FILE__), "templates","nginx", "redirects.erb")
    # generate a hash which is the content of the nginx redirects, with a key
    redirects = {domain_redirects: ERB.new(File.read(file)).result(binding)}
    set :nginx_configuration, fetch(:nginx_configuration,{}).merge(redirects)
  end

  desc "Generate rewrites"
  task :generate_rewrites do
    file = File.join(File.dirname(__FILE__), "templates","nginx", "rewrites.erb")
    rewrites = {url_rewrites: ERB.new(File.read(file)).result(binding)}
    set :nginx_configuration, fetch(:nginx_configuration,{}).merge(rewrites)
  end

  desc "Generate SSL settings from files in a specified location"
  task :generate_ssl do
    if fetch(:ssl_required, false)
      set :ip_address, ->{fetch(:ip_address, ask(:ip_address,nil))}
      set :ssl_cert_path, File.join(fetch(:ssl_dir), fetch(:ssl_cert))
      set :ssl_key_path, File.join(fetch(:ssl_dir), fetch(:ssl_key))
      set :ssl_dh_path, File.join(fetch(:ssl_dir), fetch(:ssl_dh))

      unless File.exists?(fetch(:ssl_cert_path)) && File.exists?(fetch(:ssl_key_path)) & File.exists?(fetch(:ssl_dh_path))
        puts "You need to put your SSL GPG-encrypted key, DH params and cert in the locations you've specified"
        exit
      end

      set :gpg_phrase, ask("GPG passphrase for SSL key and DH:",nil)
      set :ssl_path, "/etc/nginx/ssl"
      key = `echo #{fetch(:gpg_phrase)} | gpg -d -q --batch --passphrase-fd 0 --no-mdc-warning #{fetch(:ssl_key_path)}`
      dh = `echo #{fetch(:gpg_phrase)} | gpg -d -q --batch --passphrase-fd 0 --no-mdc-warning #{fetch(:ssl_dh_path)}`
      set :certificate_sha256, `openssl x509 -in #{fetch(:ssl_cert_path)} -pubkey -noout | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -binary | openssl enc -base64`
      if $?.success?
        on roles(:web) do
          upload! fetch(:ssl_cert_path), "#{fetch(:ssl_path)}/#{fetch(:deploy_domain)}.crt"
          upload! StringIO.new(key), "#{fetch(:ssl_path)}/#{fetch(:deploy_domain)}.key"
          upload! StringIO.new(dh), "#{fetch(:ssl_path)}/#{fetch(:deploy_domain)}.pem"
        end
      else
        puts "Incorrect GPG passphrase"
        exit
      end

      file = File.join(File.dirname(__FILE__), "templates","nginx", "ssl_settings.erb")
      ssl_settings = {ssl_settings: ERB.new(File.read(file)).result(binding)}
      set :nginx_configuration, fetch(:nginx_configuration,{}).merge(ssl_settings)
    end
  end

  desc "Get a list of Cloudflare IPs, and set real ip from the header"
  task :generate_cloudflare_real_ips do
    ips = open("https://www.cloudflare.com/ips-v4/").read
    set :cloudflare_real_ips, ips.gsub(/\<.*>/,"").split("\n")
    file = File.join(File.dirname(__FILE__), "templates","nginx", "cloudflare_real_ips.erb")
    cloudflare_ips = {cloudflare_real_ips: ERB.new(File.read(file)).result(binding)}
    set :nginx_configuration, fetch(:nginx_configuration,{}).merge(cloudflare_ips)
  end
end

after "deploy:check", "nginx:check_config"
after "nginx:generate_config", "nginx:reload"
