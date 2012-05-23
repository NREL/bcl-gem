######################################################################
#  Copyright (c) 2008-2010, Alliance for Sustainable Energy.  
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
require 'pathname'
require 'fileutils'

require 'bcl/TarBall'

module BCL
module_function

def gather_components(component_dir)
  
  current_dir = Dir.pwd
  
  Dir.chdir(component_dir)

  #delete old gather first
  gather_dest = "components.tar.gz"
  File.delete("./gather/" + gather_dest) if File.exists?("./gather/" + gather_dest)

  #gather all the components
  targzs = Pathname.glob("./**/*.tar.gz")
  targzs.each do |targz|
    destination = "./gather/#{File.basename(targz.to_s)}"
    puts "copying #{targz.to_s} to #{destination}"
    Dir.mkdir("./gather") unless File.directory?("./gather")
    File.delete(destination) if File.exists?(destination)
    FileUtils.cp(targz.to_s, destination)
  end

  #gather all the zip files into a single tar.gz
  paths = []
  Pathname.glob("./gather/*.tar.gz").each do |pt|
    paths << File.basename(pt.to_s)
  end

  Dir.chdir("./gather")

  tarball(gather_dest, paths)

  Dir.chdir(current_dir)
end

end # module BCL
