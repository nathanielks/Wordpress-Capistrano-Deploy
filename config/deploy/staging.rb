#Where we're deploying to on the server
set :deploy_to, "/var/www/vhosts/site.com/capistrano" #TODO No trailing slash 

#Remote Server credentials
set :user, "user" #TODO

set :domain, "domain.com" #TODO
set :password, "password" #TODO
set :port, "22" #TODO
server "#{user}@#{domain}", :app #This line doesn't need to change

# This is useful if apache or something needs to belong to a group. I added
# this when working on a Med Temple DV server where the files needed to be
# a part of the group placln. Don't forget to uncomment out the line near the
# bottom of the document to turn this on.

set :group. "group" #TODO


# We'll be referencing this when we go to search and replace the database, this
# is where we'll clone the search and replace script if it doesn't exist
set :local_path, '~/Sites/localhost' #TODO

# Local Database credentials for playground.rb
set :local_db_database, "database" #TODO
set :local_db_username, "user" #TODO
set :local_db_password, "password" #TODO
set :local_db_host, "localhost" #TODO
set :local_db_charset, "utf8" #TODO
set :local_site_url, "://local_sitename" #this is the url to be searched for later #TODO
set :db_prefix, 'db_prefix_' #TODO

# Remote Database credentials for playground.rb
set :remote_db_database, "database" #TODO
set :remote_db_username, "user" #TODO
set :remote_db_password, "password" #TODO
set :remote_db_host, "localhost" #TODO
set :remote_db_charset, "utf8" #TODO
set :remote_site_url, "://domain.com" #this is the url to be replaced with later #TODO

set :dbp, "#{remote_db_database}.#{db_prefix}"


# This is the path to WordPress's uploads folder on YOUR machine
set :uploads_path, "/path/to/wp-content/uploads" #TODO

# This is the path to WordPress's blogs.dir folder on YOUR machine (Used in MultiSite)
set :blogs_dir_path, "/path/to/wp-content/blogs.dir" #TODO


# Alright, that's it! Stop editing!
#
# Now Begin the magic

#Symlink wp-config to the release folder so it doesn't get overwritten
namespace :my_project do
    task :symlink, :roles => :app do
        run "ln -nfs #{shared_path}/wp-config-staging.php #{release_path}/wp-config-staging.php"
        run "ln -nfs #{shared_path}/.htaccess #{release_path}/.htaccess"
    end
end

after "deploy:finalize_update", "staging:symlink"

#Create backups directory
namespace(:deploy) do
  desc "Add backups directory"
  task :add_backups_dir, :roles => :app do
    run "mkdir #{shared_path}/backups"
  end
end
after "deploy:setup", "deploy:add_backups_dir"

#Backup Remote DB
namespace(:deploy) do
  desc "Backup MySQL Database"
  task :mysqlbackup, :roles => :app do
    run "mysqldump -u#{remote_db_username} -p#{remote_db_password} #{remote_db_database} > #{shared_path}/backups/#{release_name}.sql"
  end
end
before "deploy:create_symlink", "deploy:mysqlbackup"

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
    run "[ -d #{shared_path}/srdb/ ] || git clone git://github.com/interconnectit/Search-Replace-DB.git #{shared_path}/srdb"  
    run "php -f #{shared_path}/srdb/searchreplacedb2cli.php cli -h #{remote_db_host} -d #{remote_db_database} -u #{remote_db_username} -p #{remote_db_password} -c #{remote_db_charset} -s #{local_site_url} -r #{remote_site_url} guid=0"
    #run "php -f #{shared_path}/srdb/searchreplacedb2cli.php cli -h #{remote_db_host} -d #{remote_db_database} -u #{remote_db_username} -p #{remote_db_password} -c #{remote_db_charset} -s #{local_site_path} -r #{remote_site_path} guid=0"
  end
end

