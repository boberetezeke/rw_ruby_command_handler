class RubyCommandHandler < ODRails::CommandHandler
  def handle_command(command_str)
begin
puts "RubyCommandHandler#handle_command"
    session[:ruby_command_job_key] = MiddleMan.new_worker(:class => "ruby_command_worker") 
$TRACE.debug 5, "session: #{session[:ruby_command_job_key].inspect}"
    # unless session[:ruby_command_job_key]
worker = MiddleMan.get_worker(session[:ruby_command_job_key])
$TRACE.debug 5, "worker: #{worker.inspect}"
    command_id = 
      #MiddleMan.get_worker(session[:ruby_command_job_key]).evaluate(command_str)
      worker.evaluate(command_str)
$TRACE.debug 5, "command_id = #{command_id}"
rescue Exception => e
$TRACE.debug 5, "Exception: #{e.message}"
$TRACE.debug 5, "backtrace" + e.backtrace.join("\n")
end
    redirect_to :controller => "ruby_command", :action => "show", :id => command_id
  end
end
