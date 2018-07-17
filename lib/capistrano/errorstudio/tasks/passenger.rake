namespace :passenger do
  # This task with bounce the standalone passenger server.
  # The rails_env and passenger_port are specified in the deploy environment files, ex: "config/deploy/staging.rb"
  desc "Restart Passenger server"
  task :restart do
    on roles(:web) do
      execute "sudo invoke-rc.d #{fetch(:application)}_#{fetch(:rails_env)}_passenger restart"
    end
  end

  desc "Generate the init script for passenger"
  task :generate_init_script do
    # on roles(:web) do
    #   memory_available_kb = `cat /proc/meminfo | grep MemTotal | awk '{print $2}'`.to_i
    #   thread_use_kb = 175000
    #   set :default_pool_size, ((memory_available_kb * 0.75) / thread_use_kb).to_i
    # end

    # create the shell script that upstart will exec
    file   = File.join(File.dirname(__FILE__), "templates", "passenger", "passenger_init.erb")
    buffer = ERB.new(File.read(file)).result(binding)
    filename = "#{fetch(:application)}_#{fetch(:rails_env)}_passenger"
    on roles(:web) do
      unless test("[ -f /etc/init.d/#{filename} ]")
        upload! StringIO.new(buffer), "/tmp/#{filename}"
        execute "sudo mv /tmp/#{filename} /etc/init.d/#{filename}"
        execute "sudo chmod +x /etc/init.d/#{filename}"
        execute "sudo update-rc.d #{filename} defaults"
      end
    end
  end

  def passenger_path
    if fetch(:use_system_passenger, false)

      on roles(fetch(:rvm1_roles, :all)) do
        within release_path do
          set :ruby_version, capture(:rvm, "current")
        end
      end
      
      "RACK_ENV=#{fetch(:rails_env)} && /usr/local/rvm/gems/#{fetch(:ruby_version)}/wrappers/ruby /usr/bin/passenger"
    else
      "RACK_ENV=#{fetch(:rails_env)} && #{fetch(:rvm1_auto_script_path)}/rvm-auto.sh . bundle exec passenger"
    end

  end

  def stop_passenger_command
    return <<-CMD
      if [ -f #{current_path}/tmp/pids/passenger.#{fetch(:passenger_port)}.pid ];
      then
        cd #{current_path} && (#{passenger_path} stop --pid-file #{current_path}/tmp/pids/passenger.#{fetch(:passenger_port)}.pid)
      fi
    CMD
  end

  def start_passenger_command
    default_pool_size = 6
    return <<-CMD
    # VERSION #{fetch(:rvm1_alias_name)}
      rm -f #{current_path}/tmp/pids/passenger.#{fetch(:passenger_port)}.pid;
      cd #{current_path} && (#{passenger_path} start --max-pool-size=#{fetch(:passenger_max_pool_size,default_pool_size)} --min-instances=#{fetch(:passenger_min_instances,default_pool_size)} -e #{fetch(:rails_env)} -p #{fetch(:passenger_port)} -d)
    CMD
  end

  def restart_passenger_command
    return <<-CMD
      #{stop_passenger_command}
      #{start_passenger_command}
    CMD
  end
end

after "deploy:published", "passenger:generate_init_script"
after "deploy:finished", "passenger:restart"