#Dump Local DB, replace Remote DB, update urls in DB
namespace(:deploy) do
  desc "Dump Local DB and replace Remote DB"
  task :mu_update, :roles => :app do
    run_locally "mysqldump -u#{local_db_username} -p#{local_db_password} -h#{local_db_host} -C -c --skip-add-locks #{local_db_database} --ignore-table=#{dbp}blogs --ignore-table=#{dbp}blog_versions --ignore_table=#{dbp}site --ignore-table=#{dbp}sitemeta | ssh #{user}@#{domain} -p #{port} 'mysql -u #{remote_db_username} -p#{remote_db_password} #{remote_db_database}'"
    run "[ -d #{shared_path}/srdb/ ] || git clone git://github.com/interconnectit/Search-Replace-DB.git #{shared_path}/srdb"  
    run "php -f #{shared_path}/srdb/searchreplacedb2cli.php cli -h #{remote_db_host} -d #{remote_db_database} -u #{remote_db_username} -p #{remote_db_password} -c #{remote_db_charset} -s #{local_site_url} -r #{remote_site_url} guid=0"
  end
end

#Dump Local DB, replace Remote DB, update urls in DB
namespace(:deploy) do
  desc "Dump Local DB and replace Remote DB"
  task :local_mu_update, :roles => :app do
    run_locally "ssh #{user}@#{domain} -p #{port} 'mysqldump -u#{remote_db_username} -p#{remote_db_password} -h#{remote_db_host} #{remote_db_database} -C -c --skip-add-locks --ignore-table=#{dbp}blogs --ignore-table=#{dbp}blog_versions --ignore_table=#{dbp}site --ignore-table=#{dbp}sitemeta' | mysql -u#{local_db_username} -p#{local_db_password} -h#{local_db_host} #{local_db_database}"
    run "[ -d #{local_path}/srdb/ ] || git clone git://github.com/interconnectit/Search-Replace-DB.git #{local_path}/srdb"  
    run_locally "php -f #{local_path}/srdb/searchreplacedb2cli.php cli -h #{local_db_host} -d #{local_db_database} -u #{local_db_username} -p #{local_db_password} -c #{local_db_charset} -s #{remote_site_url} -r #{local_site_url} guid=0"
  end
end

#Dump Local DB, replace Remote DB, update urls in DB
namespace(:deploy) do
  desc "Dump Local DB and replace Remote DB"
  task :update_posts, :roles => :app do
    run_locally "mysqldump -u#{local_db_username} -p#{local_db_password} -h#{local_db_host} -C -c --skip-add-locks #{local_db_database} #{db_prefix}posts #{db_prefix}postmeta #{db_prefix}options | ssh #{user}@#{domain} -p #{port} 'mysql -u #{remote_db_username} -p#{remote_db_password} #{remote_db_database}'"
    run "[ -d #{shared_path}/srdb/ ] || git clone git://github.com/interconnectit/Search-Replace-DB.git #{shared_path}/srdb"  
    run "php -f #{shared_path}/srdb/searchreplacedb2cli.php cli -h #{remote_db_host} -d #{remote_db_database} -u #{remote_db_username} -p #{remote_db_password} -c #{remote_db_charset} -s #{local_site_url} -r #{remote_site_url} guid=0"
  end
end

#after "deploy:mysqlbackup", "deploy:dbupdate"

#Sync uploads folder
namespace(:deploy) do
  desc "Sync Uploads folder"
  task :sync_uploads, :roles => :app do
    run_locally "if [ -d #{uploads_path} ]; then rsync -avhru #{uploads_path} -delete -e 'ssh -p #{port}' #{user}@#{domain}:#{shared_path}; fi"
  end
end

after "tft_staging:symlink", "deploy:sync_uploads"


#Sync blogs.dir folder
namespace(:deploy) do
  desc "Sync blogs.dir folder"
  task :sync_blogs_dir, :roles => :app do
    run_locally "if [ -d #{blogs_dir_path} ]; then rsync -avhru #{blogs_dir_path} -delete -e 'ssh -p #{port}' #{user}@#{domain}:#{shared_path}; fi"
  end
end
after "tft_staging:symlink", "deploy:sync_blogs_dir"

#Dump Local DB, replace Remote DB, update urls in DB
namespace(:deploy) do
  desc "Fix file permissions"
  task :update_permissions, :roles => :app do
    run "cd #{release_path} && chown -R #{user}:#{group} . && find . -type d -print0 | xargs -0 chmod 755"
    run "cd #{shared_path}/uploads && chown -R #{user}:#{group} ."
    run "cd #{shared_path}/blogs.dir && chown -R #{user}:#{group} ."
  end
end

#after "tft_staging:symlink", "deploy:update_permissions"
