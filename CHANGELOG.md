# Overview
List of changes to the bcl gem

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

### Changes 

* None

### Fixes
 
## Version 0.1.7

### New Features 

* Added rspec for testing

* Made a datatype method in BCL class to resolve the appropriate values per BCL convention (i.e. int, float, string)

### Changes 

* None

### Fixes

