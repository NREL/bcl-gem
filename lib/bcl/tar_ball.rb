# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

module BCL
  module_function

  def extract_tarball(filename, destination)
    Zlib::GzipReader.open(filename) do |gz|
      Archive::Tar::Minitar.unpack(gz, destination)
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
