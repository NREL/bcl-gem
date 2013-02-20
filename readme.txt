All the methods to build, test, and release the gem are in the Rakefile.  Note that you can see all the rake tasks by calling `rake -T` at the command line.

Building BCL Gem
----------------
  1) If this is a new version that will be release first edit the ./lib/bcl/version.rb file and increment the version number.  This will automatically propogate through the build.
  2) run `rake build`
 

Testing Local Gem
-----------------
  1) run `rake install_local`

Releasing Gem
-----------------
  Note: Releasing the gem will call the build command. Also, after releasing the Gem, you will need to reinstall the Gem so that you are using the version off rubygems
  1) run `rake release`
  2) run `rake uninstall`
  3) run `rake install`


