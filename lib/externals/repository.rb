require 'fileutils'

module Externals
  class Repository
    
    attr_reader :name
    
    def initialize(base_dir, name, repo_url, rel_path)
      @base_dir = base_dir
      @name = name
      @repo_url = repo_url
      @rel_path = rel_path
    end
    
    def exists?
      File.exist?(repo_path)
    end
    
    def freeze
      install unless exists?
      if is_not_a_git_repo?
        puts "already frozen: #{@name}"
      elsif is_a_git_repo?
        overwrite = true
        # Conditionally destroy compressed repo
        if is_compressed?
          puts "You already have a frozen git snapshot. Overwrite?"
          overwrite = STDIN.gets.downcase[0..0] == 'y'
        end
        Dir.chdir(repo_path) do
          if overwrite
            # Make temp directory
            FileUtils.mkdir_p(temp_path)
            # Compress .git folder to temp
            `tar czf #{temp_path}/#{@name}.git.tgz .git` unless $TESTING
          end
          # Remove repository's .git folder
          FileUtils.rm_r('.git')
        end
        puts "frozen: #{@name}"
      end
    end
    
    def install
      # Create directory that we will clone into
      unless File.exist?(checkout_path)
        FileUtils.mkdir_p(checkout_path)
      end
      Dir.chdir(checkout_path) do
        # Remove repository if exists
        FileUtils.rm_rf(@name)
        # Clone repository
        `git clone #{@repo_url} #{@name}` unless $TESTING
      end
    end
    
    def is_a_git_repo?
      File.exist?("#{repo_path}/.git")
    end
    
    def is_not_a_git_repo?
      !is_a_git_repo?
    end
    
    def is_compressed?
      File.exists?("#{temp_path}/#{@name}.git.tgz")
    end
    
    def is_not_compressed?
      !is_compressed?
    end
    
    def status
      if exists?
        puts "#{is_a_git_repo? ? "not frozen" : "frozen and #{is_compressed? ? "has" : "does not have"} a snapshot"}: #{@name}"
      else
        puts "does not exist and #{is_compressed? ? "has" : "does not have"} a snapshot: #{@name}"
      end
    end

    def unfreeze
      if is_a_git_repo?
        puts "already unfrozen: #{@name}"
      elsif !exists?
        install
        puts "#{@name} unfrozen"
      elsif is_not_a_git_repo?
        if is_compressed?
          Dir.chdir(temp_path) do
            # Decompress git snapshot
            `tar xzf #{@name}.git.tgz` unless $TESTING
            # Move back to repo
            FileUtils.mv(".git", repo_path)
            # Remove snapshot
            FileUtils.rm_f("#{@name}.git.tgz")
          end
        else
          # Clone fresh repo if no snapshot found
          install
        end
        puts "unfrozen: #{@name}"
      end
    end

    private
    
    def checkout_path
      File.expand_path(File.join(@base_dir, @rel_path))
    end

    def repo_path
      File.expand_path(checkout_path + '/' + @name)
    end
    
    def temp_path
      @base_dir + '/tmp'
    end
  end
end
