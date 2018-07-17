namespace :wordpress do
  namespace :assets do
    desc "Download assets for the site"
    task :download do
      on roles(:web) do
        if ENV.has_key?('delete') and ENV['delete']
          if confirm("You're about to download assets from the server and delete your local")
            puts %x(rsync -rlvz --delete #{fetch(:web_server)}:#{shared_path}/#{fetch(:uploads_folder)}/ ./#{fetch(:uploads_folder)}/)
          end
        else
          puts "Downloading assets"
          puts %x(rsync -rlvz #{fetch(:web_server)}:#{shared_path}/#{fetch(:uploads_folder)}/ ./#{fetch(:uploads_folder)}/)
        end
      end
    end

    desc "Upload assets on the server. Optionally pass delete env var to rsync with the --delete switch"
    task :upload do
      on roles(:web) do |server|
        if ENV.has_key?('delete') and ENV['delete']
          if confirm("You're about to upload assets to the server and delete any differences")
            puts %x(rsync -rlvz --delete ./#{fetch(:uploads_folder)}/ #{server.hostname}:#{shared_path}/#{fetch(:uploads_folder)}/)
          end
        else
          puts "Uploading new assets"
          puts %x(rsync -rlvz ./#{fetch(:uploads_folder)}/ #{server.hostname}:#{shared_path}/#{fetch(:uploads_folder)}/)
        end
      end
    end
  end

  namespace :code do
    desc "Download the code from the server."
    task :download do
      on roles(:web) do |server|
        if confirm("You're about to download code from the server")
          puts %x(rsync -rlvz --exclude='wp-config.php' --exclude='config/' --exclude='#{fetch(:uploads_folder)}' #{server.hostname}:#{current_path}/public/ ./public/)
        end
      end
    end
  end

  # The order of tasks here is: wordpress:db:create_config [check the config doesn't exist] => wordpress:db:create => wordpress:db:grant
  namespace :db do
    set :db_password, (0...20).map{ [('0'..'9'),('A'..'Z'),('a'..'z')].map {|range| range.to_a}.flatten[rand(64)] }.join
    set :db_username, -> {"#{fetch(:application).gsub(/[^A-z]/,"").to_s[0..7]}_#{fetch(:stage).to_s[0..3]}"}
    set :db_name, -> {"#{fetch(:application).gsub(/[^A-z]/,"").to_s[0..53]}_#{fetch(:db_suffix, fetch(:stage).to_s[0..9])}"}
    desc 'Generate a config for wordpress / bedrock'
    task :create_config do
      on roles(:app) do
        unless test("[ -f #{shared_path}/.env ]")
          puts "running the create config task."
          [
            "wp_auth_key",
            "wp_secure_auth_key",
            "wp_logged_in_key",
            "wp_nonce_key",
            "wp_auth_salt",
            "wp_secure_auth_salt",
            "wp_logged_in_salt",
            "wp_nonce_salt"
           ].each do |k|
            if fetch(:"#{k}",nil).nil?
              set :"#{k}", SecureRandom.urlsafe_base64(40)
            end
          end
          file = File.join(File.dirname(__FILE__), "templates", "wordpress", "env.erb")
          buffer = ERB.new(File.read(file)).result(binding)
          upload! StringIO.new(buffer), "#{shared_path}/.env"
          invoke "wordpress:db:create"
        end
      end
    end

    desc "Create the database unless it exists"
    task :create do
      on roles(:db) do
          prompt_for_login
          db_sql = "CREATE DATABASE IF NOT EXISTS #{fetch(:db_name)};"
          execute "mysql --user=#{fetch(:server_admin_username)} --password=#{fetch(:server_admin_password)} --execute=\"#{db_sql}\""
      end
      invoke "wordpress:db:grant"
    end

    desc "Grant access to the database"
    task :grant do
      on roles(:db) do
        prompt_for_login
        puts "Creating #{fetch(:wp_db_user)}"
        %w{10.% 127.% localhost}.each do |ip|
          user_sql = "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER on #{fetch(:db_name)}.* TO #{fetch(:db_username)}@'#{ip}' IDENTIFIED BY '#{fetch(:db_password)}';"
          execute "mysql --user=#{fetch(:server_admin_username)} --password=#{fetch(:server_admin_password)} --execute=\"#{user_sql}\""
        end
      end
    end

    desc "Upload a local wordpress db to the server"
    task :upload do
      on roles(:db) do
        if confirm("You're about to overwrite the #{fetch(:wp_db_name)} database on the server")
          prompt_for_login
          get_db_details
          if fetch(:ssl_required,false)
            db = %x(mysqldump --add-drop-table --host='#{fetch(:local_db_server)}' --port='#{fetch(:local_db_port)}' --user='#{fetch(:local_db_username)}' --password='#{fetch(:local_db_password)}' #{fetch(:local_db_name)} | sed 's/#{fetch(:local_domain)}/#{fetch(:deploy_domain)}/g' | sed 's/http:\\/\\/#{fetch(:deploy_domain)}/https:\\/\\/#{fetch(:deploy_domain)}/g' | gzip)
          else
            db = %x(mysqldump --add-drop-table --host='#{fetch(:local_db_server)}' --port='#{fetch(:local_db_port)}' --user='#{fetch(:local_db_username)}' --password='#{fetch(:local_db_password)}' #{fetch(:local_db_name)} | sed 's/#{fetch(:local_domain)}/#{fetch(:deploy_domain)}/g' | gzip)
          end
          upload! StringIO.new(db), "/tmp/#{fetch(:deploy_domain)}.sql.gz"
          puts "Setting up database"
          execute "zcat /tmp/#{fetch(:deploy_domain)}.sql.gz | mysql --user=#{fetch(:server_admin_username)} --password=#{fetch(:server_admin_password)} #{fetch(:db_name)}"
          execute "rm /tmp/#{fetch(:deploy_domain)}.sql.gz"
        end
      end
    end

    desc "Download the live db for local development"
    task :download do
      on roles(:db) do
        if confirm("You're about to overwrite your local database.")
          prompt_for_login
          get_db_details
          if fetch(:ssl_required,false)
            execute "mysqldump --add-drop-table --skip-extended-insert --user='#{fetch(:server_admin_username)}' --password='#{fetch(:server_admin_password)}' #{fetch(:db_name)} | sed 's/#{fetch(:deploy_domain)}/#{fetch(:local_domain)}/g' | sed 's/https:\\/\\/#{fetch(:local_domain)}/http:\\/\\/#{fetch(:local_domain)}/g' | gzip > /tmp/#{fetch(:deploy_domain)}.sql.gz"
          else
            execute "mysqldump --add-drop-table --skip-extended-insert --user='#{fetch(:server_admin_username)}' --password='#{fetch(:server_admin_password)}' #{fetch(:db_name)} | sed 's/#{fetch(:deploy_domain)}/#{fetch(:local_domain)}/g' | gzip > /tmp/#{fetch(:deploy_domain)}.sql.gz"
          end
          download! "/tmp/#{fetch(:deploy_domain)}.sql.gz","#{fetch(:deploy_domain)}.sql.gz"
          %x(gunzip -c #{fetch(:deploy_domain)}.sql.gz | mysql --max_allowed_packet=1000M --host='#{fetch(:local_db_server)}' --port='#{fetch(:local_db_port)}' --user='#{fetch(:local_db_username)}' --password='#{fetch(:local_db_password)}' #{fetch(:local_db_name)})
          execute "rm /tmp/#{fetch(:deploy_domain)}.sql.gz"
        end
      end
    end
  end



  desc "Symlink the .env file with config for the site"
  task :symlink_env => "db:create_config" do
    on roles(:app) do
      execute "ln -s #{shared_path}/.env #{current_path}/public/"
    end
  end
end


def get_db_details
  set :local_domain, fetch(:local_domain,ask("Local WP domain", ""))
  set :local_db_username, fetch(:local_db_username,ask("Local DB username", ""))
  set :local_db_password, fetch(:local_db_password,ask("Local DB password", ""))
  set :local_db_server, fetch(:local_db_server,ask("Local DB server port", "localhost"))
  set :local_db_server_port, fetch(:local_db_server_port,ask("Local DB server port", 3306))
  set :local_db_name, fetch(:local_db_name,ask("Local DB name",fetch(:application)))
end

after "deploy:check:make_linked_dirs", "wordpress:db:create_config"
after "deploy:check", "nginx:check_config"
before "deploy:cleanup", "deploy:set_ownership"
before "deploy:cleanup", "wordpress:symlink_env"
