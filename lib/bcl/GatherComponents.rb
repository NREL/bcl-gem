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
require 'pathname'
require 'fileutils'
require 'enumerator'

require 'bcl/TarBall'

module BCL
module_function

def gather_components(component_dir)
  #store the starting directory
  current_dir = Dir.pwd
  
  #an array to hold reporting info about the batches
  gather_components_report = []
  
  #go to the directory containing the components
  Dir.chdir(component_dir)

  #delete old gather files first
  gather_dest_base = "components.tar.gz"
  #File.delete("./gather/" + gather_dest_base) if File.exists?("./0gather/" + gather_dest_base)

  #copy all the components' tar.gz files into a single directory
  targzs = Pathname.glob("./**/*.tar.gz")
  targzs.each do |targz|
    destination = "./0gather/#{File.basename(targz.to_s)}"
    puts "copying #{targz.to_s} to #{destination}"
    Dir.mkdir("./0gather") unless File.directory?("./0gather") #named so it will be at top of directory list
    File.delete(destination) if File.exists?(destination)
    FileUtils.cp(targz.to_s, destination)
  end
  
  #go into that directory
  Dir.chdir("./0gather")
  
  #get a list of all the tar.gz files in the new directory
  targzs = Pathname.glob("*.tar.gz")
  
  #report the total number of components in the directory
  gather_components_report << "Total components = #{targzs.length}"
  
  #define an iterator to keep track of the number of batches
  batch_num = 0
    
  #package all the tar.gzs in the directory into a few master tar.gz files of 1000 components or less  
  targzs.each_slice(1000) do |batch|
    
    gather_components_report << "  batch #{batch_num} contains #{batch.length} components"
    
    #put all the paths in the batch into an array
    paths = []
    batch.each do |targz|
      paths << File.basename(targz.to_s)
    end
    
    #path where the batch tarball is going
    gather_dest = "0_#{batch_num}_#{gather_dest_base}" #prefix to move to top of directory

    #tar up the batch
    tarball(gather_dest, paths)

    batch_num += 1
  end

  #report out
  puts gather_components_report
  
  #change back to the directory where we started
  Dir.chdir(current_dir)
  
end

end # module BCL
