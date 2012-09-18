set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :application, "application-name" # TODO
set :repository, "git@github.com:/username/repo.git" # TODO
set :scm, :git
set :use_sudo, false

ssh_options[:forward_agent] = true
set :deploy_via, :remote_cache
set :copy_exclude, [".git", ".DS_Store", ".gitignore", ".gitmodules"]
set :git_enable_submodules, 1
set :wp_multisite, 0 # TODO Set to 1 if multisite

namespace :my_project do
    task :symlink, :roles => :app do
        run "if [ -d #{shared_path}/uploads ]; then ln -nfs #{shared_path}/uploads #{release_path}/wp-content/uploads; fi"
        if :wp_multisite == 1
        	run "if [ -d #{shared_path}/blogs.dir ]; then ln -nfs #{shared_path}/blogs.dir #{release_path}/wp-content/blogs.dir; fi"
        end
    end
end

after "deploy:create_symlink", "myproject:symlink"

## Use below if you want to deploy based on tag releases
#set :branch do
    #default_tag = `git tag`.split("\n").last

    #tag = Capistrano::CLI.ui.ask "Tag to deploy: [#{default_tag}] "
    #tag = default_tag if tag.empty?
    #tag
#end
