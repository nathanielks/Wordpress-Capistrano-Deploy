#Where we're deploying to on the server
set :deploy_to, "/path/to/site/root" # No trailing slash 

#Remote Server credentials
set :user, "user"
set :domain, "domainOrIP"
set :port, "22"
server "#{user}@#{domain}", :app #This line doesn't need to change

# Local Database credentials for playground.rb
set :local_db_database, "database"
set :local_db_username, "username"
set :local_db_password, "password"
set :local_db_host, "localhost"
set :local_site_url, "http://localsiteurl" #this is the url to be searched for later

# Remote Database credentials for playground.rb
set :remote_db_database, "database"
set :remote_db_username, "username"
set :remote_db_password, "password`"
set :remote_db_host, "localhost"
set :remote_db_charset, "utf8"
set :remote_site_url, "http://remotesiteurl" #this is the url to be replaced with later

# This is the path to WordPress's uploads folder on YOUR machine
set :uploads_path, "/path/to/wp-content/uploads"

# This is the path to WordPress's blogs.dir folder on YOUR machine (Used in MultiSite)
set :blogs_dir_path, "/path/to/wp-content/blogs.dir"


#Begin the magic

namespace :myproject_playground do
    task :symlink, :roles => :app do
        run "touch #{release_path}/env_playground"
    end
end

after "deploy:symlink", "myproject_playground:symlink"

#Symlink wp-config to the release folder so it doesn't get overwritten
namespace :myproject_playground do
    task :symlink, :roles => :app do
        run "ln -nfs #{shared_path}/wp-config-playground.php #{release_path}/wp-config-playground.php"
    end
end

after "deploy:symlink", "myproject_playground:symlink"

#Create backups directory
namespace(:deploy) do
  desc "Add backups directory"
  task :add_backups_dir, :roles => :app do
    run "mkdir #{shared_path}/backups"
  end
end
after "deploy:setup", "deploy:add_backups_dir"

#Update themes
namespace(:deploy) do
  desc "Update HU theme"
  task :theme_update, :roles => :app do
    run "cd #{current_path} && git submodule update --init"
  end
end

#Backup Remote DB
namespace(:deploy) do
  desc "Backup MySQL Database"
  task :mysqlbackup, :roles => :app do
    run "mysqldump -u#{remote_db_username} -p#{remote_db_password} #{remote_db_database} > #{shared_path}/backups/#{release_name}.sql"
  end
end
before "deploy:symlink", "deploy:mysqlbackup"

#Restore Remote DB
namespace(:deploy) do
  desc "Restore MySQL Database"
  task :mysqlrestore, :roles => :app do
    backups = capture("ls -1 #{shared_path}/backups/").split("\n")
    default_backup = backups.last
    puts "Available backups: "
    puts backups
    backup = Capistrano::CLI.ui.ask "Which backup would you like to restore? [#{default_backup}] "
    backup_file = default_backup if backup.empty?

    run "mysql -u#{remote_db_username} -p#{remote_db_password} #{remote_db_database} < #{shared_path}/backups/#{backup_file}"
  end
end

#Dump Local DB, replace Remote DB, update urls in DB
namespace(:deploy) do
  desc "Dump Local DB and replace Remote DB"
  task :dbupdate, :roles => :app do
    run_locally "mysqldump -u#{local_db_username} -p#{local_db_password} -h#{local_db_host} -C -c --skip-add-locks #{local_db_database} | ssh #{user}@#{domain} -p #{port} 'mysql -u #{remote_db_username} -p#{remote_db_password} #{remote_db_database}'"
    run "[ -d #{shared_path}/srdb/ ] || git clone git://github.com/nathanielks/srdb.git #{shared_path}/srdb"  
    run "php -f #{shared_path}/srdb/srdb.php cli host=#{remote_db_host} data=#{remote_db_database} user=#{remote_db_username} pass=#{remote_db_password} char=#{remote_db_charset} srch=#{local_site_url} rplc=#{remote_site_url} guid=0"
  end
end

after "deploy:mysqlbackup", "deploy:dbupdate"

#Sync uploads folder
namespace(:deploy) do
  desc "Sync Uploads folder"
  task :sync_uploads, :roles => :app do
    run_locally "if [ -d #{uploads_path} ]; then rsync -avhr #{uploads_path} -update -delete -e 'ssh -p #{port}' #{user}@#{domain}:#{shared_path}; fi"
  end
end

after "deploy:dbupdate", "deploy:sync_uploads"


#Sync blogs.dir folder
namespace(:deploy) do
  desc "Sync blogs.dir folder"
  task :sync_blogs_dir, :roles => :app do
    run_locally "test -d #{blogs_dir_path} && rsync -avhr #{blogs_dir_path} -update -delete -e 'ssh -p #{port}' #{user}@#{domain}:#{shared_path}"
  end
end

if :wp_multisite == 1
  after "deploy:dbupdate", "deploy:sync_blogs_dir"
end
