namespace :composer do
  desc "Set paths for composer and invoke the installation of the composer executable"
  task :set_paths_and_install do
    set :composer_working_dir, ->{ File.join(release_path,"public")}
    set :composer_install_flags, '--no-interaction --optimize-autoloader'
    SSHKit.config.command_map[:composer] = "php #{shared_path.join("composer.phar")}"
    invoke "composer:install_executable"
  end
end

after "deploy:starting", 'composer:set_paths_and_install'
after "deploy:updated", "composer:install"
