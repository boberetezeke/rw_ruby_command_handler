class InspectParser
	class ObjectConstructor
		def create_object(class_name, context, object_id)
			constantize(class_name).allocate
		end

		def create_instance_variable(class_name, context, object, instance_variable_name, value)
			str = "@#{instance_variable_name}=value"
			$TRACE.debug 5, "about to eval '#{str}'"
			object.instance_eval(str)
		end

		def constantize(camel_cased_word)
			unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
				raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
			end

			Object.module_eval("::#{$1}", __FILE__, __LINE__)
		end	
	end

	def initialize(str, object_constructor=ObjectConstructor.new)
		@parse_str = str
		@token_stack = []
		@objects = {}
		@object_constructor = object_constructor
		@context = []
	end

	def unget_token(token, value)
		@token_stack.push([token, value])
	end

   MONTH_HASH = {
   	"Jan" => 0,
   	"Feb" => 1,
   	"Mar" => 2,
   	"Apr" => 3,
   	"May" => 4,
   	"Jun" => 5,
   	"Jul" => 6,
   	"Aug" => 7,
   	"Sep" => 8,
   	"Oct" => 9,
   	"Nov" => 10,
   	"Dec" => 11
   }

	def get_token(expected_token=nil)
		return @token_stack.pop unless @token_stack.empty?

		$TRACE.debug 5, "in @parse_str = '#{@parse_str}"

		# eat leading white space
		if @parse_str =~ /^\s+/ then
			@parse_str = Regexp.last_match.post_match
		end

		# grab the next token
		value = nil
		token = case @parse_str
		#	    Tue     Aug      8      04:23:00         -0500     2008
		when /^(\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(-)?(\d+)\s+(\d+)/
														value = Time.local( $9.to_i, MONTH_HASH[$2], $3.to_i, $4.to_i, $5.to_i, $6.to_i)
														:time
		#      Tue,     19     Aug    2008      15:42:04       UTC       +00:00
		when /^(\w+),\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\w+)\s+(\+)?(\d+):(\d+)/
														value = Time.local( $4.to_i, MONTH_HASH[$3], $2.to_i, $5.to_i, $6.to_i, $7.to_i)
														:time
		when /^0x(\w+)/:							value = $1.hex / 2   #/
		                                    $TRACE.debug 5, "object_id = #{$1}; value = 0x#{'%8.8x' % [value]}"
		                                    :object_id
		#when /^(\d+)/: 							value = $1.to_i; 	:number
		when /^((\d+)(\.(\d+))?)/:				value = $3 ? $1.to_f : $1.to_i;	:number
		when /^\[/: 								:start_array
		when /^,/: 									:comma
		when /^\]/: 								:end_array
		when /^\{/: 								:start_hash
		when /^\=\>/: 								:hash_relationship
		when /^\}/: 								:end_hash
		when /^#</: 								:start_object
		when /^>/: 									:end_object
		when /^:([A-Za-z_]+)/:					value = $1.to_sym;				:symbol
		when /^::/:									:double_colon
		when /^:/: 									:colon
		when /^@/:									:at_sign
		when /^=/:									:equal
		when /^([A-Za-z_][A-Za-z_0-9]*)/: 	value = $1; 		:identifier
		when /^\.\.\./:							:elipsis
		when /^"(([^"\\]|\\.)*)"/:				value = $1;			:string
		end

		$TRACE.debug 5, "value = #{value.inspect}, match = '#{Regexp.last_match[0]}'"

		# move past the token
		@parse_str = Regexp.last_match.post_match

		if token == :string then
			value = value.gsub(/\\"/, "\"").gsub(/\\\\/, "\\")
		end

		$TRACE.debug 5, "out @parse_str = '#{@parse_str}'"

		raise "unexpected token, expected #{expected_token} and got #{token}" if expected_token && expected_token != token
		return [token, value]
	end

	def array_contents
		array = []
		first_time = true
		loop do
			token, value = get_token
			if token == :end_array then
				return array
			elsif token == :comma then	
				if first_time then
					raise "no value before comma in array"
				end
			else
				unget_token(token, value)
				array.push(parse)
			end

			first_time = false
		end
	end

	def hash_contents
		hash = {}
		first_time = true
		loop do
			token, value = get_token
			if token == :end_hash then
				return hash
			elsif token == :comma then	
				if first_time then
					raise "no value before comma in array"
				end
			else
				unget_token(token, value)
				key = parse
				token, value = get_token(:hash_relationship)
				value = parse
				hash[key] = value
			end

			first_time = false
		end
	end

	def object_contents
		$TRACE.debug 5, "object_contents: begin()"
		class_name = ""
		token = nil
		value = nil
		loop do
			token, value = get_token(:identifier)
			class_name += value
			token, value = get_token
			break if token == :colon || token == :identifier
			class_name += "::"
		end

		if token == :colon then
			token, object_id = get_token(:object_id)
		else
			unget_token(token, value)
		end
		
		first_time = true
		object = @object_constructor.create_object(class_name, @context, object_id)
		@objects[object_id] = object unless @objects.has_key?(object_id)

		$TRACE.debug 5, "object_contents: middle(#{class_name})"
		loop do
			token, value = get_token
			$TRACE.debug 5, "object_contents: loop (#{token}, #{value})"

			if token == :end_object then
				return object
			elsif token == :comma
				if first_time then
					raise "no value before comma in array"
				end
			elsif token == :elipsis
				object = @objects[object_id]
			elsif token == :at_sign || token == :identifier
				if token == :at_sign then
					token, instance_variable_name = get_token(:identifier)
					token, value = get_token(:equal)
				else
					instance_variable_name = value
					token, value = get_token(:colon)
				end
				$TRACE.debug 5, "before get value for @#{instance_variable_name}"
$TRACE.debug 5, "b context = #{@context.inspect}"
				@context.push(class_name)
				value = parse
				@context.pop
$TRACE.debug 5, "a context = #{@context.inspect}"

				@object_constructor.create_instance_variable(object.class.to_s, @context, object, instance_variable_name, value)
			end

			first_time = false
		end
		$TRACE.debug 5, "object_contents: end(#{class_name})"
	end
	
	def parse
		token, value = get_token
		case token
		when :number, :string, :time, :symbol
			return value
		when :identifier
			case value
			when "nil":return nil
			when "true": return true
			when "false": return false
			else
				raise "unexpected identifier '#{value}'"
			end
		when :start_array
			return array_contents
		when :start_hash
			return hash_contents
		when :start_object
			return object_contents
		end
	end
end
