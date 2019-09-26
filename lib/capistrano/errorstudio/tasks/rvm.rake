

namespace :rvm1 do
  namespace :install do
    desc 'Install bundler'
    task :bundler do
      on roles(fetch(:rvm1_roles, :all)) do
        within release_path do
          version = fetch(:bundler_version).nil? ? "" : "-v #{fetch(:bundler_version)}"
          execute :rvm, fetch(:rvm1_ruby_version), 'do', "gem install bundler #{version} --no-document"
        end
      end
    end

    desc "install RVM, but only after checking it's not already installed"
    task :if_necessary do
      on roles(fetch(:rvm1_roles, :all)) do
        if test("[ -f /usr/local/rvm/bin/rvm ]")
          puts "RVM already exists - no need to install"
        else
          invoke 'rvm1:install:rvm'
        end
      end
    end
  end


  desc "Add / update the RVM key from the keyserver unless it already exists"
  task :update_rvm_key do
    on roles(fetch(:rvm1_roles, :all)) do
      unless execute :gpg, "--list-keys | grep D39DC0E3" , raise_on_non_zero_exit: false
        execute :gpg, " --keyserver hkp://keyserver.ubuntu.com --recv-keys D39DC0E3"
      end
    end
  end

  desc "Set the owner of the rvm1script directory to deploy, not www-data"
  task :set_ownership do
    on roles(fetch(:rvm1_roles, :all)) do
      execute "sudo chown -R `whoami | xargs echo -n`:deployers #{fetch(:rvm1_auto_script_path)}"
    end
  end

end

before "rvm1:install:rvm", "rvm1:update_rvm_key"
before 'deploy', 'rvm1:install:if_necessary'  # install/update RVM
before 'deploy', 'rvm1:install:ruby'  # install/update Ruby
after 'rvm1:install:ruby', 'rvm1:install:bundler'
after "deploy:set_ownership", "rvm1:set_ownership"
