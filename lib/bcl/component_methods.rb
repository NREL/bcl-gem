######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.
#  All rights reserved.
#  
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require 'rubygems'
require 'pathname'
require 'fileutils'
require 'enumerator'
require 'yaml'
require 'base64'

# required gems
require 'json/pure'
require 'bcl/tar_ball'
require 'rest-client'

module BCL

  class ComponentMethods

    attr_accessor :config
    attr_accessor :session

    def initialize()
      @config = nil
      @session = nil
      @api_version = 2.0
      config_path = File.expand_path('~') + '/.bcl'
      config_name = 'config.yml'
      if File.exists?(config_path + "/" + config_name)
        puts "loading config settings from #{config_path + "/" + config_name}"
        @config = YAML.load_file(config_path + "/" + config_name)
      else
        #location of template file
        FileUtils.mkdir_p(config_path)
        File.open(config_path + "/" + config_name, 'w') do |file|
          file << default_yaml.to_yaml
        end
        raise "******** Please fill in user credentials in #{config_path}/#{config_name} file.  DO NOT COMMIT THIS FILE. **********"
      end

    end

    def default_yaml
      settings = { :server => { :url => "bcl7.development.nrel.gov", :admin_user => { :username => "ENTER_BCL_USERNAME", :password => "ENTER_BCL_PASSWORD"} } }

      settings
    end

    def login(username=nil, password=nil)
      if username.nil? || password.nil?
        # log in via cached creditials
        username = @config[:server][:admin_user][:username]
        password = @config[:server][:admin_user][:password]
      end

      data = {"username" => username, "password" => password}
      res = RestClient.post "http://#{@config[:server][:url]}/api/user/login", data.to_json, :content_type => :json, :accept => :json

      if res.code == 200
        #pull out the session key
        res_j = JSON.parse(res.body)

        sessid = res_j["sessid"]
        session_name = res_j["session_name"]

        @session = { session_name => sessid }
      end

      res
    end


    # pushes component to the bcl and sets to published (for now). Username and password and
    # set in ~/.bcl/config.yml file which determines the permissions and the group to which
    # the component will be uploaded
    def push_content(filename_and_path, write_receipt_file, content_type)
      raise "Please login before pushing components" if @session.nil?

      valid = false
      res_j = nil
      filename = File.basename(filename_and_path)
      filepath = File.dirname(filename_and_path) + "/"

      file = File.open(filename_and_path, 'r')
      file_b64 = Base64.encode64(file.read)
      @data = {"file" =>
                   {
                       "file" => "#{file_b64}",
                       "filesize" => "#{File.size(filename_and_path)}",
                       "filename" => filename
                   },
               "node" =>
                     {
                        "type" => "#{content_type}",
                        "status" => 1  #NOTE THIS ONLY WORKS IF YOU ARE ADMIN
                     }
                }

      res = RestClient.post "http://#{@config[:server][:url]}/api/content", @data.to_json, :content_type => :json, :cookies => @session, :accept => :json

      if res.code == 200
        res_j = JSON.parse(res.body)

        if res.code == 200
          valid = true
        elsif res.code == 500
          raise "server exception"
          valid = false
        else
          valid = false
        end
      else
        res = nil
      end

      if valid
        #write out a receipt file into the same directory of the component with the same file name as
        #the component
        if write_receipt_file
          File.open(filepath + File.basename(filename, '.tar.gz') + ".receipt", 'w') do |file|
            file << Time.now.to_s
          end
        end
      end

      [valid, res_j]
    end

    def push_contents(array_of_components, skip_files_with_receipts, content_type)
      logs = []
      array_of_components.each do |comp|
        receipt_file = File.dirname(comp) + "/" + File.basename(comp, '.tar.gz') + ".receipt"
        log_message = ""
        if skip_files_with_receipts && File.exists?(receipt_file)
          log_message = "skipping component because found receipt for #{comp}"
        else
          log_message = "pushing component #{comp}: "
          puts log_message
          valid, res = push_content(comp, true, content_type)
          log_message += " #{valid} #{res.inspect.chomp}"
        end
        logs << log_message
      end

      logs
    end

    # Simple method to search bcl and return the result as an XML object
    def search(search_str)
      full_url = "http://#{@config[:server][:url]}/api/search/#{search_str}&api_version=#{@api_version}"
      res = RestClient.get "#{full_url}"
      xml = LibXML::XML::Document.string(res.body)

      xml
    end

  end

  # TODO make this extend the component_xml class (or create a super class around components)

  def BCL.gather_components(component_dir, chunk_size = 0, delete_previous_gather = false)
    @dest_filename = "components"
    @dest_file_ext = "tar.gz"

    #store the starting directory
    current_dir = Dir.pwd

    #an array to hold reporting info about the batches
    gather_components_report = []

    #go to the directory containing the components
    Dir.chdir(component_dir)

    # delete any old versions of the component chunks
    FileUtils.rm_rf("./_gather") if delete_previous_gather

    #gather all the components into array
    targzs = Pathname.glob("./**/*.tar.gz")
    tar_cnt = 0
    chunk_cnt = 0
    targzs.each do |targz|
      if chunk_size != 0 && (tar_cnt % chunk_size) == 0
        chunk_cnt += 1
      end
      tar_cnt += 1

      destination_path = "./_gather/#{chunk_cnt}"
      FileUtils.mkdir_p(destination_path)
      destination_file = "#{destination_path}/#{File.basename(targz.to_s)}"
      puts "copying #{targz.to_s} to #{destination_file}"
      FileUtils.cp(targz.to_s, destination_file)
    end

    #gather all the zip files into a single tar.gz
    (1..chunk_cnt).each do |cnt|
      currentdir = Dir.pwd

      paths = []
      Pathname.glob("./_gather/#{cnt}/*.tar.gz").each do |pt|
        paths << File.basename(pt.to_s)
      end

      Dir.chdir("./_gather/#{cnt}")
      destination = "#{@dest_filename}_#{cnt}.#{@dest_file_ext}"
      BCL.tarball(destination, paths)
      Dir.chdir(currentdir)

      #move the tarball back a directory
      FileUtils.move("./_gather/#{cnt}/#{destination}", "./_gather/#{destination}")
    end

    Dir.chdir(current_dir)

  end



end # module BCL
