# namespace :deploy do
#   desc "Precompile assets"
#   task :precompile do
#     on roles(:app) do
#       execute  "cd #{release_path}/ && bundle exec rake assets:precompile"
#     end
#   end
# end

namespace :rails do

  namespace :secrets do
    desc "Create Rails secrets file using random secret key base"
    task :create_config do
      on roles(:app, :db) do
        unless test("[ -f #{shared_path}/config/secrets.yml ]")
          set :secret_key_base, SecureRandom.hex(64)
          # get common secrets: we need to find a way to encrypt these really.
          local_secrets = YAML.load_file(File.join(fetch(:repo_tree,"."),"config/secrets.yml"))
          if local_secrets.has_key?("common")
            set :common_secrets, local_secrets["common"]
          end
          file = File.join(File.dirname(__FILE__), "templates", "rails", "secrets.yml.erb")
          buffer = ERB.new(File.read(file), nil, '-').result(binding)
          upload! StringIO.new(buffer), "#{shared_path}/config/secrets.yml"
        end
      end
    end
  end

  # The order of tasks here is: rails:db:create_config [check the config doesn't exist] => rails:db:create => rails:db:grant

  namespace :db do
    set :db_password, (0...20).map{ [('0'..'9'),('A'..'Z'),('a'..'z')].map {|range| range.to_a}.flatten[rand(64)] }.join
    set :db_username, -> {"#{fetch(:application).gsub(/[^A-z]/,"").to_s[0..7]}_#{fetch(:stage).to_s[0..3]}"}
    set :db_name, -> {"#{fetch(:application).gsub(/[^A-z]/,"").to_s[0..53]}_#{fetch(:db_suffix, fetch(:stage).to_s[0..9])}"}

    desc "Create database.yml"
    task :create_config do
      on roles(:app, :db) do
        unless test("[ -f #{File.join(shared_path, "config", "database.yml")} ]")
          file = File.join(File.dirname(__FILE__), "templates", "rails", "database.yml.erb")
          buffer = ERB.new(File.read(file)).result(binding)
          upload! StringIO.new(buffer), "#{shared_path}/config/database.yml"
          invoke! "rails:db:create"
        end
      end
    end

    desc "Create database"
    task :create do
      on roles(:db) do
        prompt_for_login
        db_sql = "CREATE DATABASE IF NOT EXISTS #{fetch(:db_name)};"
        execute "mysql --user=#{fetch(:server_admin_username)} --password=#{fetch(:server_admin_password)} --execute=\"#{db_sql}\""
      end
      invoke! "rails:db:grant"
    end

    desc "Grant db rights"
    task :grant do
      puts "Creating user"
      on roles(:db) do |server|
        prompt_for_login
        [%w{10.% 127.% localhost},[server.hostname]].flatten.each do |ip|
          puts "#{ip}"
          user_sql = "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES on #{fetch(:db_name)}.* TO '#{fetch(:db_username)}'@'#{ip}' IDENTIFIED BY '#{fetch(:db_password)}';"
          execute "mysql --user=#{fetch(:server_admin_username)} --password=#{fetch(:server_admin_password)} --execute=\"#{user_sql}\""
        end
      end
    end


  end
end

after "deploy:check:make_linked_dirs", "rails:secrets:create_config"
after "deploy:check:make_linked_dirs", "rails:db:create_config"
# after "rails:db:create_config", "rails:db:create"
after "deploy:check", "nginx:check_config"
