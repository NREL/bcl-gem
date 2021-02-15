######################################################################
#  Copyright (c) 2008-2021, Alliance for Sustainable Energy.
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

module BCL
  class ComponentMethods
    attr_accessor :config
    attr_accessor :parsed_measures_path
    attr_reader :session
    attr_reader :http
    attr_reader :logged_in

    def initialize
      @parsed_measures_path = './measures/parsed'
      @config = nil
      @session = nil
      @access_token = nil
      @http = nil
      @api_version = 2.0
      @group_id = nil
      @logged_in = false

      load_config
    end

    def login(username = nil, password = nil, url = nil, group_id = nil)
      # figure out what url to use
      if url.nil?
        url = @config[:server][:url]
      end
      # look for http vs. https
      if url.include? 'https'
        port = 443
      else
        port = 80
      end
      # strip out http(s)
      url = url.gsub('http://', '')
      url = url.gsub('https://', '')

      if username.nil? || password.nil?
        # log in via cached credentials
        username = @config[:server][:user][:username]
        password = @config[:server][:user][:password]
        @group_id = group_id || @config[:server][:user][:group]
        puts "logging in using credentials in .bcl/config.yml: Connecting to #{url} on port #{port} as #{username} with group #{@group_id}"
      else
        @group_id = group_id || @config[:server][:user][:group]
        puts "logging in using credentials in function arguments: Connecting to #{url} on port #{port} as #{username} with group #{@group_id}"
      end

      if @group_id.nil?
        puts '[WARNING] You did not set a group ID in your config.yml file or pass in a group ID. You can retrieve your group ID from the node number of your group page (e.g., https://bcl.nrel.gov/node/32). Will continue, but you will not be able to upload content.'
      end

      @http = Net::HTTP.new(url, port)
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if port == 443
        @http.use_ssl = true
      end

      data = %({"username":"#{username}","password":"#{password}"})

      login_path = '/api/user/login.json'
      headers = { 'Content-Type' => 'application/json' }

      res = @http.post(login_path, data, headers)

      # for debugging:
      # res.each do |key, value|
      #  puts "#{key}: #{value}"
      # end

      if res.code == '200'
        puts 'Login Successful'

        bnes = ''
        bni = ''
        junkout = res['set-cookie'].split(';')
        junkout.each do |line|
          if line.match?(/BNES_SESS/)
            bnes = line.match(/(BNES_SESS.*)/)[0]
          end
        end

        junkout.each do |line|
          if line.match?(/BNI/)
            bni = line.match(/(BNI.*)/)[0]
          end
        end

        # puts "DATA: #{data}"
        session_name = ''
        sessid = ''
        json = JSON.parse(res.body)
        json.each do |key, val|
          if key == 'session_name'
            session_name = val
          elsif key == 'sessid'
            sessid = val
          end
        end

        @session = session_name + '=' + sessid + ';' + bni + ';' + bnes

        # get access token
        token_path = '/services/session/token'
        token_headers = { 'Content-Type' => 'application/json', 'Cookie' => @session }
        # puts "token_headers = #{token_headers.inspect}"
        access_token = @http.post(token_path, '', token_headers)
        if access_token.code == '200'
          @access_token = access_token.body
        else
          puts 'Unable to get access token; uploads will not work'
          puts "error code: #{access_token.code}"
          puts "error info: #{access_token.body}"
        end

        # puts "access_token = *#{@access_token}*"
        # puts "cookie = #{@session}"

        res
      else

        puts "error code: #{res.code}"
        puts "error info: #{res.body}"
        puts 'continuing as unauthenticated sessions (you can still search and download)'

        res
      end
    end

    # retrieve measures for parsing metadata.
    # specify a search term to narrow down search or leave nil to retrieve all
    # set all_pages to true to iterate over all pages of results
    # can't specify filters other than the hard-coded bundle and show_rows
    def retrieve_measures(search_term = nil, filter_term = nil, return_all_pages = false, &_block)
      # raise "Please login before performing this action" if @session.nil?

      # make sure filter_term includes bundle
      if filter_term.nil?
        filter_term = 'fq[]=bundle%3Anrel_measure'
      elsif !filter_term.include? 'bundle'
        filter_term += '&fq[]=bundle%3Anrel_measure'
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

    # evaluate the response from the API in a consistent manner
    def evaluate_api_response(api_response)
      valid = false
      result = { error: 'could not get json from http post response' }
      case api_response.code
        when '200'
          puts "  Response Code: #{api_response.code}"
          if api_response.body.empty?
            puts '  200 BUT ERROR: Returned body was empty. Possible causes:'
            puts '      - BSD tar on Mac OSX vs gnutar'
            result = { error: 'returned 200, but returned body was empty' }
            valid = false
          else
            puts '  200 - Successful Upload'
            result = JSON.parse api_response.body
            valid = true
          end
        when '404'
          puts "  Error Code: #{api_response.code} - #{api_response.body}"
          puts '   - check these common causes first:'
          puts "     - you are trying to update content that doesn't exist"
          puts "     - you are not an 'administrator member' of the group you're trying to upload to"
          result = JSON.parse api_response.body
          valid = false
        when '406'
          puts "  Error Code: #{api_response.code}"
          # try to parse the response a bit
          error = JSON.parse api_response.body
          puts "temp error: #{error}"
          if error.key?('form_errors')
            if error['form_errors'].key?('field_tar_file')
              result = { error: error['form_errors']['field_tar_file'] }
            elsif error['form_errors'].key?('og_group_ref][und][0][default')
              result = { error: error['form_errors']['og_group_ref][und][0][default'] }
            end
          else
            result = error
          end
          valid = false
        when '500'
          puts "  Error Code: #{api_response.code}"
          result = { error: api_response.message }
          # fail 'server exception'
          valid = false
        else
          puts "  Response: #{api_response.code} - #{api_response.body}"
          valid = false
      end

      [valid, result]
    end

    # Construct the post parameter for the API content.json end point.
    # param(@update) is a boolean that triggers whether to use content_type or uuid
    def construct_post_data(filepath, update, content_type_or_uuid)
      # TODO: remove special characters in the filename; they create firewall errors
      # filename = filename.gsub(/\W/,'_').gsub(/___/,'_').gsub(/__/,'_').chomp('_').strip

      file_b64 = Base64.encode64(File.binread(filepath))

      data = {}
      data['file'] = {
        'file' => file_b64,
        'filesize' => File.size(filepath).to_s,
        'filename' => File.basename(filepath)
      }

      data['node'] = {}

      # Only include the content type if this is an update
      if update
        data['node']['uuid'] = content_type_or_uuid
      else
        data['node']['type'] = content_type_or_uuid
      end

      # TODO: remove this field_component_tags once BCL is fixed
      data['node']['field_component_tags'] = { 'und' => '1289' }
      data['node']['og_group_ref'] = { 'und' => ['target_id' => @group_id] }

      # NOTE THIS ONLY WORKS IF YOU ARE A BCL SITE ADMIN
      data['node']['publish'] = '1'

      data
    end

    # pushes component to the bcl and publishes them (if logged-in as BCL Website Admin user).
    # username, password, and group_id are set in the ~/.bcl/config.yml file
    def push_content(filename_and_path, write_receipt_file, content_type)
      raise 'Please login before pushing components' if @session.nil?
      raise 'Do not have a valid access token; try again' if @access_token.nil?

      data = construct_post_data(filename_and_path, false, content_type)

      path = '/api/content.json'
      headers = { 'Content-Type' => 'application/json', 'X-CSRF-Token' => @access_token, 'Cookie' => @session }

      res = @http.post(path, JSON.dump(data), headers)

      valid, json = evaluate_api_response(res)

      if valid
        # write out a receipt file into the same directory of the component with the same file name as
        # the component
        if write_receipt_file
          File.open("#{File.dirname(filename_and_path)}/#{File.basename(filename_and_path, '.tar.gz')}.receipt", 'w') do |file|
            file << Time.now.to_s
          end
        end
      end

      [valid, json]
    end

    # pushes updated content to the bcl and publishes it (if logged-in as BCL Website Admin user).
    # username and password set in ~/.bcl/config.yml file
    def update_content(filename_and_path, write_receipt_file, uuid = nil)
      raise 'Please login before pushing components' unless @session

      # get the UUID if zip or xml file
      version_id = nil
      if uuid.nil?
        puts File.extname(filename_and_path).downcase
        if filename_and_path.match?(/^.*.tar.gz$/i)
          uuid, version_id = uuid_vid_from_tarball(filename_and_path)
          puts "Parsed uuid out of tar.gz file with value #{uuid}"
        end
      else
        # verify the uuid via regex
        unless uuid.match?(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
          raise "uuid of #{uuid} is invalid"
        end
      end
      raise 'Please pass in a tar.gz file or pass in the uuid' unless uuid

      data = construct_post_data(filename_and_path, true, uuid)

      path = '/api/content.json'
      headers = { 'Content-Type' => 'application/json', 'X-CSRF-Token' => @access_token, 'Cookie' => @session }

      res = @http.post(path, JSON.dump(data), headers)

      valid, json = evaluate_api_response(res)

      if valid
        # write out a receipt file into the same directory of the component with the same file name as
        # the component
        if write_receipt_file
          File.open("#{File.dirname(filename_and_path)}/#{File.basename(filename_and_path, '.tar.gz')}.receipt", 'w') do |file|
            file << Time.now.to_s
          end
        end
      end

      [valid, json]
    end

    def push_contents(array_of_components, skip_files_with_receipts, content_type)
      logs = []
      array_of_components.each do |comp|
        receipt_file = File.dirname(comp) + '/' + File.basename(comp, '.tar.gz') + '.receipt'
        log_message = ''
        if skip_files_with_receipts && File.exist?(receipt_file)
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

    # Unpack the tarball in memory and extract the XML file to read the UUID and Version ID
    def uuid_vid_from_tarball(path_to_tarball)
      uuid = nil
      vid = nil

      raise "File does not exist #{path_to_tarball}" unless File.exist? path_to_tarball

      tgz = Zlib::GzipReader.open(path_to_tarball)
      Archive::Tar::Minitar::Reader.open(tgz).each do |entry|
        # If taring with tar zcf ameasure.tar.gz -C measure_dir .
        if entry.name =~ /^.{0,2}component.xml$/ || entry.name =~ /^.{0,2}measure.xml$/
          # xml_to_parse = File.new( entry.read )
          xml_file = REXML::Document.new entry.read

          # pull out some information
          if entry.name.match?(/component/)
            u = xml_file.elements['component/uid']
            v = xml_file.elements['component/version_id']
          else
            u = xml_file.elements['measure/uid']
            v = xml_file.elements['measure/version_id']
          end
          raise "Could not find UUID in XML file #{path_to_tarball}" unless u

          # Don't error on version not existing.

          uuid = u.text
          vid = v ? v.text : nil

          # puts "uuid = #{uuid}; vid = #{vid}"
        end
      end

      [uuid, vid]
    end

    def uuid_vid_from_xml(path_to_xml)
      uuid = nil
      vid = nil

      raise "File does not exist #{path_to_xml}" unless File.exist? path_to_xml

      xml_to_parse = File.new(path_to_xml)
      xml_file = REXML::Document.new xml_to_parse

      if path_to_xml.to_s.split('/').last.match?(/component.xml/)
        u = xml_file.elements['component/uid']
        v = xml_file.elements['component/version_id']
      else
        u = xml_file.elements['measure/uid']
        v = xml_file.elements['measure/version_id']
      end
      raise "Could not find UUID in XML file #{path_to_tarball}" unless u

      uuid = u.text
      vid = v ? v.text : nil
      [uuid, vid]
    end

    def update_contents(array_of_tarball_components, skip_files_with_receipts)
      logs = []
      array_of_tarball_components.each do |comp|
        receipt_file = File.dirname(comp) + '/' + File.basename(comp, '.tar.gz') + '.receipt'
        log_message = ''
        if skip_files_with_receipts && File.exist?(receipt_file)
          log_message = "skipping update because found receipt #{File.basename(comp)}"
          puts log_message
        else
          uuid, vid = uuid_vid_from_tarball(comp)
          if uuid.nil?
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

    def search_by_uuid(uuid, vid = nil)
      full_url = '/api/search.json'
      action = nil

      # add api_version
      if @api_version < 2.0
        puts "WARNING:  attempting to use search with api_version #{@api_version}. Use API v2.0 for this functionality."
      end
      full_url += "?api_version=#{@api_version}"

      # uuid
      full_url += "&fq[]=ss_uuid:#{uuid}"

      res = @http.get(full_url)
      res = JSON.parse res.body

      if res['result'].count > 0
        # found content, check version
        content = res['result'].first
        # puts "first result: #{content}"

        # parse out measure vs component
        if content['measure']
          content = content['measure']
        else
          content = content['component']
        end

        # TODO: check version_modified date if it exists?
        if !vid.nil? && content['vuuid'] == vid
          # no update needed
          action = 'noop'
        else
          # vid doesn't match: update existing
          action = 'update'
        end
      else
        # no uuid found: push new
        action = 'push'
      end
      action
    end

    # Simple method to search bcl and return the result as hash with symbols
    # If all = true, iterate over pages of results and return all
    # JSON ONLY
    def search(search_str = nil, filter_str = nil, all = false)
      full_url = '/api/search/'

      # add search term
      if !search_str.nil? && search_str != ''
        full_url += search_str
        # strip out xml in case it's included. make sure .json is included
        full_url = full_url.gsub('.xml', '')
        unless search_str.include? '.json'
          full_url += '.json'
        end
      else
        full_url += '*.json'
      end

      # add api_version
      if @api_version < 2.0
        puts "WARNING:  attempting to use search with api_version #{@api_version}. Use API v2.0 for this functionality."
      end
      full_url += "?api_version=#{@api_version}"

      # add filters
      unless filter_str.nil?
        # strip out api_version from filters, if included
        if filter_str.include? 'api_version='
          filter_str = filter_str.gsub(/api_version=\d{1,}/, '')
          filter_str = filter_str.gsub(/&api_version=\d{1,}/, '')
        end
        full_url = full_url + '&' + filter_str
      end

      # simple search vs. all results
      if !all
        puts "search url: #{full_url}"
        res = @http.get(full_url)
        # return unparsed
        JSON.parse res.body, symbolize_names: true
      else
        # iterate over result pages
        # modify filter_str for show_rows=200 for maximum returns
        if filter_str.include? 'show_rows='
          full_url = full_url.gsub(/show_rows=\d{1,}/, 'show_rows=200')
        else
          full_url += '&show_rows=200'
        end
        # make sure filter_str doesn't already have a page=x
        full_url.gsub(/page=\d{1,}/, '')

        pagecnt = 0
        continue = 1
        results = []
        while continue == 1
          # retrieve current page
          full_url_all = full_url + "&page=#{pagecnt}"
          puts "search url: #{full_url_all}"
          response = @http.get(full_url_all)
          # parse here so you can build results array
          res = JSON.parse response.body, symbolize_names: true

          if res[:result].count > 0
            pagecnt += 1
            res[:result].each do |r|
              results << r
            end
          else
            continue = 0
          end
        end
        # return unparsed b/c that is what is expected
        return { result: results }
      end
    end

    # Delete receipt files
    def delete_receipts(array_of_components)
      array_of_components.each do |comp|
        receipt_file = File.dirname(comp) + '/' + File.basename(comp, '.tar.gz') + '.receipt'
        if File.exist?(receipt_file)
          FileUtils.remove_file(receipt_file)

        end
      end
    end

    def list_all_measures
      json = search(nil, 'fq[]=bundle%3Anrel_measure&show_rows=100')

      json
    end

    def download_component(uid)
      result = @http.get("/api/component/download?uids=#{uid}")
      puts "Downloading: http://#{@http.address}/api/component/download?uids=#{uid}"
      # puts "RESULTS: #{result.inspect}"
      # puts "RESULTS BODY: #{result.body}"
      # look at response code
      if result.code == '200'
        # puts 'Download Successful'
        result.body || nil
      else
        puts "Download fail. Error code #{result.code}"
        nil
      end
    rescue StandardError
      puts "Couldn't download uid(s): #{uid}...skipping"
      nil
    end

    private

    def load_config
      config_filename = File.expand_path('~/.bcl/config.yml')

      if File.exist?(config_filename)
        puts "loading config settings from #{config_filename}"
        @config = YAML.load_file(config_filename)
      else
        # location of template file
        FileUtils.mkdir_p(File.dirname(config_filename))
        File.open(config_filename, 'w') { |f| f << default_yaml.to_yaml }
        File.chmod(0o600, config_filename)
        puts "******** Please fill in user credentials in #{config_filename} file if you need to upload data **********"
        # fill in the @config data with the temporary data for now.
        @config = YAML.load_file(config_filename)
      end
    end

    def default_yaml
      settings = {
        server: {
          url: 'https://bcl.nrel.gov',
          user: {
            username: 'ENTER_BCL_USERNAME',
            password: 'ENTER_BCL_PASSWORD',
            group: 'ENTER_GROUP_ID'
          }
        }
      }

      settings
    end
  end

  # TODO: make this extend the component_xml class (or create a super class around components)

  def self.gather_components(component_dir, chunk_size = 0, delete_previousgather = false, destination = nil)
    if destination.nil?
      @dest_filename = 'components'
    else
      @dest_filename = destination
    end
    @dest_file_ext = 'tar.gz'

    # store the starting directory
    current_dir = Dir.pwd

    # an array to hold reporting info about the batches
    gather_components_report = []

    # go to the directory containing the components
    Dir.chdir(component_dir)

    # delete any old versions of the component chunks
    FileUtils.rm_rf('./gather') if delete_previousgather

    # gather all the components into array
    targzs = Pathname.glob('./**/*.tar.gz')
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
      # puts "copying #{targz.to_s} to #{destination_file}"
      FileUtils.cp(targz.to_s, destination_file)
    end

    # gather all the .tar.gz files into a single tar.gz
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

      # move the tarball back a directory
      FileUtils.move("./gather/#{cnt}/#{destination}", "./gather/#{destination}")
    end

    Dir.chdir(current_dir)
  end
end
