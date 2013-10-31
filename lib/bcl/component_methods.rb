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
#require 'rest-client'
require 'net/https'
require 'libxml'

module BCL

  class ComponentMethods

    attr_accessor :config
    attr_accessor :session
    attr_accessor :http

    def initialize()
      @config = nil
      @session = nil
      @access_token = nil
      @http = nil
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
      settings = { :server => { :url => "https://bcl.nrel.gov", :user => { :username => "ENTER_BCL_USERNAME", :password => "ENTER_BCL_PASSWORD"} } }

      settings
    end
    
    
    def login(username=nil, password=nil)
      if username.nil? || password.nil?
        # log in via cached creditials
        username = @config[:server][:user][:username]
        password = @config[:server][:user][:password]
      end
	
      #figure out what time to use
      url = @config[:server][:url]
      #look for http vs. https
      if url.include? "https"
        port = 443
      else
        port = 80
      end
      #strip out http(s)
      url = url.gsub('http://', '')
      url = url.gsub('https://', '')
      
      puts "Connecting to #{url} on port #{port} as #{username}"
      
      @http = Net::HTTP.new(url, port)
      @http.use_ssl = true
      
      data = %Q({"username":"#{username}","password":"#{password}"})
      #data = {"username" => username, "password" => password}
      
      login_path = "/api/user/login.json?"
      headers = {'Content-Type' => 'application/json'}

      res, data = @http.post(login_path, data, headers)
      
      #restClient wasn't working
      #res = RestClient.post "#{@config[:server][:url]}/api/user/login", data.to_json, :content_type => :json, :accept => :json
      if res.code == '200'
        puts "Login Successful"
=begin
		  #OLD RESTCLIENT CODE
        #pull out the session key
        res_j = JSON.parse(res.body)
        sessid = res_j["sessid"]
        session_name = res_j["session_name"]

			puts "**** RETURNED COOKIES: #{res.cookies.inspect}"
			#pull out the BNES key and BNI key
			bnes_name = ""
			bnesid = ""
			bni_name = ""
			bni_id = ""
			junkout = res.cookies
			junkout.each do |key, val|
			  if key.include?("BNES_SESS")
				 bnes_name = key.to_s
				 bnesid = val.to_s
			  end
			end
			junkout.each do |key, val|
			  if key.include?("BNI_bcl")
				bni_name = key.to_s
				bni_id = val.to_s
			  end
			end
			#@session = { session_name => sessid, bnes_name => bnesid }
			#@session = {session_name => URI.unescape(sessid), bnes_name => URI.unescape(bnesid)}
			@session = {session_name => sessid,bnes_name => bnesid,bni_name => bni_id}
		
