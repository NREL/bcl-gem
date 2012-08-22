#access the BCL API to download weather files
# 2012-04-12

require 'net/http'
require 'rexml/document'

#make sure to put in your api key here (create an account and request a key).
apikey = "xxx"

# Our query string. This searches for "florida", and limits results to 3
url = "http://bcl.nrel.gov/api/search/fl.xml?show_rows=3&oauth_consumer_key=#{apikey}"

# Get XML data as a string
xml_data = Net::HTTP.get_response(URI.parse(url)).body

# Parse the XML
doc = REXML::Document.new(xml_data)

# Set up our string
uids = String.new

# Fill our string with nids
doc.elements.each('results/result/component/uid') do |ele|
	uids << ele.text
	uids << ','
end

puts uids

# Send our hash as a POST to our bulk downloader
#   The bulk downloader expects a list of uids in POST, like so: uids => uid,uid,uid,uid,
#   It will build every nid it receives into a component folder with the
#   data file, component.xml, and any images or video, then output a zip file
resp = Net::HTTP.post_form(URI.parse("http://bcl.nrel.gov/api/component/download"), {"uids" => uids, "oauth_consumer_key" => apikey})
# Write the response to a file in the local directory
file = File.new("bcl_download.zip", "wb")
file.write(resp.body)
file.close
