namespace :cron do
  desc "Generate cron scripts"
  task :generate_cron_scripts do
    on roles(:web) do
      fetch(:cron_scripts).each do |cron_time, files|
        files.each do |cron_template|
          buffer = ERB.new(File.read(cron_template)).result(binding)+"\n"
          cron_filename = File.basename(cron_template).gsub(/\.sh\.erb$/, '')
          upload! StringIO.new(buffer), "#{shared_path}/#{cron_time}.#{File.basename(cron_template)}"
          execute "sudo mv -f #{shared_path}/#{cron_time}.#{File.basename(cron_template)} /etc/cron.#{cron_time}/#{cron_filename} && sudo chown root:root /etc/cron.#{cron_time}/#{cron_filename} && sudo chmod +x /etc/cron.#{cron_time}/#{cron_filename}"
        end
      end
    end
  end
end
