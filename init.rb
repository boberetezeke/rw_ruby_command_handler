# Include hook code here
puts "in init.rb ****************************** #{directory}"

path = File.join(directory, 'lib')
$LOAD_PATH << path
Dependencies.load_paths << path

%w{ models controllers helpers views workers command_handlers }.each do |dir|
  path = File.join(directory, 'app', dir)
  $LOAD_PATH << path
  Dependencies.load_paths << path
  Dependencies.load_once_paths.delete(path)
end

unless ObjectDatabaseCommandHandler.find_by_name("RubyCommand")
puts "************************** here 1 ***********************************"
	ObjectDatabaseCommandHandler.new(:prefix => ">", 
												:name => "RubyCommand", 
												:is_plugin_source_code => true,
			   								:content => File.read(
									 				File.join(directory, 
														"app/command_handlers/ruby_command_handler.rb"))
												).save
puts "************************** here 2 ***********************************"
	ObjectDatabaseModel.new(:name => "RubyCommand", 
									:is_plugin_source_code => true,
	  								:content => File.read(
						 				File.join(directory, 
										"app/models/ruby_command.rb"))
							     ).save
puts "************************** here 3 ***********************************"
	ObjectDatabaseController.new(:name => "RubyCommand",
										  :is_plugin_source_code => true,
	  								     :content => File.read(
						 				     File.join(directory, 
										        "app/controllers/ruby_command_controller.rb"))
										  ).save
puts "************************** here 4 ***********************************"
	ObjectDatabaseHelper.new(:name => "RubyCommand", 
									 :is_plugin_source_code => true,
	  								     :content => File.read(
						 				     File.join(directory, 
										        "app/helpers/ruby_command_helper.rb"))
								   ).save
puts "************************** here 5 ***********************************"
end
