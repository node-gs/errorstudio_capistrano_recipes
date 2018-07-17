require 'capistrano/errorstudio'
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system', 'public/uploads')
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')
set :upstream_proxy_required, true
set :upstream_proxy_port, -> {fetch(:passenger_port)}
set :upstream_proxy_cache, fetch(:upstream_proxy_cache, true)
require 'capistrano/rails'
require 'capistrano/rails/assets'
# require 'capistrano/rails/migrations'
require 'capistrano/errorstudio/nginx'
require 'capistrano/errorstudio/passenger'
require 'capistrano/errorstudio/rvm'
load File.expand_path("../tasks/rails.rake", __FILE__)
