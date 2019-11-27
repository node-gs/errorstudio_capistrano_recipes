namespace :deploy do
  desc "Sets the owner to www-data and the group to deployers"
  task :set_ownership do
    on roles([:web, :app]) do
      # execute "sudo chown -R www-data:deployers #{deploy_to}"
      execute "sudo chmod -R 775 #{deploy_to}"
    end
  end
end

before "deploy:cleanup", "deploy:set_ownership"