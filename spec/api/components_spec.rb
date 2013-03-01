require 'spec_helper'
require 'rest_client'
require 'json/pure'
require 'libxml'
require 'base64'

describe BCL::Component do
  before :all do
    @username = $config["admin_user"]["username"]
    @password = $config["admin_user"]["password"]  #MOVE THIS TO CONFIG FILE or hash
    puts @password

    @url = "bcl7.development.nrel.gov/api"
    # @url = "bcl.concept3d.com/api"
    @url_bwc = "bcl.concept3d.com/api?api_version=1.1"
  end

  context "login tests" do
    it "should not authenticate" do
      data = {"username" => @username, "password" => "abc"}
      res = RestClient.post "http://#{@url}/user/login", data.to_json, :content_type => :json, :accept => :json
      puts res.inspect
      res.code.should eq(401)
    end
  end

  context "login and return session" do
    before :all do
      data = {"username" => @username, "password" => @password}
      res = RestClient.post "http://#{@url}/user/login", data.to_json, :content_type => :json, :accept => :json
      res.code.should eq(200)

      res_j = JSON.parse(res.body)

      @sessid = res_j["sessid"]
      @session_name = res_j["session_name"]
      @session_name.should_not be_nil
      @sessid.should_not be_nil

      @cookie = { @session_name => @sessid }
    end

    context "search component information v2.0" do
      before :all do
        query = "sunpower.xml?show_rows=3"
        full_url = "http://#{@url}/search/#{query}"
        puts full_url
        @res = RestClient.get "#{full_url}"
        @xml_doc = LibXML::XML::Document.string(@res.body)
      end

      it "should return 200" do
        @res.code.should eq(200)
      end

      it "should return a valid search" do
        elements = @xml_doc.find("/results/result")
        elements.length.should be >= 1
        end

      it "should return three results" do
        elements = @xml_doc.find("/results/result")
        elements.size.should eq(2)
      end
    end

    context "download component v2.0" do
      before :all do
        query = "sunpower.xml?show_rows=3"
        full_url = "http://#{@url}/search/#{query}"
        @res = RestClient.get "#{full_url}"
        @xml_doc = LibXML::XML::Document.string(@res.body)
        @uids = []
        @xml_doc.find('/results/result/component/uuid').each do |ele|
          @uids << ele.content
        end

      end

      it "should have uuid to download" do
        @uids.length.should be > 0
      end

      it "should be able to use get to download multiple components that is valid" do
        # need to look like uuids=abc,def
        data = "uids=#{@uids.join(",")}"
        #data = "uids=#{@uids.first}"

        res = RestClient.get "http://#{@url}/component/download?#{data}"
        res.code.should eq(200)
        res.body.should_not be_nil

        #save file?
        #file = File.new("bcl_download.zip", "wb")
        #file.write(resp.body)
        #file.close
      end

      it "should be able to download many components using get" do
        data = "uids=#{@uids.first}"

        res = RestClient.get "http://#{@url}/component/download?#{data}"
        res.code.should eq(200)
        res.code.should eq(200)
      end

      it "should be able to use post to download a component that is valid" do
        # need to look like uuids=abc,def
        data = "uids=#{@uids.join(",")}"
        data = "uids=#{@uids.first}"

        res = RestClient.post "http://#{@url}/component/download?#{data}", data
        res.code.should eq(200)
      end


    end

    context "post data" do
      it "should be able to post a file as tar.gz and then reference in new component" do
        # NOTE: This is uploading the exact same component every time. It should automatically error out
        # if the file has been uploaded before
        filename = "#{File.dirname(__FILE__)}/resources/component_example.tar.gz"
        file = File.open(filename, 'r')
        file_b64 = Base64.encode64(file.read)
        @data = {"file" =>
                  {
                    "file" => "#{file_b64}",
                    "filesize" => "#{file.size}",
                    "filename" => "component_example.tar.gz"
                  }
                }

        res = RestClient.post "http://#{@url}/file", @data.to_json, :content_type => :json, :cookies => @cookie, :accept => :json
        res.code.should eq(200)

        fid = JSON.parse(res.body)["fid"]

        #post the node now with reference to this fid
        @data = {"node" =>
                     {"type" => "nrel_component",
                      "status" => 1,  #NOTE THIS ONLY WORKS IF YOU ARE ADMIN
                      "field_tar_file" =>
                          {"und" => [
                              {"fid" => fid}
                          ]
                          }
                     }
                }

        res = RestClient.post "http://#{@url}/node", @data.to_json, :content_type => :json, :cookies => @cookie, :accept => :json
        res.code.should eq(200)

        res.body.should_not be_nil
        res_j = JSON.parse(res.body)
        res_j["nid"].to_i.should be > 0
        res_j["uuid"].should_not be_nil
      end

    end
  end
end
