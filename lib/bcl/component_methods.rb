# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

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
      @http = nil
      @api_version = nil

      # load configs from file or default
      load_config

      # configure connection
      url = @config[:server][:url]
      # look for http vs. https
      if url.include? 'https'
        port = 443
      else
        port = 80
      end

      # strip out http(s)
      url = url.gsub('http://', '')
      url = url.gsub('https://', '')

      @http = Net::HTTP.new(url, port)
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if port == 443
        @http.use_ssl = true
      end

      puts "Connecting to BCL at URL: #{@config[:server][:url]}"
    end

    # retrieve measures for parsing metadata.
    # specify a search term to narrow down search or leave nil to retrieve all
    # set all_pages to true to iterate over all pages of results
    # can't specify filters other than the hard-coded bundle and show_rows
    def retrieve_measures(search_term = nil, filter_term = nil, return_all_pages = false, &_block)
      # raise "Please login before performing this action" if @session.nil?

      # make sure filter_term includes bundle
      if @api_version == 2.0
        if filter_term.nil?
          filter_term = 'fq[]=bundle%3Anrel_measure'
        elsif !filter_term.include? 'bundle'
          filter_term += '&fq[]=bundle%3Anrel_measure'
        end
      else
        if filter_term.nil?
          filter_term = 'fq=bundle%3Ameasure'
        elsif !filter_term.include? 'bundle'
          filter_term += '&fq=bundle%3Ameasure'
        end
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

    def search_by_uuid(uuid, vid = nil)
      full_url = '/api/search.json'

      # add api_version
      if @api_version == 2.0
        # uuid
        full_url += "?api_version=#{@api_version}"
        full_url += "&fq[]=ss_uuid:#{uuid}"
      else
        # uuid
        full_url += "&fq=uuid:#{uuid}"
      end

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
      end
       
      content
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

      # add api_version (legacy NREL is 2.0, otherwise use new syntax and ignore version)
      if @api_version.nil?
        # see if we can extract it from filter_str:
        tmp = filter_str.match(/api_version=\d{1,}.\d{1,}/)
        if tmp
          @api_version = tmp.to_s.gsub(/api_version=/, '').to_f
          puts "@api_version from filter_str: #{@api_version}"
        end
      end

      if @api_version == 2.0
        full_url += "?api_version=#{@api_version}"
      end
      puts "@api_version: #{@api_version}"

      # add filters
      if !filter_str.nil? 
        # strip out api_version from filters, if included & @api_version is defined
        if (filter_str.include? 'api_version=')
          filter_str = filter_str.gsub(/&api_version=\d{1,}.\d{1,}/, '')
          filter_str = filter_str.gsub(/api_version=\d{1,}.\d{1,}/, '')
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
      if @api_version == 2.0
        json = search(nil, 'fq[]=bundle%3Anrel_measure&show_rows=100')
      else
        json = search(nil, 'fq=bundle%3Ameasure&show_rows=100')
      end
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
        puts "loading URL config from #{config_filename}"
        @config = YAML.load_file(config_filename)
      else
        # use default URL
        @config = {
          server: {
            url: 'https://bcl.nrel.gov'
          }
        }
      end
    end

    # unused
    def default_yaml
      settings = {
        server: {
          url: 'https://bcl.nrel.gov'
        }
      }

      settings
    end
  end
end