=end
    
        bnes = ""
        bni = ""
        junkout = res["set-cookie"].split(";")
        junkout.each do |line|
          if line =~ /BNES_SESS/
           bnes = line.match(/(BNES_SESS.*)/)[0]
          end
        end

        junkout.each do |line|
          if line =~ /BNI/
           bni = line.match(/(BNI.*)/)[0]
          end
        end

        #puts "DATA: #{data}"
        session_name = ""
        sessid = ""
        json = JSON.parse(data)
        json.each do |key, val| 
          if key == 'session_name'
            session_name = val
          elsif key == 'sessid'
            sessid = val
          end
        end

        @session = session_name + '=' + sessid + ';' + bni + ";" + bnes 
         
        #get access token
        token_path = "/services/session/token"
        token_headers = {'Content-Type' => 'application/json', 'Cookie' => @session}
        #puts "token_headers = #{token_headers.inspect}"
        access_token_res, access_token = @http.post(token_path,"",token_headers)
        if access_token_res.code == '200'
          @access_token = access_token
        else
          puts "Unable to get access token; uploads will not work"
          puts "error code: #{access_token_res.code}"
          puts "error info: #{access_token_res.body}"
        end
		
        #puts "access_token = *#{@access_token}*" 
        #puts "cookie = #{@session}"
        
        res
      else
      
        puts "error code: #{res.code}"
        puts "error info: #{res.body}"
		
        res
      end
    end

    # pushes component to the bcl and publishes them (if logged-in as BCL Website Admin user).
    # username and password set in ~/.bcl/config.yml file
    def push_content(filename_and_path, write_receipt_file, content_type, bcl_group_id)
      raise "Please login before pushing components" if @session.nil?
      raise "Do not have a valid access token; try again" if @access_token.nil?
      valid = false
      res_j = nil
      filename = File.basename(filename_and_path)
      #TODO remove special characters in the filename; they create firewall errors
      #filename = filename.gsub(/\W/,'_').gsub(/___/,'_').gsub(/__/,'_').chomp('_').strip
      filepath = File.dirname(filename_and_path) + "/"
      file = File.open(filename_and_path, 'rb')
      file_b64 = Base64.encode64(file.read)
      @data = {
              "file" =>
               {
                 "file" => "#{file_b64}",
                 "filesize" => "#{File.size(filename_and_path)}",
                 "filename" => filename
               },
                "node" =>
               {
                "type" => "#{content_type}",
                "field_component_tags" =>  #TODO remove this field_component_tags once BCL is fixed
                  {
                    "und" => "1289"
                  },  
                "og_group_ref" =>
                  {
                    "und" =>
                      ["target_id" => bcl_group_id],
                      "publish" => 1  #NOTE THIS ONLY WORKS IF YOU ARE A BCL SITE ADMIN
                  }
                }
              }    
      #restclient not working
      #res = RestClient.post "#{@config[:server][:url]}/api/content.json", @data.to_json, :content_type => :json, :cookies => @session
	   
      path = "/api/content.json"	 
      headers = {'Content-Type' => 'application/json','X-CSRF-Token' => @access_token, 'Cookie' => @session}
      #puts headers.inspect
      res, data = @http.post(path, @data.to_json, headers)		
		 
      res_j = "could not get json from http post response"
      if res.code == '200'
        res_j = JSON.parse(res.body)
        puts "  200 - Successful Upload"
        valid = true
      elsif res.code == '404'
        puts "  error code: #{res.code} - #{res.body}"
        puts "  404 - check these common causes first:"
        puts "    the filename contains periods (other than the ones before the file extension)"
        puts "    you are not an 'administrator member' of the group you're trying to upload to"
        valid = false   
      elsif res.code == '500'
        puts "  error code: #{res.code} - #{res.body}"
        raise "server exception"
        valid = false
      else
        puts "  error code: #{res.code} - #{res.body}"
        valid = false        
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

    def push_contents(array_of_components, skip_files_with_receipts, content_type, bcl_group_id)
      logs = []
      array_of_components.each do |comp|
        receipt_file = File.dirname(comp) + "/" + File.basename(comp, '.tar.gz') + ".receipt"
        log_message = ""
        if skip_files_with_receipts && File.exists?(receipt_file)
          log_message = "skipping because found receipt #{comp}"
          puts log_message
        else
          log_message = "pushing content #{File.basename(comp, '.tar.gz')}"
          puts log_message
          valid, res = push_content(comp, true, content_type, bcl_group_id)
          log_message += " #{valid} #{res.inspect.chomp}"
        end
        logs << log_message
      end

      logs
    end
	
    # pushes updated content to the bcl and publishes it (if logged-in as BCL Website Admin user).
    # username and password set in ~/.bcl/config.yml file
    def update_content(filename_and_path, write_receipt_file, uuid, bcl_group_id)
      raise "Please login before pushing components" if @session.nil?
      valid = false
      res_j = nil
      filename = File.basename(filename_and_path)
      #TODO remove special characters in the filename; they create firewall errors
      #filename = filename.gsub(/\W/,'_').gsub(/___/,'_').gsub(/__/,'_').chomp('_').strip
      filepath = File.dirname(filename_and_path) + "/"
      file = File.open(filename_and_path, 'rb')
      file_b64 = Base64.encode64(file.read)
      @data = {
              "file" =>
               {
                 "file" => "#{file_b64}",
                 "filesize" => "#{File.size(filename_and_path)}",
                 "filename" => filename
               },
               "node" =>
               {
                "uuid" => "#{uuid}",
                "field_component_tags" =>  #TODO remove this field_component_tags once BCL is fixed
                  {
                    "und" => "1289"
                  },                  
                "og_group_ref" =>
                  {
                    "und" =>
                      ["target_id" => bcl_group_id],
                      "publish" => 1  #NOTE THIS ONLY WORKS IF YOU ARE A BCL SITE ADMIN
                  }
                }
              }
                
		#restclient not working
		#res = RestClient.post "#{@config[:server][:url]}/api/content", @data.to_json, :content_type => :json, :cookies => @session, :accept => :json   

		path = "/api/content.json"	 
		headers = {'Content-Type' => 'application/json', 'Cookie' => @session, 'X-CSRF-Token' => @access_token}

		res, data = @http.post(path, @data.to_json, headers)
				
      res_j = "could not get json from http post response"
      if res.code == '200'
        res_j = JSON.parse(res.body)
        puts "  200 - Successful Upload"
        valid = true
      elsif res.code == '404'
        puts "  error code: #{res.code} - #{res.body}"
        puts "  404 - check these common causes first:"
        puts "    the filename contains periods (other than the ones before the file extension)"
        puts "    you are not an 'administrator member' of the group you're trying to upload to"
        valid = false   
      elsif res.code == '500'
        puts "  error code: #{res.code} - #{res.body}"
        raise "server exception"
        valid = false
      else
        puts "  error code: #{res.code} - #{res.body}"
        valid = false        
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
	
	def update_contents(array_of_components, skip_files_with_receipts, bcl_group_id)
	  logs = []
	  array_of_components.each do |comp|
      receipt_file = File.dirname(comp) + "/" + File.basename(comp, '.tar.gz') + ".receipt"
      log_message = ""
      if skip_files_with_receipts && File.exists?(receipt_file)
        log_message = "skipping update because found receipt #{File.basename(comp)}"
        puts log_message
      else
        #extract uuid from the .tar.gz file
        uuid = nil
        tgz = Zlib::GzipReader.open(comp)
        Archive::Tar::Minitar::Reader.open(tgz).each do |entry|
          if entry.name == "component.xml" or entry.name == "measure.xml"
            xml_file = LibXML::XML::Document.string(entry.read)
            uid_node = xml_file.find('uid').first
            uuid = uid_node.content
            #vid_node = xml_file.find('version_id').first
            #vid = vid_node.content
            #puts "uuid = #{uuid}; vid = #{vid}"
          end
        end
        if uuid == nil
          log_message "ERROR: uuid not found for #{File.basename(comp)}"
          puts log_message
        else
          log_message = "pushing updated content #{File.basename(comp)}"
          puts log_message
          valid, res = update_content(comp, true, uuid, bcl_group_id)
          log_message += " #{valid} #{res.inspect.chomp}"
        end
      end
      logs << log_message
	  end
    logs		
	end

  # Simple method to search bcl and return the result as an XML object
  def search(search_str)
    full_url = "#{@config[:server][:url]}/api/search/#{search_str}&api_version=#{@api_version}"
    res = RestClient.get "#{full_url}"
    xml = LibXML::XML::Document.string(res.body)

    xml
  end
	
	# Delete receipt files
	def delete_receipts(array_of_components)
	  array_of_components.each do |comp|
      receipt_file = File.dirname(comp) + "/" + File.basename(comp, '.tar.gz') + ".receipt"
      if File.exists?(receipt_file)
        FileUtils.remove_file(receipt_file)
      
      end
	  end
	end
  
  end #class ComponentMethods

  # TODO make this extend the component_xml class (or create a super class around components)

  def BCL.gather_components(component_dir, chunk_size = 0, delete_previousgather = false)
    @dest_filename = "components"
    @dest_file_ext = "tar.gz"

    #store the starting directory
    current_dir = Dir.pwd

    #an array to hold reporting info about the batches
    gather_components_report = []

    #go to the directory containing the components
    Dir.chdir(component_dir)

    # delete any old versions of the component chunks
    FileUtils.rm_rf("./gather") if delete_previousgather

    #gather all the components into array
    targzs = Pathname.glob("./**/*.tar.gz")
    tar_cnt = 0
    chunk_cnt = 0
    targzs.each do |targz|
      if chunk_size != 0 && (tar_cnt % chunk_size) == 0
        chunk_cnt += 1
      end
      tar_cnt += 1

      destination_path = "./gather/#{chunk_cnt}"
      FileUtils.mkdir_p(destination_path)
      destination_file = "#{destination_path}/#{File.basename(targz.to_s)}"
      #puts "copying #{targz.to_s} to #{destination_file}"
      FileUtils.cp(targz.to_s, destination_file)
    end

    #gather all the .tar.gz files into a single tar.gz
    (1..chunk_cnt).each do |cnt|
      currentdir = Dir.pwd
      
      paths = []
      Pathname.glob("./gather/#{cnt}/*.tar.gz").each do |pt|
        paths << File.basename(pt.to_s)
      end

      Dir.chdir("./gather/#{cnt}")
      destination = "#{@dest_filename}_#{cnt}.#{@dest_file_ext}"
      puts "tarring batch #{cnt} of #{chunk_cnt} to #{@dest_filename}_#{cnt}.#{@dest_file_ext}"
      BCL.tarball(destination, paths)
      Dir.chdir(currentdir)

      #move the tarball back a directory
      FileUtils.move("./gather/#{cnt}/#{destination}", "./gather/#{destination}")
    end

    Dir.chdir(current_dir)

  end

end # module BCL
