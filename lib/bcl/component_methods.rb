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

require 'rubygems'
require 'pathname'
require 'FileUtils'
require 'bcl/TarBall'

module BCL

  module_function

  def gather_components(component_dir, chunk_size = 0, delete_previous_gather = false)
    @dest_filename = "components"
    @dest_file_ext = "tar.gz"

    #store the starting directory
    current_dir = Dir.pwd

    #an array to hold reporting info about the batches
    gather_components_report = []

    #go to the directory containing the components
    Dir.chdir(component_dir)

    # delete any old versions of the component chunks
    FileUtils.rm_rf("./_gather") if delete_previous_gather

    #gather all the components into array
    targzs = Pathname.glob("./**/*.tar.gz")
    tar_cnt = 0
    chunk_cnt = 0
    targzs.each do |targz|
      if chunk_size != 0 && (tar_cnt % chunk_size) == 0
        chunk_cnt += 1
      end
      tar_cnt += 1

      destination_path = "./_gather/#{chunk_cnt}"
      FileUtils.mkdir_p(destination_path)
      destination_file = "#{destination_path}/#{File.basename(targz.to_s)}"
      puts "copying #{targz.to_s} to #{destination_file}"
      FileUtils.cp(targz.to_s, destination_file)
    end

    #gather all the zip files into a single tar.gz
    (1..chunk_cnt).each do |cnt|
      currentdir = Dir.pwd

      paths = []
      Pathname.glob("./_gather/#{cnt}/*.tar.gz").each do |pt|
        paths << File.basename(pt.to_s)
      end

      Dir.chdir("./_gather/#{cnt}")
      destination = "#{@dest_filename}_#{cnt}.#{@dest_file_ext}"
      BCL.tarball(destination, paths)
      Dir.chdir(currentdir)

      #move the tarball back a directory
      FileUtils.move("./_gather/#{cnt}/#{destination}", "./_gather/#{destination}")
    end

    Dir.chdir(current_dir)

  end

  def push_components(component_dir)
    # read in the configuration data

    return true

  end

end # module BCL
