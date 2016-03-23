######################################################################
#  Copyright (c) 2008-2014, Alliance for Sustainable Energy.
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

     def login(username = nil, secret = nil, url = nil, group_id = nil)
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

      if username.nil? || secret.nil?
        # log in via cached credentials
        username = @config[:server][:user][:username]
        secret = @config[:server][:user][:secret]
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

      data = %({"username":"#{username}","secret":"#{secret}"})

      login_path = '/api/user/loginsso.json'
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
          if line =~ /BNES_SESS/
            bnes = line.match(/(BNES_SESS.*)/)[0]
          end
        end

        junkout.each do |line|
          if line =~ /BNI/
            bni = line.match(/(BNI.*)/)[0]
          end
        end

        # puts "DATA: #{data}"
        session_name = ''
        sessid = ''
        json = MultiJson.load(res.body)
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

    # retrieve, parse, and save metadata for BCL measures
    def measure_metadata(search_term = nil, filter_term = nil, return_all_pages = false)
      # setup results directory
      unless File.exist?(@parsed_measures_path)
        FileUtils.mkdir_p(@parsed_measures_path)
      end
      puts "...storing parsed metadata in #{@parsed_measures_path}"

      # retrieve measures
      puts "retrieving measures that match search_term: #{search_term.nil? ? 'nil' : search_term} and filters: #{filter_term.nil? ? 'nil' : filter_term}"
      measures = []
      retrieve_measures(search_term, filter_term, return_all_pages) do |m|
        begin
          r = parse_measure_metadata(m)
          measures << r if r
        rescue => e
          puts "[ERROR] Parsing measure #{e.message}:#{e.backtrace.join("\n")}"
        end
      end

      measures
    end

    # Read in an existing measure.rb file and extract the arguments.
    # TODO: deprecate the _measure_name. This is used in the openstudio analysis gem, so it has to be carefully removed or renamed
    def parse_measure_file(_measure_name, measure_filename)
      measure_hash = {}

      if File.exist? measure_filename
        # read in the measure file and extract some information
        measure_string = File.read(measure_filename)

        measure_hash[:classname] = measure_string.match(/class (.*) </)[1]
        measure_hash[:name] = measure_hash[:classname].to_underscore
        measure_hash[:display_name] = nil
        measure_hash[:display_name_titleized] = measure_hash[:name].titleize
        measure_hash[:display_name_from_measure] = nil

        if measure_string =~ /OpenStudio::Ruleset::WorkspaceUserScript/
          measure_hash[:measure_type] = 'EnergyPlusMeasure'
        elsif measure_string =~ /OpenStudio::Ruleset::ModelUserScript/
          measure_hash[:measure_type] = 'RubyMeasure'
        elsif measure_string =~ /OpenStudio::Ruleset::ReportingUserScript/
          measure_hash[:measure_type] = 'ReportingMeasure'
        elsif measure_string =~ /OpenStudio::Ruleset::UtilityUserScript/
          measure_hash[:measure_type] = 'UtilityUserScript'
        else
          fail "measure type is unknown with an inherited class in #{measure_filename}: #{measure_hash.inspect}"
        end

        # New versions of measures have name, description, and modeler description methods
        n = measure_string.scan(/def name(.*?)end/m).first
        if n
          n = n.first.strip
          n.gsub!('return', '')
          n.gsub!(/"|'/, '')
          n.strip!
          measure_hash[:display_name_from_measure] = n
        end

        # New versions of measures have name, description, and modeler description methods
        n = measure_string.scan(/def description(.*?)end/m).first
        if n
          n = n.first.strip
          n.gsub!('return', '')
          n.gsub!(/"|'/, '')
          n.strip!
          measure_hash[:description] = n
        end

        # New versions of measures have name, description, and modeler description methods
        n = measure_string.scan(/def modeler_description(.*?)end/m).first
        if n
          n = n.first.strip
          n.gsub!('return', '')
          n.gsub!(/"|'/, '')
          n.strip!
          measure_hash[:modeler_description] = n
        end

        measure_hash[:arguments] = []

        args = measure_string.scan(/(.*).*=.*OpenStudio::Ruleset::OSArgument.*make(.*)Argument\((.*).*\)/)
        args.each do |arg|
          new_arg = {}
          new_arg[:name] = nil
          new_arg[:display_name] = nil
          new_arg[:variable_type] = nil
          new_arg[:local_variable] = nil
          new_arg[:units] = nil
          new_arg[:units_in_name] = nil

          new_arg[:local_variable] = arg[0].strip
          new_arg[:variable_type] = arg[1]
          arg_params = arg[2].split(',')
          new_arg[:name] = arg_params[0].gsub(/"|'/, '')
          next if new_arg[:name] == 'info_widget'
          choice_vector = arg_params[1] ? arg_params[1].strip : nil

          # try find the display name of the argument
          reg = /#{new_arg[:local_variable]}.setDisplayName\((.*)\)/
          if measure_string =~ reg
            new_arg[:display_name] = measure_string.match(reg)[1]
            new_arg[:display_name].gsub!(/"|'/, '') if new_arg[:display_name]
          else
            new_arg[:display_name] = new_arg[:name]
          end

          p = parse_measure_name(new_arg[:display_name])
          new_arg[:display_name] = p[0]
          new_arg[:units_in_name] = p[1]

          # try to get the units
          reg = /#{new_arg[:local_variable]}.setUnits\((.*)\)/
          if measure_string =~ reg
            new_arg[:units] = measure_string.match(reg)[1]
            new_arg[:units].gsub!(/"|'/, '') if new_arg[:units]
          end

          if measure_string =~ /#{new_arg[:local_variable]}.setDefaultValue/
            new_arg[:default_value] = measure_string.match(/#{new_arg[:local_variable]}.setDefaultValue\((.*)\)/)[1]
          else
            puts "[WARNING] #{measure_hash[:name]}:#{new_arg[:name]} has no default value... will continue"
          end

          case new_arg[:variable_type]
            when 'Choice'
              # Choices to appear to only be strings?
              # puts "Choice vector appears to be #{choice_vector}"
              new_arg[:default_value].gsub!(/"|'/, '') if new_arg[:default_value]

              # parse the choices from the measure
              # scan from where the "instance has been created to the measure"
              possible_choices = nil
              possible_choice_block = measure_string # .scan(/#{choice_vector}.*=(.*)#{new_arg[:local_variable]}.*=/mi)
              if possible_choice_block
                # puts "possible_choice_block is #{possible_choice_block}"
                possible_choices = possible_choice_block.scan(/#{choice_vector}.*<<.*(')(.*)(')/)
                possible_choices += possible_choice_block.scan(/#{choice_vector}.*<<.*(")(.*)(")/)
              end

              # puts "Possible choices are #{possible_choices}"

              if possible_choices.nil? || possible_choices.empty?
                new_arg[:choices] = []
              else
                new_arg[:choices] = possible_choices.map { |c| c[1] }
              end

              # if the choices are inherited from the model, then need to just display the default value which
              # somehow magically works because that is the display name
              if new_arg[:default_value]
                new_arg[:choices] << new_arg[:default_value] unless new_arg[:choices].include?(new_arg[:default_value])
              end
            when 'String', 'Path'
              new_arg[:default_value].gsub!(/"|'/, '') if new_arg[:default_value]
            when 'Bool'
              if new_arg[:default_value]
                new_arg[:default_value] = new_arg[:default_value].downcase == 'true' ? true : false
              end
            when 'Integer'
              new_arg[:default_value] = new_arg[:default_value].to_i if new_arg[:default_value]
            when 'Double'
              new_arg[:default_value] = new_arg[:default_value].to_f if new_arg[:default_value]
            else
              fail "unknown variable type of #{new_arg[:variable_type]}"
          end

          measure_hash[:arguments] << new_arg
        end
      end

      # check if there is a measure.xml file?
      measure_xml_filename = "#{File.join(File.dirname(measure_filename), File.basename(measure_filename, '.*'))}.xml"
      if File.exist? measure_xml_filename
        f = File.open measure_xml_filename
        doc = Nokogiri::XML(f)

        # pull out some information
        measure_hash[:name_xml] = doc.xpath('/measure/name').first.content
        measure_hash[:uid] = doc.xpath('/measure/uid').first.content
        measure_hash[:version_id] = doc.xpath('/measure/version_id').first.content
        measure_hash[:tags] = doc.xpath('/measure/tags/tag').map(&:content)

        measure_hash[:modeler_description_xml] = doc.xpath('/measure/modeler_description').first.content

        measure_hash[:description_xml] = doc.xpath('/measure/description').first.content

        f.close
      end

      # validate the measure information

      validate_measure_hash(measure_hash)

      measure_hash
    end

    # Validate the measure hash to make sure that it is meets the style guide. This will also perform the selection
    # of which data to use for the "actual metadata"
    #
    # @param h [Hash] Measure hash
    def validate_measure_hash(h)
      if h.key? :name_xml
        if h[:name_xml] != h[:name]
          puts "[ERROR] {Validation}. Snake-cased name and the name in the XML do not match. Will default to automatic snake-cased measure name. #{h[:name_xml]} <> #{h[:name]}"
        end
      end

      puts '[WARNING] {Validation} Could not find measure description in measure.'  unless h[:description]
      puts '[WARNING] {Validation} Could not find modeler description in measure.'  unless h[:modeler_description]
      puts '[WARNING] {Validation} Could not find measure name method in measure.'  unless h[:name_from_measure]

      # check the naming conventions
      if h[:display_name_from_measure]
        if h[:display_name_from_measure] != h[:display_name_titleized]
          puts '[WARNING] {Validation} Display name from measure and automated naming do not match. Will default to the automated name until all measures use the name method because of potential conflicts due to bad copy/pasting.'
        end
        h[:display_name] = h.delete :display_name_titleized
      else
        h[:display_name] = h.delete :display_name_titleized
      end
      h.delete :display_name_from_measure

      if h.key?(:description) && h.key?(:description_xml)
        if h[:description] != h[:description_xml]
          puts '[ERROR] {Validation} Measure description and XML description differ. Will default to description in measure'
        end
        h.delete(:description_xml)
      end

      if h.key?(:modeler_description) && h.key?(:modeler_description_xml)
        if h[:modeler_description] != h[:modeler_description_xml]
          puts '[ERROR] {Validation} Measure modeler description and XML modeler description differ. Will default to modeler description in measure'
        end
        h.delete(:modeler_description_xml)
      end

      h[:arguments].each do |arg|
        if arg[:units_in_name]
          puts "[ERROR] {Validation} It appears that units are embedded in the argument name for #{arg[:name]}."

          if arg[:units]
            if arg[:units] != arg[:units_in_name]
              puts '[ERROR] {Validation} Units in argument name do not match units in setUnits method. Using setUnits.'
              arg.delete :units_in_name
            end
          else
            puts '[ERROR] {Validation} Units appear to be in measure name. Please use setUnits.'
            arg[:units] = arg.delete :units_in_name
          end
        else
          # make sure to delete if null
          arg.delete :units_in_name
        end
      end
    end

    def translate_measure_hash_to_csv(measure_hash)
      csv = []
      csv << [false, measure_hash[:display_name], measure_hash[:classname], measure_hash[:classname], measure_hash[:measure_type]]

      measure_hash[:arguments].each do |argument|
        values = []
        values << ''
        values << 'argument'
        values << ''
        values << argument[:display_name]
        values << argument[:name]
        values << argument[:display_name] # this is the default short display name
        values << argument[:variable_type]
        values << argument[:units]

        # watch out because :default_value can be a boolean
        argument[:default_value].nil? ? values << '' : values << argument[:default_value]
        choices = ''
        if argument[:choices]
          choices << "|#{argument[:choices].join(',')}|" unless argument[:choices].empty?
        end
        values << choices

        csv << values
      end

      csv
    end

    # Read the measure's information to pull out the metadata and to move into a more friendly directory name.
    # argument of measure is a hash
    def parse_measure_metadata(measure)
      m_result = nil
      # check for valid measure
      if measure[:measure][:name] && measure[:measure][:uuid]

        file_data = download_component(measure[:measure][:uuid])

        if file_data
          save_file = File.expand_path("#{@parsed_measures_path}/#{measure[:measure][:name].downcase.gsub(' ', '_')}.zip")
          File.open(save_file, 'wb') { |f| f << file_data }

          # unzip file and delete zip.
          # TODO: check that something was downloaded here before extracting zip
          if File.exist? save_file
            BCL.extract_zip(save_file, @parsed_measures_path, true)

            # catch a weird case where there is an extra space in an unzip file structure but not in the measure.name
            if measure[:measure][:name] == 'Add Daylight Sensor at Center of Spaces with a Specified Space Type Assigned'
              unless File.exist? "#{@parsed_measures_path}/#{measure[:measure][:name]}"
                temp_dir_name = "#{@parsed_measures_path}/Add Daylight Sensor at Center of  Spaces with a Specified Space Type Assigned"
                FileUtils.move(temp_dir_name, "#{@parsed_measures_path}/#{measure[:measure][:name]}")
              end
            end

            temp_dir_name = File.join(@parsed_measures_path, measure[:measure][:name])

            # Read the measure.rb file
            # puts "save dir name #{temp_dir_name}"
            measure_filename = "#{temp_dir_name}/measure.rb"
            measure_hash = parse_measure_file(nil, measure_filename)

            if measure_hash.empty?
              puts 'Measure Hash was empty... moving on'
            else
              # puts measure_hash.inspect
              m_result = measure_hash
              # move the directory to the class name
              new_dir_name = File.join(@parsed_measures_path, measure_hash[:classname])
              # puts "Moving #{temp_dir_name} to #{new_dir_name}"
              if temp_dir_name == new_dir_name
                puts 'Destination directory is the same as the processed directory'
              else
                FileUtils.rm_rf(new_dir_name) if File.exist?(new_dir_name) && temp_dir_name != measure_hash[:classname]
                FileUtils.move(temp_dir_name, new_dir_name) unless temp_dir_name == measure_hash[:classname]
              end
              # create a new measure.json file for parsing later if need be
              File.open(File.join(new_dir_name, 'measure.json'), 'w') { |f| f << MultiJson.dump(measure_hash, pretty: true) }
            end
          else
            puts "Problems downloading #{measure[:measure][:name]}... moving on"
          end
        end
      end

      m_result
    end

    # parse measure name
    def parse_measure_name(name)
      # TODO: save/display errors
      errors = ''
      m = nil

      clean_name = name
      units = nil

      # remove everything btw parentheses
      m = clean_name.match(/\((.+?)\)/)
      unless m.nil?
        errors += ' removing parentheses,'
        units = m[1]
        clean_name = clean_name.gsub(/\((.+?)\)/, '')
      end

      # remove everything btw brackets
      m = nil
      m = clean_name.match(/\[(.+?)\]/)
      unless m.nil?
        errors += ' removing brackets,'
        clean_name = clean_name.gsub(/\[(.+?)\]/, '')
      end

      # remove characters
      m = nil
      m = clean_name.match(/(\?|\.|\#).+?/)
      unless m.nil?
        errors += ' removing any of following: ?.#'
        clean_name = clean_name.gsub(/(\?|\.|\#).+?/, '')
      end
      clean_name = clean_name.gsub('.', '')
      clean_name = clean_name.gsub('?', '')

      [clean_name.strip, units]
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
          puts "  Response Code: #{api_response.code} - #{api_response.body}"
          if api_response.body.empty?
            puts '  200 BUT ERROR: Returned body was empty. Possible causes:'
            puts '      - BSD tar on Mac OSX vs gnutar'
            result = { error: 'returned 200, but returned body was empty' }
            valid = false
          else
            puts '  200 - Successful Upload'
            result = MultiJson.load api_response.body
            valid = true
          end
        when '404'
          puts "  Response: #{api_response.code} - #{api_response.body}"
          puts '  404 - check these common causes first:'
          puts '    - the filename contains periods (other than the ones before the file extension)'
          puts "    - you are not an 'administrator member' of the group you're trying to upload to"
          result = MultiJson.load api_response.body
          valid = false
        when '406'
          puts "  Response: #{api_response.code} - #{api_response.body}"
          puts '  406 - check these common causes first:'
          puts '    - the UUID of the item that you are uploading is already on the BCL'
          puts '    - the group_id is not correct in the config.yml (go to group on site, and copy the number at the end of the URL)'
          puts "    - you are not an 'administrator member' of the group you're trying to upload to"
          result = MultiJson.load api_response.body
          valid = false
        when '500'
          puts "  Response: #{api_response.code} - #{api_response.body}"
          fail 'server exception'
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
    # username, secret, and group_id are set in the ~/.bcl/config.yml file
    def push_content(filename_and_path, write_receipt_file, content_type)
      fail 'Please login before pushing components' if @session.nil?
      fail 'Do not have a valid access token; try again' if @access_token.nil?

      data = construct_post_data(filename_and_path, false, content_type)

      path = '/api/content.json'
      headers = { 'Content-Type' => 'application/json', 'X-CSRF-Token' => @access_token, 'Cookie' => @session }

      res = @http.post(path, MultiJson.dump(data), headers)

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
    # username and secret set in ~/.bcl/config.yml file
    def update_content(filename_and_path, write_receipt_file, uuid = nil)
      fail 'Please login before pushing components' unless @session

      # get the UUID if zip or xml file
      version_id = nil
      if uuid.nil?
        puts File.extname(filename_and_path).downcase
        if filename_and_path =~ /^.*.tar.gz$/i
          uuid, version_id = uuid_vid_from_tarball(filename_and_path)
          puts "Parsed uuid out of tar.gz file with value #{uuid}"
        end
      else
        # verify the uuid via regex
        unless uuid =~ /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
          fail "uuid of #{uuid} is invalid"
        end
      end
      fail 'Please pass in a tar.gz file or pass in the uuid' unless uuid

      data = construct_post_data(filename_and_path, true, uuid)

      path = '/api/content.json'
      headers = { 'Content-Type' => 'application/json', 'X-CSRF-Token' => @access_token, 'Cookie' => @session }

      res = @http.post(path, MultiJson.dump(data), headers)

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

      fail "File does not exist #{path_to_tarball}" unless File.exist? path_to_tarball
      tgz = Zlib::GzipReader.open(path_to_tarball)
      Archive::Tar::Minitar::Reader.open(tgz).each do |entry|
        # If taring with tar zcf ameasure.tar.gz -C measure_dir .
        if entry.name =~ /^.{0,2}component.xml$/ || entry.name =~ /^.{0,2}measure.xml$/
          xml_file = Nokogiri::XML(entry.read)

          # pull out some information
          if entry.name =~ /component/
            u = xml_file.xpath('/component/uid').first
            v = xml_file.xpath('/component/version_id').first
          else
            u = xml_file.xpath('/measure/uid').first
            v = xml_file.xpath('/measure/version_id').first
          end
          fail "Could not find UUID in XML file #{path_to_tarball}" unless u
          # Don't error on version not existing.

          uuid = u.content
          vid = v ? v.content : nil

          # puts "uuid = #{uuid}; vid = #{vid}"
        end
      end

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
        MultiJson.load(res.body, symbolize_keys: true)
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
          res = MultiJson.load(response.body)

          if res['result'].count > 0
            pagecnt += 1
            res['result'].each do |r|
              results << r
            end
          else
            continue = 0
          end
        end
        # return unparsed b/c that is what is expected
        formatted_results = { 'result' => results }
        results_to_return = MultiJson.load(MultiJson.dump(formatted_results), symbolize_keys: true)
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
        result.body ? result.body : nil
      else
        puts "Download fail. Error code #{result.code}"
        nil
      end
    rescue
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
        File.chmod(0600, config_filename)
        puts "******** Please fill in user credentials in #{config_filename} file if you need to upload data **********"
      end
    end

    def default_yaml
      settings = {
        server: {
          url: 'https://bcl.nrel.gov',
          user: {
            username: 'ENTER_BCL_USERNAME',
            secret: 'ENTER_BCL_SECRET',
            group: 'ENTER_GROUP_ID'
          }
        }
      }

      settings
    end
  end # class ComponentMethods

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
end # module BCL
