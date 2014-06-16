require 'uuid' # gem install uuid

module BCL
  ProvStruct = Struct.new(:author, :datetime, :comment)
  TagsStruct = Struct.new(:descriptor)
  AttrStruct = Struct.new(:name, :value, :datatype, :units)
  FileStruct = Struct.new(:version_software_program, :version_id, :fqp_file, :filename, :filetype, :usage_type, :checksum)
  CostStruct = Struct.new(:cost_name, :cost_type, :category, :value, :interval,
                          :interval_units, :year, :location, :units, :currency, :source,
                          :reference_component_name, :reference_component_id)

  ObjectStruct = Struct.new(:obj_type, :obj_instance)

  class BaseXml
    attr_accessor :name
    attr_accessor :description
    attr_accessor :modeler_description
    attr_accessor :uuid
    attr_accessor :vuid

    attr_accessor :attributes
    attr_accessor :files
    attr_accessor :costs
    attr_accessor :tags
    attr_accessor :provenances

    def initialize(save_path)
      @name = "" #this is also a unique identifier to the component...
      @description = ""
      @modeler_description = ""

      @provenances = []
      @tags = []
      @attributes = []
      @files = []

      @schema_url = "schema.xsd"
    end

    def generate_uuid()
      @uuid = UUID.new.generate
    end

    def generate_vuid()
      @vuid = UUID.new.generate
    end


    def add_provenance(author, datetime, comment)
      prov = ProvStruct.new
      prov.author = author
      prov.datetime = datetime
      prov.comment = comment

      @provenances << prov
    end

    def add_tag(tag_name)
      tag = TagsStruct.new
      tag.descriptor = tag_name

      @tags << tag
    end

    def add_attribute(name, value, units, datatype = nil)
      attr = AttrStruct.new
      attr.name = name
      attr.value = value

      if !datatype.nil?
        attr.datatype = datatype
      else
        attr.datatype = get_datatype(value)
      end
      attr.units = units

      @attributes << attr
    end

    def add_file(version_sp, version_id, fqp_file, filename, filetype, usage_type = nil, checksum = nil)
      fs = FileStruct.new
      fs.version_software_program = version_sp
      fs.version_id = version_id
      fs.fqp_file = fqp_file
      fs.filename = filename
      fs.filetype = filetype
      fs.usage_type = usage_type if usage_type != nil
      fs.checksum = checksum if checksum != nil

      @files << fs
    end

    #return the title case of the string
    def tc(input)
      val = input.gsub(/\b\w/) { $&.upcase }
      if val.downcase == "energyplus"
        val = "EnergyPlus"
      end
      return val
    end

    def get_attribute(attribute_name)
      result = nil
      @attributes.each do |attr|
        if attr.name == attribute_name
          result = attr
        end
      end

      result
    end

    def get_datatype(input_value)
      dt = 'undefined'

      # simple method to test if the input_value is a string, float, or integer.
      # First convert the value back to a string for testing (in case it was passed as a float/integer)
      test = input_value.to_s
      input_value = test.match('\.').nil? ? Integer(test) : Float(test) rescue test.to_s

      if input_value.is_a?(Fixnum) || input_value.is_a?(Bignum)
        dt = "int"
      elsif input_value.is_a?(Float)
        dt = "float"
      else
        dt = "string"
      end

      dt
    end
  end
end
