#example ruby script for searching and downloading components
#script is configured for the DEV server

require 'net/http'
require 'rexml/document'

#apikey (apitest user)
apikey = "QYK5rQGbxnSNRVDEYhEqALnC25Kb38DW"

#select which example to run
puts "What example do you want to run?"
puts "Enter 1 for search and download components"
puts "Enter 2 for downloading a component by node id"
sel = gets

sel = sel.strip

if sel == "1"
  #SEARCH AND DOWNLOAD
  puts "Searching for components..."
  
  #Our query string. This example search is for components matching the keyword "co", are weather files, and limit the results to 2 per page, and returns the 2nd page of results
	url = "http://bcl.development.nrel.gov/api/search/co.xml?filters=sm_component_type:\"Weather File\"&show_rows=2&page=2&oauth_consumer_key=#{apikey}"
	
	# Get XML data as a string
	xml_data = Net::HTTP.get_response(URI.parse(URI.encode(url))).body
	
	# Parse the XML
	doc = REXML::Document.new(xml_data)
	
	# Set up our string
	nids = String.new
	
	# Fill our string with nids
	doc.elements.each('result/results/item/nid') do |ele|
		nids << ele.text
		nids << ','
	end
	
	puts "Components Found: #{nids}"
	
	# Send our hash as a POST to our bulk downloader
	#   The bulk downloader expects a list of nids in POST, like so: nids => nid,nid,nid,nid,
	#   It will build every nid it receives into a component folder with the
	#   data file, component.xml, and any images or video, then output a zip file
	resp = Net::HTTP.post_form(URI.parse("http://bcl.development.nrel.gov/api/component/download"), {"nids" => nids, "oauth_consumer_key" => apikey })
	
	# Write the response to a file in the local directory
	file = File.new("component_search.zip", "wb")
	file.write(resp.body)
	file.close

  
elsif sel == "2"
  #DOWNLOAD BY ID
  
  puts "Enter the id of the node you want to download:"
	node_id = gets
	puts "Downloading node id #{node_id}"
	node_id = node_id.strip
	
	resp = Net::HTTP.post_form(URI.parse("http://bcl.development.nrel.gov/api/component/download"), {"nids" => node_id, "oauth_consumer_key" => apikey })
	
	# Write the response to a file in the local directory
	file = File.new("component_#{node_id}.zip", "wb")
	file.write(resp.body)
  file.close

end