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

require 'zlib' #gem install zliby
require 'archive/tar/minitar' #gem install archive-tar-minitar

module BCL

module_function

def tarball(destination, paths)
  
  #check for filepath length limit
  full_destination = File.expand_path(destination)
  if full_destination.length > 259 #256 chars max; "C:\" doesn't count
    puts "[TarBall] ERROR cannot generate #{destination} because path exceeds 256 char limit. shorten component name by at least by #{full_destination.length - 259} chars"
    return
  end
  
  Zlib::GzipWriter.open(destination) do |gzip|
    out = Archive::Tar::Minitar::Output.new(gzip)
    
    paths.each do |fi|
      if File.exists?(fi) 
        Archive::Tar::Minitar.pack_file(fi, out)
      else
        puts "[TarBall] ERROR Could not file file: #{fi}"
      end
    end
    out.close
  end
end

def extract_tarball(filename, destination)
  Zlib::GzipReader.open(filename) {|gz|
      Archive::Tar::Minitar.unpack(gz, destination)
  }
end

end # module BCL