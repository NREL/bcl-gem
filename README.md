# BCL Gem

All the methods to build, test, and release the gem available as rake tasks via bundler/gem_tasks. Note that you can see all the rake tasks by calling `rake -T` at the command line.

## Building BCL Gem

If this is a new version that will be release first edit the ./lib/bcl/version.rb file and increment the version number.  This will automatically propagate through the build process.

`rake build`

To install:

`rake install`

## Releasing Gem

Note: Releasing the gem will call the build command, tag it in Git, and push to rubygems.

run `rake release`

## Testing

`rake spec`

## Uninstall

run `gem uninstall bcl -a`

## Workflow for pushing content to BCL

run `rake bcl:stage_and_upload[/path/to/content, resetFlag]`

where `path/to/content` is a path to the directory of measures or components to upload and `resetFlag` is a boolean flag indicating whether to clear already staged content and receipt files (true), or to keep the staged content and receipt files (false).

Staging and Uploading tasks can be called separately: 

`rake bcl:stage_content[/path/to/content, resetFlag]`

`rake bcl:upload_content[resetFlag]`

