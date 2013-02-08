# initial file created by Allan Wintersick
# modified by Nicholas Long to add other 
# search queries, curl commands, and point to prod server.
# fixed writing of binary files for windows (what out for this in python too 'wb', not 'w')

# to access via curl type
#    curl -d "nid=nid_id_1,nid_id_2" http://....
#

# https://bcl.nrel.gov/api/search/denver.xml?oauth_consumer_key=fM9SwvMbeWeDevZwKsgrBrXqQc5TvpSv

require 'net/http'
require 'rexml/document'

#make sure to put in your api key here (create an account and request a key).
apikey = "XYZ"

# Our query string. This searches for "denver", and limits results to 2
url = "http://bcl.nrel.gov/api/search/denver.xml?show_rows=3&oauth_consumer_key=#{apikey}"

#filter vlt by facet
#url = http://bcl.nrel.gov/api/search/ashrae?filters=type:nrel_component%20fs_ca_vlt:%20[0%20TO%200.5]&oauth_consumer_key=#{apikey}"

#pagination of results
#url = http://bcl.nrel.gov/api/search/ashrae?filters=type:nrel_component%20fs_ca_vlt:%20[0%20TO%200.5]&page=2&oauth_consumer_key=#{apikey}"

# Get XML data as a string
xml_data = Net::HTTP.get_response(URI.parse(url)).body

# Parse the XML
doc = REXML::Document.new(xml_data)

# Set up our string
nids = String.new

# Fill our string with nids
doc.elements.each('result/results/item/nid') do |ele|
	nids << ele.text
	nids << ','
end

puts nids

# Send our hash as a POST to our bulk downloader
#   The bulk downloader expects a list of nids in POST, like so: nids => nid,nid,nid,nid,
#   It will build every nid it receives into a component folder with the
#   data file, component.xml, and any images or video, then output a zip file
resp = Net::HTTP.post_form(URI.parse("http://bcl.nrel.gov/api/component/download"), {"nids" => nids})
# Write the response to a file in the local directory
file = File.new("bcl_download.zip", "wb")
file.write(resp.body)
file.close
