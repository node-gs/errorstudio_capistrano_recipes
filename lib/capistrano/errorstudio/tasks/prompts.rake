def confirm(message)
  puts <<-WARN

  ========================================================================
        #{message}
  ========================================================================

  WARN
  set :answer, ask("Continue? y/n",'n')
  if fetch(:answer)== 'y' then true else false end
end

def prompt_for_login
  unless fetch(:server_admin_username,false) && fetch(:server_admin_password, false)
    set :server_admin_username, ask("Server MySQL Username:",nil)
    set :server_admin_password, ask("Server DB Password:", nil, echo: false)
  end
end