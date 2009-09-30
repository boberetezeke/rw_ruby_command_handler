class RubyCommand < ActiveRecord::Base
  acts_as_database_object

  has_field :command
  has_field :result, :type => "text", :control_type => "partial", 
            :display_partial => "command_results"
  has_field :output, :type => "text", :control_type => "partial",
            :display_partial => "command_output"

  has_field :when_created, :type => :datetime

  link_text {|x,c| if x.command.size > 20 then; x.command[0..17] + "..."; else; x.command; end}
end
