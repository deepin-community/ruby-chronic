module Chronic
  class RepeaterTime < Repeater #:nodoc:
    class Tick #:nodoc:
      attr_accessor :time

      def initialize(time, ambiguous = false)
        @time = time
        @ambiguous = ambiguous
      end

      def ambiguous?
        @ambiguous
      end

      def *(other)
        Tick.new(@time * other, @ambiguous)
      end

      def to_f
        @time.to_f
      end

      def to_s
        @time.to_s + (@ambiguous ? '?' : '')
      end

    end

    def initialize(time, options = {})
      @current_time = nil
      @options = options
      time_parts = time.split(':')
      raise ArgumentError, "Time cannot have more than 4 groups of ':'" if time_parts.count > 4

      if time_parts.first.length > 2 and time_parts.count == 1
        if time_parts.first.length > 4
          second_index = time_parts.first.length - 2
          time_parts.insert(1, time_parts.first[second_index..time_parts.first.length])
          time_parts[0] = time_parts.first[0..second_index - 1]
        end
        minute_index = time_parts.first.length - 2
        time_parts.insert(1, time_parts.first[minute_index..time_parts.first.length])
        time_parts[0] = time_parts.first[0..minute_index - 1]
      end

      ambiguous = false
      hours = time_parts.first.to_i

      if @options[:hours24].nil? or (not @options[:hours24].nil? and @options[:hours24] != true)
          ambiguous = true if (time_parts.first.length == 1 and hours > 0) or (hours >= 10 and hours <= 12) or (@options[:hours24] == false and hours > 0)
          hours = 0 if hours == 12 and ambiguous
      end

      hours *= 60 * 60
      minutes = 0
      seconds = 0
      subseconds = 0

      minutes = time_parts[1].to_i * 60 if time_parts.count > 1
      seconds = time_parts[2].to_i if time_parts.count > 2
      subseconds = time_parts[3].to_f / (10 ** time_parts[3].length) if time_parts.count > 3

      @type = Tick.new(hours + minutes + seconds + subseconds, ambiguous)
    end

    # Return the next past or future Span for the time that this Repeater represents
    #   pointer - Symbol representing which temporal direction to fetch the next day
    #             must be either :past or :future
    def next(pointer)
      super

      half_day = 60 * 60 * 12
      full_day = 60 * 60 * 24

      first = false

      unless @current_time
        first = true
        midnight = Chronic.time_class.local(@now.year, @now.month, @now.day)

        yesterday_midnight = midnight - full_day
        tomorrow_midnight = midnight + full_day

        catch :done do
          if pointer == :future
            if @type.ambiguous?
              [midnight, midnight + half_day, tomorrow_midnight].each do |base_time|
                t = adjust_daylight_savings_offset(midnight, base_time + @type.time)
                (@current_time = t; throw :done) if t >= @now
              end
            else
              [midnight, tomorrow_midnight].each do |base_time|
                t = adjust_daylight_savings_offset(midnight, base_time + @type.time)
                (@current_time = t; throw :done) if t >= @now
              end
            end
          else # pointer == :past
            if @type.ambiguous?
              [midnight + half_day, midnight, yesterday_midnight + half_day].each do |base_time|
                t = adjust_daylight_savings_offset(midnight, base_time + @type.time)
                (@current_time = t; throw :done) if t <= @now
              end
            else
              [midnight, yesterday_midnight].each do |base_time|
                t = adjust_daylight_savings_offset(midnight, base_time + @type.time)
                (@current_time = t; throw :done) if t <= @now
              end
            end
          end
        end

        @current_time || raise("Current time cannot be nil at this point")
      end

      unless first
        increment = @type.ambiguous? ? half_day : full_day
        @current_time += pointer == :future ? increment : -increment
      end

      Span.new(@current_time, @current_time + width)
    end

    # Every time a time crosses a Daylight Savings interval we must adjust the
    # current time by that amount. For example, if we take midnight of Daylight
    # Savings and only add an hour, the offset does not change:
    #
    # Time.parse('2008-03-09 00:00')
    # => 2008-03-09 00:00:00 -0800
    # Time.parse('2008-03-09 00:00') + (60 * 60)
    # => 2008-03-09 01:00:00 -0800
    #
    # However, if we add 2 hours, we notice the time advances to 03:00 instead of 02:00:
    #
    # Time.parse('2008-03-09 00:00') + (60 * 60 * 2)
    # => 2008-03-09 03:00:00 -0700
    #
    # Since we gained an hour and we actually want 02:00, we subtract an hour.
    def adjust_daylight_savings_offset(base_time, current_time)
      offset_fix = base_time.gmt_offset - current_time.gmt_offset
      current_time + offset_fix
    end

    def this(context = :future)
      super

      context = :future if context == :none

      self.next(context)
    end

    def width
      1
    end

    def to_s
      super << '-time-' << @type.to_s
    end
  end
end
