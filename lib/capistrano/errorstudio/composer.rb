require 'capistrano/composer'
Rake::Task['deploy:updated'].prerequisites.delete('composer:install')
load File.expand_path("../tasks/composer.rake", __FILE__)