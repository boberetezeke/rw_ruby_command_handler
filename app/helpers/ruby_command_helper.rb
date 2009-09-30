
module RubyCommandHelper
  include ActsWithMetaDataHelper

  class ActiveRecordProxy
    attr_reader :class_name, :database_id, :memory_id

    def initialize(class_name, memory_id)
      @class_name = class_name
      @memory_id = "0x%8.8x" % [memory_id]
    end

    def database_id
puts "**************************************************************"
puts "**************************************************************"
puts "**************************************************************"
puts "in database_id: self = #{self.inspect}"
puts "in database_id: attributes = #{@attributes.inspect}"
puts "**************************************************************"
puts "**************************************************************"
puts "**************************************************************"
      #return @attributes["database_id"] if @attributes["database_id"]
      return @database_id if @database_id
      return @memory_id
    end
 
    def method_missing(sym, *args)
      if args.size == 0 then
        #$TRACE.debug 0, "ActiveRecordProxy.method_missing(#{sym.inspect}), " +
                         "sym.to_s = #{sym.to_s}, val = #{@attributes[:sym.to_s].inspect}, " +
                         "attributes = #{@attributes.inspect}"
        if @attributes && @attributes[sym.to_s] then
          @attributes[sym.to_s]
        else
          ""
        end
      end
    end
  end

  class ActiveRecordProxyConstructor < InspectParser::ObjectConstructor
    def initialize
      @active_record_proxies = []
    end

    def create_object(class_name, context, object_id)
      $TRACE.debug 5, "create_object: #{class_name}: #{context.inspect}"

      begin
      	constant = class_name.constantize
      rescue NameError
      	Object.module_eval("class #{class_name};end")
      end

      if class_name.constantize.ancestors.include?(ActiveRecord::Base)
        @active_record_proxies.push(class_name)
        return ActiveRecordProxy.new(class_name, object_id)
      else
        if (context & @active_record_proxies).empty?
          super
        else
          nil
        end
      end
    end

    def create_instance_variable(class_name, context, object, variable_name, value)
      begin
        $TRACE.debug 5, "create_ivar: #{variable_name}=#{value.inspect} " + 
           "on #{object.inspect}:: #{class_name}: #{context.inspect}"
        if object then
          if class_name == "RubyCommandHelper::ActiveRecordProxy" then
            if variable_name == "attributes" then
              # its a saved record and it hasn't been changed
              if value["id"] then
puts "**************************************************************"
puts "**************************************************************"
puts "**************************************************************"
puts "setting database_id = #{value['id']}"
puts "value = #{value.inspect}"
puts "**************************************************************"
puts "**************************************************************"
puts "**************************************************************"
                super(class_name, context, object, "database_id", value["id"])
              else
                super(class_name, context, object, "database_id", object.memory_id)
              end
              super(class_name, context, object, "attributes", value)
            else
              super
            end
puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
puts "self = #{object.inspect}"
puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
puts "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
          else
            super
          end
        end
      rescue Exception => e
        str = "@#{instance_variable_name}='EXCEPTION:#{e.message}'"
        $TRACE.debug 5, "about to eval '#{str}'"
        object.instance_eval(str)
      end
    end
  end

  def html_for_object(object)
    if object.kind_of?(RubyCommandHelper::ActiveRecordProxy) then
      link_to("#{object.class_name}::#{object.database_id}", 
              :controller => object.class_name, 
              :action => "show", 
              :id => object.database_id)
    else
      html_escape(object.inspect)
    end
  end
	
  def inspect_to_html(inspect_str)
    return "nil" if inspect_str.nil?

    #$TRACE.set_level 5 do
    objects = nil
    begin
      objects = InspectParser.new(inspect_str, 
                                  ActiveRecordProxyConstructor.new).parse
    rescue Exception => e
      return "inspect string=#{html_escape(inspect_str)}" + 
             "<br><b>ERROR: #{e.message}</b>" + 
             e.backtrace.join("<br>")
    end
    #end

    if objects.respond_to?(:map) && objects.respond_to?(:first) then
      classes = objects.map do |x| 
        class_name = x.class.to_s
        #class_name = x.class_name if class_name == 
        #                               "CommandHelper::ActiveRecordProxy"
      end

      # if all the classes are ActiveRecordProxy's for the same class
      if classes.uniq.size == 1 && classes.first == 
                                       "RubyCommandHelper::ActiveRecordProxy" then
        class_ids_hash = {}
        objects.each do |obj|
          (class_ids_hash[obj.class_name] ||= []).push(obj)
        end

        str = "<br>"
        class_ids_hash.each do |class_name, objects|
          $TRACE.debug 5, "objects after inspect = #{objects.inspect}"
          args = objects.map{|x| x.database_id}
          ar_objects = objects.first.class_name.constantize.find(*args)
          ar_objects = [ar_objects] unless ar_objects.respond_to?(:first)
          ar_object = ar_objects.first
          $TRACE.debug 5, "ar_objects after find = #{ar_objects.inspect}"
          
          model_params = {}
          model_params[:members] = ar_object.members_for_class
          members_to_display = ar_object.params_for_class[:list_members] 
			
          model_params[:members].
            select_and_order_members(members_to_display) if members_to_display
          @count = ar_objects.size
          str += render(:partial => "metacrud/model_list", 
                        :object => ar_objects, 
                        :locals => {:model_params => model_params})
        end
        str
      else
         "<table border=\"1\">" + objects.map do |row| 
           "<tr><td>#{html_for_object(row)}</td></tr>"
         end.join + "</table>"
      end
    elsif objects.class.to_s == "RubyCommandHelper::ActiveRecordProxy" then
puts "objects.inspect = #{objects.inspect}, remote_object_worker = #{$remote_object_worker.inspect}"
      ar_object = objects.class_name.constantize.find(objects.database_id)
      model_params = {}
      model_params[:members] = ar_object.members_for_class
      render(:partial => "metacrud/model_show", 
            :object => ar_object, 
            :locals => {:model_params => model_params})
    else
      "<b>" + html_escape(inspect_str) + "</b>"
    end
  end
end
