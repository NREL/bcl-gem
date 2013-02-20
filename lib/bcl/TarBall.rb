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
  Zlib::GzipWriter.open(destination) do |gzip|
    out = Archive::Tar::Minitar::Output.new(gzip)
    puts "[TarBall] Starting #{destination}"
    paths.each do |fi|
      puts "[TarBall] Packing #{fi}"
      if File.exists?(fi) 
        Archive::Tar::Minitar.pack_file(fi, out)
      else
        puts "[TarBall] Could not file file: #{fi}"
      end
    end
    puts "[TarBall] Finished #{destination}"
    out.close
  end
end

def extract_tarball(filename, destination)
  Zlib::GzipReader.open(filename) {|gz|
      Archive::Tar::Minitar.unpack(gz, destination)
  }
end

end # module BCL