#example ruby script for uploading and updating components
#script is configured for the DEV server
#user must have "Content Editor" role in order to be able to upload via the API

require 'net/http'
require 'json'  #gem install json_pure
require 'base64'

#***VARIABLES

http = Net::HTTP.new('bcl.development.nrel.gov', 80)
session_name = ""
sessid = ""
cookie = ""
newnid = ""
uid = "24"
username = "apitest"
password = "6Dr4S88P!"
apikey = "QYK5rQGbxnSNRVDEYhEqALnC25Kb38DW"

#***LOGIN***

puts "***LOG IN***"

path = "/api/user/login?oauth_consumer_key=#{apikey}"
data = %Q({"username":"#{username}","password":"#{password}"})

headers = {'Content-Type' => 'application/json'}

resp, data = http.post(path, data, headers)

puts 'Code = ' + resp.code
puts 'Message = ' + resp.message
resp.each {|key, val| puts key + ' = ' + val}
puts data


#parse json object to extract session_name and sessid
json = JSON.parse(data)
json.each do |key, val|
	if key == 'session_name'
		session_name = val
	elsif key == 'sessid'
		sessid = val
	end
end

puts "session_name: #{session_name}, sessid: #{sessid}"

cookie = "#{session_name}=#{sessid}"


#***UPLOAD FILE for component (this needs the user's uid)***

puts "***UPLOAD FILE***"

path = "/api/file?oauth_consumer_key=#{apikey}"

filecontents = File.read('uploadfile')
filecontents = Base64.encode64(filecontents).gsub("\n", '')

data = '{"file":{"file":"' + filecontents + '","filename":"testfile.idf","filesize":"24","uid":"' + uid + '"}}'

headers = {'Content-Type' => 'application/json', 'Cookie' => "#{cookie}"}

resp, data = http.post(path, data, headers)

puts 'Code = ' + resp.code
puts 'Message = ' + resp.message
resp.each {|key, val| puts key + ' = ' + val}
puts data

#extract data to tie file to a new component
filedata = data

#*** UPLOAD NEW COMPONENT (with filedata from above)***

puts "***UPLOAD NEW COMPONENT AND ATTACH FILE TO IT***"

path = "/api/component?oauth_consumer_key=#{apikey}"
data = %Q({"node":{"type":"nrel_component","title":"Testing API","component":{"general":{"name":"API upload Test","attributes":{"attribute":{"0":{"name":"WMO","value":"577"}}},"files":{"file":{"0":{"filename":"testfile","filetype":"idf"}}}}},"field_files":{"0":#{filedata}}}})

headers = {'Content-Type' => 'application/json', 'Cookie' => "#{cookie}"}

resp, data = http.post(path, data, headers)

puts 'Code = ' + resp.code
puts 'Message = ' + resp.message
resp.each {|key, val| puts key + ' = ' + val}
puts data

#extract nid of new component
json = JSON.parse(data)
json.each do |key, val|
	if key == 'nid'
		newnid = val
		break
	end
end

puts "NEWNID: #{newnid}"

#*** UPDATE NODE (need NID, and this is a PUT, not POST)***
puts "***UPDATE NODE DATA AND REATTACH FILE TO IT***"

path = "/api/component/#{newnid}?oauth_consumer_key=#{apikey}"

puts path

data = %Q({"node":{"type":"nrel_component","title":"Testing API update","component":{"general":{"name":"API upload Test","attributes":{"attribute":{"0":{"name":"WMO","value":"600"}}},"files":{"file":{"0":{"filename":"testfile","filetype":"idf"}}}}},"field_files":{"0":#{filedata}}}})

puts "UPDATE DATA: #{data}"

headers = {'Content-Type' => 'application/json', 'Cookie' => "#{cookie}"} 

resp, data = http.send_request('PUT',path, data, headers)

puts 'Code = ' + resp.code
puts 'Message = ' + resp.message
resp.each {|key, val| puts key + ' = ' + val}
puts data
