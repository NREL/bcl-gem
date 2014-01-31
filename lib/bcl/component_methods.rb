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


# required gems
require 'net/https'

module BCL

  class ComponentMethods

    attr_accessor :config
    attr_accessor :session
    attr_accessor :http
    attr_accessor :parsed_measures_path

    def initialize()
      @parsed_measures_path = './measures/parsed/'
      @config = nil
      @session = nil
      @access_token = nil
      @http = nil
      @api_version = 2.0
      @group_id = nil

      load_config
    end


    def login(username=nil, password=nil, url=nil, group_id = nil)
      #figure out what url to use
      if url.nil?
        url = @config[:server][:url]
      end
      #look for http vs. https
      if url.include? "https"
        port = 443
      else
        port = 80
      end
      #strip out http(s)
      url = url.gsub('http://', '')
      url = url.gsub('https://', '')

      if username.nil? || password.nil?
        # log in via cached creditials
        puts "logging in using credentials in .bcl/config.yml: Connecting to #{url} on port #{port} as #{username}"
        username = @config[:server][:user][:username]
        password = @config[:server][:user][:password]
        @group_id = group_id || @config[:server][:user][:group]
      else
        puts "logging in using credentials in function arguments: Connecting to #{url} on port #{port} as #{username}"
      end

      if @group_id.nil?
        puts "[WARNING] You did not set a group ID in your config.yml file. You can retrieve your group ID from the node number of your group page (e.g., https://bcl.nrel.gov/node/32). Will continue, but you will not be able to upload content."
      end

      @http = Net::HTTP.new(url, port)
      if port == 443
        @http.use_ssl = true
      end

      data = %Q({"username":"#{username}","password":"#{password}"})
      #data = {"username" => username, "password" => password}

      login_path = "/api/user/login.json"
      headers = {'Content-Type' => 'application/json'}

      res = @http.post(login_path, data, headers)

      # for debugging:
      #res.each do |key, value|
      #  puts "#{key}: #{value}"
      #end

      #restClient wasn't working
      #res = RestClient.post "#{@config[:server][:url]}/api/user/login", data.to_json, :content_type => :json, :accept => :json
      if res.code == '200'
        puts "Login Successful"

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
        json = MultiJson.load(res.body)
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
        access_token = @http.post(token_path, "", token_headers)
        if access_token.code == '200'
          @access_token = access_token.body
        else
          puts "Unable to get access token; uploads will not work"
          puts "error code: #{access_token.code}"
          puts "error info: #{access_token.body}"
        end

        #puts "access_token = *#{@access_token}*"
        # puts "cookie = #{@session}"

        res
      else

        puts "error code: #{res.code}"
        puts "error info: #{res.body}"
        puts "continuing as unauthenticated sessions (you can still search and download)"

        res
      end
    end

    #retrieve, parse, and save metadata for BCL measures
    def measure_metadata(search_term = nil, filter_term=nil, return_all_pages = false)

      #setup results directory
      if !File.exists?(@parsed_measures_path)
        FileUtils.mkdir_p(@parsed_measures_path)
      end
      puts "...storing parsed metadata in #{@parsed_measures_path}"

      #retrieve measures
      puts "retrieving measures that match search_term: #{search_term.nil? ? "nil" :search_term} and filters: #{filter_term.nil? ? "nil" :filter_term}"
      retrieve_measures(search_term, filter_term, return_all_pages) do |measure|
        #parse and save
        parse_measure_metadata(measure)

      end

      return true

    end

    #expects a JSON measure object
    def parse_measure_metadata(measure)

      #check for valid measure
      if measure[:measure][:name] && measure[:measure][:uuid]

        file_data = download_component(measure[:measure][:uuid])

        if file_data
          save_file = File.expand_path("@{parsed_measures_path}#{measure[:measure][:name].downcase.gsub(" ", "_")}.zip")
          File.open(save_file, 'wb') { |f| f << file_data }

          #unzip file and delete zip.
          #TODO check that something was downloaded here before extracting zip
          if File.exists?(save_file)
            BCL.extract_zip(save_file, @parsed_measures_path, true)

            # catch a weird case where there is an extra space in an unzip file structure but not in the measure.name
            if measure[:measure][:name] == "Add Daylight Sensor at Center of Spaces with a Specified Space Type Assigned"
              if !File.exists? "#{@parsed_measures_path}#{measure[:measure][:name]}"
                temp_dir_name = "#{@parsed_measures_path}Add Daylight Sensor at Center of  Spaces with a Specified Space Type Assigned"
                FileUtils.move(temp_dir_name, "#{@parsed_measures_path}#{measure[:measure][:name]}")
              end
            end

            temp_dir_name = "#{@parsed_measures_path}#{measure[:measure][:name]}"

            # Read the measure.rb file
            #puts "save dir name #{temp_dir_name}"
            measure_filename = "#{temp_dir_name}/measure.rb"
            if File.exists?(measure_filename)
              measure_hash = {}
              # read in the measure file and extract some information
              measure_string = File.read(measure_filename)

              measure_hash[:classname] = measure_string.match(/class (.*) </)[1]
              measure_hash[:path] = "#{@parsed_measures_path}#{measure_hash[:classname]}"
              measure_hash[:name] = measure[:measure][:name]
              if measure_string =~ /OpenStudio::Ruleset::WorkspaceUserScript/
                measure_hash[:measure_type] = "EnergyPlusMeasure"
              elsif measure_string =~ /OpenStudio::Ruleset::ModelUserScript/
                measure_hash[:measure_type] = "RubyMeasure"
              elsif measure_string =~ /OpenStudio::Ruleset::ReportingUserScript/
                measure_hash[:measure_type] = "ReportingMeasure"
              else
                raise "measure type is unknown with an inherited class in #{measure_filename}: #{measure_hash.inspect}"
              end

              # move the directory to the class name
              FileUtils.rm_rf(measure_hash[:path]) if File.exists?(measure_hash[:path]) && temp_dir_name != measure_hash[:path]
              FileUtils.move(temp_dir_name, measure_hash[:path]) unless temp_dir_name == measure_hash[:path]

              measure_hash[:arguments] = []

              args = measure_string.scan(/(.*).*=.*OpenStudio::Ruleset::OSArgument::make(.*)Argument\((.*).*\)/)
              #puts "found #{args.size} arguments for measure '#{measure[:measure][:name]}'"
              args.each do |arg|
                new_arg = {}
                new_arg[:local_variable] = arg[0].strip
                new_arg[:variable_type] = arg[1]
                arg_params = arg[2].split(",")
                new_arg[:name] = arg_params[0].gsub(/"|'/, "")
                choice_vector = arg_params[1]

                # local variable name to get other attributes
                new_arg[:display_name] = measure_string.match(/#{new_arg[:local_variable]}.setDisplayName\((.*)\)/)[1]
                new_arg[:display_name].gsub!(/"|'/, "") if new_arg[:display_name]

                if measure_string =~ /#{new_arg[:local_variable]}.setDefaultValue/
                  new_arg[:default_value] = measure_string.match(/#{new_arg[:local_variable]}.setDefaultValue\((.*)\)/)[1]
                  case new_arg[:variable_type]
                    when "Choice"
                      # Choices to appear to only be strings?
                      new_arg[:default_value].gsub!(/"|'/, "")

                      # parse the choices from the measure
                      choices = measure_string.scan(/#{choice_vector}.*<<.*("|')(.*)("|')/)

                      new_arg[:choices] = choices.map { |c| c[1] }
                      # if the choices are inherited from the model, then need to just display the default value which
                      # somehow magically works because that is the display name
                      new_arg[:choices] << new_arg[:default_value] unless new_arg[:choices].include?(new_arg[:default_value])
                    when "String"
                      new_arg[:default_value].gsub!(/"|'/, "")
                    when "Bool"
                      new_arg[:default_value] = new_arg[:default_value].downcase == "true" ? true : false
                    when "Integer"
                      new_arg[:default_value] = new_arg[:default_value].to_i
                    when "Double"
                      new_arg[:default_value] = new_arg[:default_value].to_f
                    else
                      raise "unknown variable type of #{new_arg[:variable_type]}"
                  end
                end

                measure_hash[:arguments] << new_arg
              end

              # create a new measure.json file for parsing later if need be
              File.open("#{measure_hash[:path]}/measure.json", 'w') { |f| f << JSON.pretty_generate(measure_hash) }

            end
          else
            puts "Problems downloading #{measure[:measure][:name]}...moving on"
          end
        end
      end
    end

    # retrieve measures for parsing metadata.
    # specify a search term to narrow down search or leave nil to retrieve all
    # set all_pages to true to iterate over all pages of results
    # can't specify filters other than the hard-coded bundle and show_rows
    def retrieve_measures(search_term = nil, filter_term=nil, return_all_pages = false, &block)
      #raise "Please login before performing this action" if @session.nil?

      #make sure filter_term includes bundle
      if filter_term.nil?
        filter_term = "fq[]=bundle%3Anrel_measure"
      elsif !filter_term.include? "bundle"
        filter_term = filter_term + "&fq[]=bundle%3Anrel_measure"
      end


      # use provided search term or nil.
      # if return_all_pages is true, iterate over pages of API results. Otherwise only return first 100
      results = search(search_term, filter_term, return_all_pages)
      puts "#{results[:result].count} results returned"

      results[:result].each do |result|
        puts "retrieving measure: #{result[:measure][:name]}"
        yield result
      end

    end

    # pushes component to the bcl and publishes them (if logged-in as BCL Website Admin user).
    # username and password set in ~/.bcl/config.yml file
    def push_content(filename_and_path, write_receipt_file, content_type)
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
                  "field_component_tags" => #TODO remove this field_component_tags once BCL is fixed
                      {
                          "und" => "1289"
                      },
                  "og_group_ref" =>
                      {
                          "und" =>
                              ["target_id" => @group_id],

                      },
                  "publish" => 1 #NOTE THIS ONLY WORKS IF YOU ARE A BCL SITE ADMIN
              }

      }
      #restclient not working
      #res = RestClient.post "#{@config[:server][:url]}/api/content.json", @data.to_json, :content_type => :json, :cookies => @session

      path = "/api/content.json"
      headers = {'Content-Type' => 'application/json', 'X-CSRF-Token' => @access_token, 'Cookie' => @session}


      res = @http.post(path, @data.to_json, headers)

      res_j = "could not get json from http post response"
      if res.code == '200'
        puts "200"
        res_j = MultiJson.load(res.body)
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

    def push_contents(array_of_components, skip_files_with_receipts, content_type)
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
          valid, res = push_content(comp, true, content_type)
          log_message += " #{valid} #{res.inspect.chomp}"
        end
        logs << log_message
      end

      logs
    end

    # pushes updated content to the bcl and publishes it (if logged-in as BCL Website Admin user).
    # username and password set in ~/.bcl/config.yml file
    def update_content(filename_and_path, write_receipt_file, uuid)
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
                  "field_component_tags" => #TODO remove this field_component_tags once BCL is fixed
                      {
                          "und" => "1289"
                      },
                  "og_group_ref" =>
                      {
                          "und" =>
                              ["target_id" => @group_id],
                      },
                  "publish" => 1 #NOTE THIS ONLY WORKS IF YOU ARE A BCL SITE ADMIN
              }
      }

      #restclient not working
      #res = RestClient.post "#{@config[:server][:url]}/api/content", @data.to_json, :content_type => :json, :cookies => @session, :accept => :json   

      path = "/api/content.json"
      headers = {'Content-Type' => 'application/json', 'Cookie' => @session, 'X-CSRF-Token' => @access_token}

      res = @http.post(path, @data.to_json, headers)

      res_j = "could not get json from http post response"
      if res.code == '200'
        res_j = MultiJson.load(res.body)
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

    def update_contents(array_of_components, skip_files_with_receipts)
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
            log_message = "ERROR: uuid not found for #{File.basename(comp)}"
            puts log_message
          else
            log_message = "pushing updated content #{File.basename(comp)}"
            puts log_message
            valid, res = update_content(comp, true, uuid)
            log_message += " #{valid} #{res.inspect.chomp}"
          end
        end
        logs << log_message
      end
      logs
    end

    # Simple method to search bcl and return the result as hash with symbols
    # If all = true, iterate over pages of results and return all
    # JSON ONLY
    def search(search_str=nil, filter_str=nil, all=false)
      full_url = "/api/search/"

      #add search term
      if !search_str.nil? and search_str != ""
        full_url = full_url + search_str
        #strip out xml in case it's included. make sure .json is included
        full_url = full_url.gsub('.xml', '')
        unless search_str.include? ".json"
          full_url = full_url + ".json"
        end
      else
        full_url = full_url + "*.json"
      end

      #add api_version
      if @api_version < 2.0
        puts "WARNING:  attempting to use search with api_version #{@api_version}. Use API v2.0 for this functionality."
      end
      full_url = full_url + "?api_version=#{@api_version}"

      #add filters
      if !filter_str.nil?
        #strip out api_version from filters, if included
        if filter_str.include? "api_version="
          filter_str = filter_str.gsub(/api_version=\d{1,}/, '')
          filter_str = filter_str.gsub(/&api_version=\d{1,}/, '')
        end
        full_url = full_url + "&" + filter_str
      end

      #simple search vs. all results
      if !all
        puts "search url: #{full_url}"
        res = @http.get(full_url)
        #return unparsed
        MultiJson.load(res.body, :symbolize_keys => true)
      else
        #iterate over result pages
        #modify filter_str for show_rows=200 for maximum returns
        if filter_str.include? "show_rows="
          full_url = full_url.gsub(/show_rows=\d{1,}/, "show_rows=200")
        else
          full_url = full_url + "&show_rows=200"
        end
        #make sure filter_str doesn't already have a page=x
        full_url.gsub(/page=\d{1,}/, '')

        pagecnt = 0
        continue = 1
        results = []
        while continue == 1
          #retrieve current page
          full_url_all = full_url + "&page=#{pagecnt}"
          puts "search url: #{full_url_all}"
          response = @http.get(full_url_all)
          #parse here so you can build results array
          res = MultiJson.load(response.body)

          if res["result"].count > 0
            pagecnt += 1
            res["result"].each do |r|
              results << r
            end
          else
            continue = 0
          end
        end
        #return unparsed b/c that is what is expected
        formatted_results = {"result" => results}
        results_to_return = MultiJson.load(formatted_results.to_json, :symbolize_keys => true)
      end
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

    def list_all_measures()
      json = search(nil, "fq[]=bundle%3Anrel_measure&show_rows=100")

      json
    end

    def download_component(uid)

      begin
        result = @http.get("/api/component/download?uids=#{uid}")
        puts "DOWNLOADING: /api/component/download?uids=#{uid}"
        #puts "RESULTS: #{result.inspect}"
        #puts "RESULTS BODY: #{result.body}"

        #look at response code
        if result.code == '200'
          puts "Download Successful"
          result.body ? result.body : nil
        else
          puts "Download fail. Error code #{result.code}"
          nil
        end

      rescue
        puts "Couldn't download uid(s): #{uid}...skipping"
        nil
      end

    end

    private

    def load_config()
      config_filename = File.expand_path("~/.bcl/config.yml")

      if File.exists?(config_filename)
        puts "loading config settings from #{config_filename}"
        @config = YAML.load_file(config_filename)
      else
        #location of template file
        FileUtils.mkdir_p(File.dirname(config_filename))
        File.open(config_filename, 'w') { |f| f << default_yaml.to_yaml }
        File.chmod(0600, config_filename)
        puts "******** Please fill in user credentials in #{config_filename} file if you need to upload data **********"
      end
    end

    def default_yaml
      settings = {
          :server => {
              :url => "https://bcl.nrel.gov",
              :user => {
                  :username => "ENTER_BCL_USERNAME",
                  :password => "ENTER_BCL_PASSWORD",
                  :group => "ENTER_GROUP_ID"
              }
          }
      }

      settings
    end
  end #class ComponentMethods


  # TODO make this extend the component_xml class (or create a super class around components)

  def BCL.gather_components(component_dir, chunk_size = 0, delete_previousgather = false, destination=nil)
    if destination.nil?
      @dest_filename = "components"
    else
      @dest_filename = destination
    end
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
