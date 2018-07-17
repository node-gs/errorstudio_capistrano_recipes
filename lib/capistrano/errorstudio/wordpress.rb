require 'capistrano/errorstudio'
require 'securerandom'
require 'capistrano/errorstudio/composer'
require 'capistrano/errorstudio/nginx'
set :web_server, ->{ roles(:web).first.hostname }
set :db_server, ->{ roles(:db).first.hostname }
set :linked_dirs, fetch(:linked_dirs,[]).push(fetch(:uploads_folder,"public/wp-content/uploads"))
# set :wp_db_host, fetch(:wp_db_host, "localhost")
# set :wp_db_prefix, fetch(:wp_db_prefix, "wp_")
set :php_required, true
load File.expand_path("../tasks/wordpress.rake", __FILE__)

