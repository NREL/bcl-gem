# Change Log

## Version 0.7.0
* Support Ruby > 2.7
* Minimum version of OpenStudio Measure Tester Gem to 0.3.0
* Update copyrights

## Version 0.6.1
* Remove dependency for winole (`require 'win32ole'`). This affects the reading of the component spreadsheets and the 
the master taxomony.
* Use new rubocop (v3) from s3 openstudio-resources

## Version 0.6.0
* Support Ruby > 2.5
* Update dependencies

## Version 0.5.9
* Update copyrights
* Update rubocop version (security)
* Updates to support OpenStudio Extension gem

## Version 0.5.8 
* Cleanup code (rubocop)

## Version 0.5.7
* Update to_underscore method to not break apart EnergyPlus nor OpenStudio

## Version 0.5.6
* Allow no display name when parsing measure arguments (measure argument does not have setDisplayName)
* Parse measure display name, description, modeler description, and argument units
* Add basic validation that prints to the terminal
* Upgrade spec and ci reporter
* New branch for development (develop)

## Version 0.5.5
* Read as binary for .tar.gz
* When downloading and parsing measures, skip instance where the measure class name is already the directory name.

## Version 0.5.2-4
* Remove libxml dependency
* Add OpenStudio static measure parsing method
* Add translate to CSV from static measures to support OpenStudio-analysis spreadsheet
* Fix Group ID
* Pull UUID out of tar.gz files
* More testing around measures and components API
* Rubocop

## Version 0.5.1
* Fix bug when parsing BCL measures and nil arguments

## Version 0.5.0
* Remove support for Ruby 1.8.7.  Only supporting > 1.9.2
* Remove JSON gem. Using multi_json
* Removed obsolete tests
* Removed RestClient in favor of Faraday (used for testing)

## Version 0.4.1
* Several fixes to previous gem
* Put required gems into the gemspec

### New Features
* Able to specify the group_id when you create the component methods
* Added parsing of BCL measures for extracting arguments

## Version 0.3.7

### New Features
* Added a search for measures that returns the JSON
* Added the ability to download a component (measure or component). Result returns the file data that needes to be persisted.

## Version 0.1.7

### New Features
* Added rspec for testing
* Made a datatype method in BCL class to resolve the appropriate values per BCL convention (i.e. int, float, string)
