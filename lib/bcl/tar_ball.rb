# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

module BCL
  module_function

  # tarball multiple paths recursively to destination
  def tarball(destination, paths)
    # check for filepath length limit
    full_destination = File.expand_path(destination)
    if full_destination.length > 259 # 256 chars max; "C:\" doesn't count
      puts "[TarBall] ERROR cannot generate #{destination} because path exceeds 256 char limit. shorten component name by at least by #{full_destination.length - 259} chars"
      return
    end

    Zlib::GzipWriter.open(destination) do |gzip|
      out = Archive::Tar::Minitar::Output.new(gzip)

      paths.each do |fi|
        if File.exist?(fi)
          Archive::Tar::Minitar.pack_file(fi, out)
        else
          puts "[TarBall] ERROR Could not file file: #{fi}"
        end
      end
      out.close
    end
  end

  def extract_tarball(filename, destination)
    Zlib::GzipReader.open(filename) do |gz|
      Archive::Tar::Minitar.unpack(gz, destination)
    end
  end

  def create_zip(_destination, paths)
    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      paths.each do |fi|
        # Two arguments:
        # - The name of the file as it will appear in the archive
        # - The original file, including the path to find it
        zipfile.add(fi.basename, fi)
      end
    end
  end

  def extract_zip(filename, destination, delete_zip = false)
    Zip::File.open(filename) do |zip_file|
      zip_file.each do |f|
        f_path = File.join(destination, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) unless File.exist? f_path
      end
    end

    if delete_zip
      file_list = []
      file_list << filename
      FileUtils.rm(file_list)
    end
  end
end
