require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/errorstudio/ownership'
require 'capistrano/errorstudio/prompts'
set :deploy_to, ->{"/var/www/#{fetch(:deploy_domain)}"}
