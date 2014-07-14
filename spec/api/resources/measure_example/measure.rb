# Non Working measure for testing
class AddDaylightSensors < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see
  def name
    'Add Daylight Sensor at the Center of Spaces with a Specified Space Type Assigned'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make a choice argument for model objects
    space_type_handles = OpenStudio::StringVector.new
    space_type_display_names = OpenStudio::StringVector.new

    # putting model object and names into hash
    space_type_args = model.getSpaceTypes
    space_type_args_hash = {}
    space_type_args.each do |space_type_arg|
      space_type_args_hash[space_type_arg.name.to_s] = space_type_arg
    end

    # looping through sorted hash of model objects
    space_type_args_hash.sort.map do |key, value|
      # only include if space type is used in the model
      if value.spaces.size > 0
        space_type_handles << value.handle.to_s
        space_type_display_names << key
      end
    end

    args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    space_type = runner.getOptionalWorkspaceObjectChoiceValue('space_type', user_arguments, model)
    setpoint = runner.getDoubleArgumentValue('setpoint', user_arguments)
    control_type = runner.getStringArgumentValue('control_type', user_arguments)
    min_power_fraction = runner.getDoubleArgumentValue('min_power_fraction', user_arguments)
    min_light_fraction = runner.getDoubleArgumentValue('min_light_fraction', user_arguments)
    height = runner.getDoubleArgumentValue('height', user_arguments)
    material_cost = runner.getDoubleArgumentValue('material_cost', user_arguments)
    demolition_cost = runner.getDoubleArgumentValue('demolition_cost', user_arguments)
    years_until_costs_start = runner.getIntegerArgumentValue('years_until_costs_start', user_arguments)
    demo_cost_initial_const = runner.getBoolArgumentValue('demo_cost_initial_const', user_arguments)
    expected_life = runner.getIntegerArgumentValue('expected_life', user_arguments)
    om_cost = runner.getDoubleArgumentValue('om_cost', user_arguments)
    om_frequency = runner.getIntegerArgumentValue('om_frequency', user_arguments)

    # setup OpenStudio units that we will need
    unit_area_ip = OpenStudio.createUnit('ft^2').get
    unit_area_si = OpenStudio.createUnit('m^2').get

    # define starting units
    area_si = OpenStudio::Quantity.new(sensor_area, unit_area_si)

    # unit conversion from IP units to SI units
    area_ip = OpenStudio.convert(area_si, unit_area_ip).get

    # get final costs for spaces
    yr0_capital_totalCosts = get_total_costs_for_objects(spaces_using_space_type)

    # reporting final condition of model
    runner.registerFinalCondition("Added daylighting controls to #{sensor_count} spaces, covering #{area_ip}. Initial year costs associated with the daylighting controls is $#{neat_numbers(yr0_capital_totalCosts, 0)}.")

    true
  end # end the run method
end # end the measure

# this allows the measure to be used by the application
AddDaylightSensors.new.registerWithApplication
