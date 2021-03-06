class Chart
  include ActionView::Helpers
  include ActionView::Context
  
  def initialize(event)
    @event               = event    
    @timezone            = @event.event_timezone
    @flight_data_by_date = @event.flight_data_by_date
    @airport_hues        = @event.airport_hues
    @airport_names       = Airport.airport_names
    
    initialize_settings

  end
  
  # Return HTML and SVG code for arrival and departure charts.
  def draw
    html = ActiveSupport::SafeBuffer.new
    
    html += content_tag(:h2, "Arriving Flights")
    html += draw_direction_charts(@flight_data_by_date, :arrivals)
    html += content_tag(:h2, "Departing Flights")
    html += draw_direction_charts(@flight_data_by_date, :departures)
    
    return html
  end
  
  # Return the airport color array
  def colors
    airport_colors = Hash.new
    @airport_hues.each do |airport, hue|
      airport_colors.store(airport, {background: "#{hue},#{@saturation},#{@lightness_layover_fill}", border: "#{hue},#{@saturation},#{@lightness_flight_fill}"})
    end
    return airport_colors
  end
  
  private
    
    # Define chart visual settings.
    def initialize_settings
      # Settable colors:
      @lightness_flight_fill       = '35%'
      @lightness_flight_text       = '99%'
      @lightness_layover_fill      = '95%'
      @lightness_layover_text      = '30%'
      @lightness_stroke            = '35%'
      @saturation                  = '50%'
      @bar_opacity                 = '0.9'
      @bar_text_opacity            = '1'
  
      # Settable distances (all values in pixels):
      @image_padding               = 15
                               
      @legend_width                = 140
      @legend_height               = 30
      @legend_box_size             = 16
  
      @time_axis_height            = 22
      @time_axis_dst_height        = 18
      @time_axis_padding           = 5
  
      @name_width                  = 130
      @name_height                 = 40
  
      @hour_width                  = 38.5
  
      @flight_bar_height           = 30
      @flight_bar_arrow_width      = 5
      @flight_bar_buffer_width     = 48
      @flight_bar_line_break_width = 50 # If flight bar width is less than this, add a line break
      @flight_bar_no_text_width    = 23 # If flight bar width is less than this, do not display text

      @bar_text_row_y_position = {
        single: [0.61],
        double: [0.41,0.81],
        triple: [0.33,0.63,0.94]
      }
  
      @airport_margin              = 3
  
      # Derived:
      @image_width = @name_width + (24*@hour_width) + 2*@image_padding + @time_axis_padding + @flight_bar_buffer_width
      @flight_bar_margin = (@name_height - @flight_bar_height) / 2
  
      @chart_top = @image_padding + @legend_height + @time_axis_height
      @chart_left = @image_padding + @name_width
      @chart_right = @chart_left + (24 * @hour_width)
      @chart_width = @chart_right - @chart_left
  
    end
    
    # Take a date and two times, and return a hash containing a string of the
    # SVG polygon points for a time bar, the left side of the bar, and the
    # right side of the bar.
    # Params:
    # +day_time_range_utc+:: A range of UTC times for the local day this bar is being plotted on
    # +bar_time_range_utc+:: A range of UTC times for the duration of the bar
    # +row+:: Which row the bar belongs in (zero-indexed)
    def bar_points(day_time_range_utc, bar_time_range_utc, row)
      # Ensure ranges overlap:
      return nil unless (day_time_range_utc.begin <= bar_time_range_utc.end && bar_time_range_utc.begin <= day_time_range_utc.end)
      
      points = Array.new
      top = flight_bar_top(row)
      middle = top + @flight_bar_height/2
      bottom = top + @flight_bar_height
            
      # Check if bar starts today or before today
      if day_time_range_utc.include?(bar_time_range_utc.begin)
        # Draw left bar edge
        left_side = x_position_in_local_day(day_time_range_utc, bar_time_range_utc.begin)
        points.push("#{left_side},#{bottom}")
        points.push("#{left_side},#{top}")
      else
        # Draw left arrow edge
        left_side = @chart_left
        points.push("#{left_side},#{bottom}")
        points.push("#{left_side - @flight_bar_arrow_width},#{middle}")
        points.push("#{left_side},#{top}")     
      end

      # Check if bar ends today or after today
      if day_time_range_utc.include?(bar_time_range_utc.end)
        # Draw right bar edge
        right_side = x_position_in_local_day(day_time_range_utc, bar_time_range_utc.end)
        points.push("#{right_side},#{top}")
        points.push("#{right_side},#{bottom}")
      else
        # Draw right arrow edge
        right_side = @chart_right
        points.push("#{right_side},#{top}")
        points.push("#{right_side + @flight_bar_arrow_width},#{middle}")
        points.push("#{right_side},#{bottom}")
      end

      return {points: points.join(" "), left: left_side, right: right_side}
    
    end
    
    # Return a hash of departures and arrivals, with :arrivals or :departures as
    # the keys and ranges of dates as the values.
    # Params:
    # +traveler_array+:: A traveler array for a single direction (arrivals or departures)
    def date_range(traveler_array)
    	date_range = [nil,nil];
	
    	traveler_array.each do |traveler|
    		traveler[:flights].each do |flight|
          origin_date_event      = flight.origin_time.in_time_zone(@timezone).to_date
          destination_date_event = flight.destination_time.in_time_zone(@timezone).to_date
          
          if (date_range[0].nil? || origin_date_event < date_range[0])
    				date_range[0] = origin_date_event
    			end
    			if (date_range[1].nil? || destination_date_event > date_range[1])
    				date_range[1] = destination_date_event
    			end
    		end
    	end
    
      return date_range
    end
    
    # Accept a date and a direction, and return a chart showing all applicable
    # flights and layovers on that date.
    # Params: 
    # +date_local+:: The date to show (in the timezone of the event)
    # +date_local_data+:: A date hash (from Event.flight_data_by_date)
    # +direction+:: Arrivals (:arrivals) or departures (:departures)
    def draw_date_chart(date_local, date_local_data, direction)
      number_of_rows = date_local_data[:travelers].count
      return nil unless number_of_rows > 0
      
      html = ActiveSupport::SafeBuffer.new
      chart_height = @name_height * number_of_rows
      image_height = @chart_top + chart_height + @image_padding
      
      html += content_tag(:h3, date_local.strftime("%A, %-d %B %Y"))
      html += content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", "xmlns:xlink": "http://www.w3.org/1999/xlink", width: @image_width, height: image_height) do
        # Draw background:
        concat(content_tag(:rect, "", width: @image_width, height: image_height, class: "svg_background"))

        # Draw legend:
        @airport_hues.each_with_index do |(airport, hue), index|
          legend_left = @chart_right - ((@airport_hues.length - index) * @legend_width)
          text_left = legend_left + (@legend_box_size * 1.25)
          arriving_departing = (direction == :arrivals) ? "Arriving at" : "Departing from"
          concat(content_tag(:g, cursor: "default") do
            concat(content_tag(:title, @airport_names[airport] || airport))
            concat(content_tag(:rect, "", width: @legend_box_size, height: @legend_box_size, x: legend_left, y: @image_padding, fill: "hsl(#{hue},#{@saturation},#{@lightness_flight_fill})", "fill-opacity": @bar_opacity, stroke: "hsl(#{hue},#{@saturation},#{@lightness_stroke})", "stroke-opacity": @bar_opacity))
            concat(content_tag(:text, arriving_departing + " " + airport, x: text_left, y: @image_padding + @legend_box_size*0.75, "text-anchor": "start"))
          end)
        end

        # Draw chart grid:
        key_airports = date_local_data[:travelers].map{|k,v| v[:key_code]}
        prior_key_airport = nil
        for x in 0..number_of_rows
          current_key_airport = key_airports[x]
          majmin = current_key_airport == prior_key_airport ? "minor" : "major"
          prior_key_airport = current_key_airport
          html += %Q(\t<line x1="#{@image_padding}" y1="#{@chart_top + x * @name_height}" x2="#{@image_padding + @name_width + 24 * @hour_width}" y2="#{@chart_top + x * @name_height}" class="svg_gridline_#{majmin}_horizontal" />\n)
        end
        day_time_range_utc = date_local_data[:start_time_utc]..date_local_data[:end_time_utc]
        day_time_range_local = date_local_data[:start_time_utc].in_time_zone(@timezone)..date_local_data[:end_time_utc].in_time_zone(@timezone)

        if day_time_range_local.begin.gmt_offset == day_time_range_local.end.gmt_offset
          # No DST switch; show one time label row
          concat(content_tag(:text, day_time_range_utc.begin.in_time_zone(@timezone).strftime("(%:z) %Z"), x: @image_padding, y: @chart_top - @time_axis_padding, "text-anchor": "left", class: "svg_time_label"))
          for x in 0..24
            concat(content_tag(:text, time_label(x), x: @chart_left + (x * @hour_width), y: @chart_top - @time_axis_padding, "text-anchor": "middle", class: "svg_time_label"))
            concat(content_tag(:line, nil, x1: @chart_left + (x * @hour_width), y1: @chart_top, x2: @image_padding + @name_width + (x * @hour_width), y2: @chart_top + chart_height, class: (x % 12 == 0 ? "svg_gridline_major" : "svg_gridline_minor")))
          end
        else
          # DST switch; show two time label rows
          seconds_in_day = (day_time_range_utc.end - day_time_range_utc.begin).to_i
          dst_hour_width = @chart_width/(seconds_in_day/3600.0) # Must use float to handle non-hour DST offset
          hours_in_day = seconds_in_day/3600

          concat(content_tag(:text, day_time_range_local.begin.strftime("(%:z) %Z"), x: @image_padding, y: @chart_top - @time_axis_dst_height - @time_axis_padding, "text-anchor": "let", class: "svg_time_label"))
          for x in 0..hours_in_day
            this_time = day_time_range_utc.begin + x.hours
            concat(content_tag(:text, time_label(x), x: @chart_left + (x * dst_hour_width), y: @chart_top - @time_axis_dst_height - @time_axis_padding, "text-anchor": "middle", class: "svg_time_label"))
            if this_time.in_time_zone(@timezone).gmt_offset != day_time_range_local.begin.gmt_offset
              concat(content_tag(:line, nil, x1: @chart_left + (x * dst_hour_width), y1: @chart_top, x2: @chart_left + (x * dst_hour_width), y2: @chart_top + chart_height, class: "svg_gridline_dst_switch"))
              switch_x = x
              break
            end
            concat(content_tag(:line, nil, x1: @chart_left + (x * dst_hour_width), y1: @chart_top, x2: @chart_left + (x * dst_hour_width), y2: @chart_top + chart_height, class: (x % 12 == 0 ? "svg_gridline_major" : "svg_gridline_minor")))
          end
          concat(content_tag(:text, day_time_range_local.end.strftime("(%:z) %Z"), x: @image_padding, y: @chart_top - @time_axis_padding, "text-anchor": "left", class: "svg_time_label"))
          for x in 0..(hours_in_day-switch_x)
            this_time = day_time_range_utc.end - x.hours
            concat(content_tag(:text, time_label(24-x), x: @chart_right - (x * dst_hour_width), y: @chart_top - @time_axis_padding, "text-anchor": "middle", class: "svg_time_label"))
            concat(content_tag(:line, nil, x1: @chart_right - (x * dst_hour_width), y1: @chart_top, x2: @chart_right - (x * dst_hour_width), y2: @chart_top + chart_height, class: (x % 12 == 0 ? "svg_gridline_major" : "svg_gridline_minor"))) unless (x == hours_in_day-switch_x && seconds_in_day%3600 == 0)
          end
        end
        
        # Draw traveler rows:
        date_local_data[:travelers].each_with_index do |(traveler_id, traveler), index|
          concat(draw_row(direction, day_time_range_utc, traveler_id, traveler, index))
        end
      end
      
      return html
      
    end
    
    # Return the HTML and SVG for all flight charts in a given direction.
    # Params:
    # +data_by_date+:: The hash generated by Event.flight_data_by_date
    # +direction+:: Arrivals (:arrivals) or departures (:departures)
    def draw_direction_charts(data_by_date, direction)
      html = ActiveSupport::SafeBuffer.new
      
      if data_by_date[direction].any?
        data_by_date[direction].each do |date_local, date_local_data|
          html += draw_date_chart(date_local, date_local_data, direction)
        end
      else
        direction_text = direction == :arrivals ? "arriving" : "departing"
        html += content_tag(:p, "When #{direction_text} flights are added to any traveler, the flights will show up here.")
      end
        
      return html
    end
    
    # Return the SVG for an individual flight bar.
    # Params:
    # +day_time_range_utc+:: A range of UTC times for the local day this flight is being plotted on
    # +row+:: Which row the flight bar belongs in (zero-indexed)
    # +hue+:: Hue value for this flight bar
    # +flight+:: Flight data hash to draw bar for
  	def draw_flight_bar(day_time_range_utc, row, hue, flight)
      html = ActiveSupport::SafeBuffer.new
      
      flight_time_range_utc = flight[:origin_time_utc]..flight[:destination_time_utc]
      flight_time_range_local = flight[:origin_time_utc].in_time_zone(@timezone)..flight[:destination_time_utc].in_time_zone(@timezone)
      
      bar_values = bar_points(day_time_range_utc, flight_time_range_utc, row)
      return nil if bar_values.nil?
      points     = bar_values[:points]
      left_side  = bar_values[:left]
      right_side = bar_values[:right]
      width      = right_side - left_side

      html += content_tag(:g, id: "flight-#{flight[:id]}", cursor: "default") do
        # Draw tooltip:
        title  = "#{flight[:airline_name]} #{flight[:flight_number]}\n"
        title += "#{flight[:origin_time_local].strftime("%-l:%M%P %Z")}\t#{flight[:origin_name]} (#{flight[:origin_code]})\n"
        title += "#{flight[:destination_time_local].strftime("%-l:%M%P %Z")}\t#{flight[:destination_name]} (#{flight[:destination_code]})\n"
        concat(content_tag(:title, title))

        # Draw flight bar:
        concat(content_tag(:polygon, nil, id: "flight-#{flight[:id]}", points: points, class: "svg_bar", fill: "hsl(#{hue},#{@saturation},#{@lightness_flight_fill})", stroke: "hsl(#{hue},#{@saturation},#{@lightness_stroke})", "fill-opacity": @bar_opacity, "stroke-opacity": @bar_opacity))

        # Draw flight number:
        if width >= @flight_bar_no_text_width
          if width < @flight_bar_line_break_width
            concat(content_tag(:text, flight[:airline_code], x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height * @bar_text_row_y_position[:double][0], class: "svg_flight_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_flight_text})", "fill-opacity": @bar_text_opacity))
            concat(content_tag(:text, flight[:flight_number], x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height * @bar_text_row_y_position[:double][1], class: "svg_flight_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_flight_text})", "fill-opacity": @bar_text_opacity))
          else
            concat(content_tag(:text, "#{flight[:airline_code]} #{flight[:flight_number]}", x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height * @bar_text_row_y_position[:single][0], class: "svg_flight_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_flight_text})", "fill-opacity": @bar_text_opacity))
          end
        end

      end
      
      return html
    end
    
    # Return the SVG for an individual layover bar.
    # Params:
    # +day_time_range_utc+:: A range of UTC times for the local day this layover is being plotted on
    # +row+:: Which row the layover bar belongs in (zero-indexed)
    # +hue+:: Hue value for this layover bar
    # +layover+:: Layover data hash to draw bar for
    def draw_layover_bar(day_time_range_utc, row, hue, layover)
      html = ActiveSupport::SafeBuffer.new
      
      layover_time_range_utc = layover[:start_time_utc]..layover[:end_time_utc]
      layover_time_range_local = layover[:start_time_local]..layover[:end_time_local]
      
      bar_values = bar_points(day_time_range_utc, layover_time_range_utc, row)
      return nil if bar_values.nil?
      points     = bar_values[:points]
      left_side  = bar_values[:left]
      right_side = bar_values[:right]
      width      = right_side - left_side

      html += content_tag(:g, cursor: "default") do
        # Draw tooltip:
        if layover[:start_code] == layover[:end_code]
          title = "Layover at #{layover[:start_name]} (#{layover[:start_code]})\n"
        else
          title = "Layover between #{layover[:start_name]} (#{layover[:start_code]}) and #{layover[:end_name]} (#{layover[:end_code]})\n"
        end
        title += time_range(layover_time_range_local, layover_time_range_local.begin.strftime("%Z"))
        concat(content_tag(:title, title))

        # Draw layover bar:
        concat(content_tag(:polygon, nil, points: points, class: "svg_bar", fill: "hsl(#{hue},#{@saturation},#{@lightness_layover_fill})", stroke: "hsl(#{hue},#{@saturation},#{@lightness_stroke})", "fill-opacity": @bar_opacity, "stroke-opacity": @bar_opacity))

        # Draw layover airport label:
        if width >= @flight_bar_no_text_width
          if layover[:start_code] == layover[:end_code]
            concat(content_tag(:text, layover[:start_code], x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height*@bar_text_row_y_position[:single][0], class: "svg_layover_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_layover_text})", "fill-opacity": @bar_text_opacity))
          else
            concat(content_tag(:text, layover[:start_code], x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height*@bar_text_row_y_position[:double][0], class: "svg_layover_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_layover_text})", "fill-opacity": @bar_text_opacity))
            concat(content_tag(:text, layover[:end_code], x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height*@bar_text_row_y_position[:double][1], class: "svg_layover_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_layover_text})", "fill-opacity": @bar_text_opacity))
          end
        else
          if layover[:start_code] == layover[:end_code]
            @bar_text_row_y_position[:triple].each_with_index do |ypos, index|
              concat(content_tag(:text, layover[:start_code][index], x: (left_side + right_side) / 2, y: flight_bar_top(row) + @flight_bar_height*ypos, class: "svg_layover_text", fill: "hsl(#{hue},#{@saturation},#{@lightness_layover_text})", "fill-opacity": @bar_text_opacity))
            end
          end
        end

      end
    
    	return html
    end
    
    # Return the SVG for a particular chart row.
    # Params:
    # +direction+:: Arrivals (:arrivals) or departures (:departures)
    # +day_time_range_utc+:: A range of UTC times for the local day this row is being plotted on
    # +traveler_id+:: ID of the traveler being plotted
    # +traveler_data+:: Hash of traveler data
    # +row_index+:: Which row the layover bar belongs in (zero-indexed)
    def draw_row(direction, day_time_range_utc, traveler_id, traveler_data, row_index)
      html = ActiveSupport::SafeBuffer.new
      
      hue = @airport_hues[traveler_data[:key_code]]

      html += content_tag(:a, "xlink:href": "#t-#{traveler_id}") do
        concat(content_tag(:text, traveler_data[:name], x: @image_padding, y: flight_bar_top(row_index) + (@flight_bar_height * 0.4), class: "svg_person_name"))
        concat(content_tag(:text, traveler_data[:note], x: @image_padding, y: flight_bar_top(row_index) + (@flight_bar_height * 0.9), class: "svg_person_nickname"))
      end
      
      # Draw flights:
      traveler_data[:flights].each do |flight|
        html += draw_flight_bar(day_time_range_utc, row_index, hue, flight)
      end
      
      # Draw layovers:
      traveler_data[:layovers].each do |layover|
        html += draw_layover_bar(day_time_range_utc, row_index, hue, layover)
      end

      # Draw airport codes and times at each end of each flight bar:
      
      if direction == :arrivals
        travel_start_time_utc = traveler_data[:alt_time_utc]
        travel_end_time_utc   = traveler_data[:key_time_utc]
      else
        travel_start_time_utc = traveler_data[:key_time_utc]
        travel_end_time_utc   = traveler_data[:alt_time_utc]
      end
      start_x = x_position_in_local_day(day_time_range_utc, travel_start_time_utc)
      end_x   = x_position_in_local_day(day_time_range_utc, travel_end_time_utc)
      if start_x
        html += content_tag(:g, cursor: "default") do
          concat(content_tag(:title, traveler_data[:flights].first[:origin_name]))
          concat(content_tag(:text, traveler_data[:flights].first[:origin_code], x: start_x - @airport_margin, y: flight_bar_top(row_index) + @flight_bar_height * 0.42, class: %w(svg_airport_label svg_airport_block_start)))
          concat(content_tag(:text, format_time_short(travel_start_time_utc.in_time_zone(@timezone)), x: start_x - @airport_margin, y: flight_bar_top(row_index) + @flight_bar_height * 0.92, class: %w(svg_time_label svg_airport_block_start)))
        end
      end
      if end_x
        html += content_tag(:g, cursor: "default") do
          concat(content_tag(:title, traveler_data[:flights].last[:destination_name]))
          concat(content_tag(:text, traveler_data[:flights].last[:destination_code], x: end_x + @airport_margin, y: flight_bar_top(row_index) + @flight_bar_height * 0.42, class: %w(svg_airport_label svg_airport_block_end)))
          concat(content_tag(:text, format_time_short(travel_end_time_utc.in_time_zone(@timezone)), x: end_x + @airport_margin, y: flight_bar_top(row_index) + @flight_bar_height * 0.92, class: %w(svg_time_label svg_airport_block_end)))
        end
      end
      
      return html
    end
    
    # Take two times, and return a string showing the elapsed time in hours and
    # minutes.
    # Params:
    # +time_range+:: A range of Time objects
    def elapsed_time(time_range)
      diff_hour = ((time_range.end - time_range.begin) / 3600).to_i
      diff_minute = (((time_range.end - time_range.begin) / 60) % 60).to_i
      "#{diff_hour}h #{diff_minute}m"
    end
    
    # Return the y position of the top of the flight bar of a given row.
    # Params:
    # +row_number+:: Row number (zero-indexed)
    def flight_bar_top(row_number)
    	return @chart_top + (row_number * @name_height) + @flight_bar_margin
    end
    
    # Return a formatted time string.
    # Params:
    # +time+:: The time to format
    def format_time(time)
      time.strftime("%l:%M%P").strip
    end
    
    # Return a formatted time string.
    # Params:
    # +time+:: The time to format
    def format_time_short(time)
      time.strftime("%l:%M%P").chomp('m')
    end
    
    # Creates a string for a given hour to label the chart x-axis.
    # Params:
    # +hour+:: The hour to format    
    def time_label(hour)
    	case hour
    	when 0
    		return "mdnt"
    	when 1..11
    		return hour.to_s + "am"
    	when 12
    		return "noon"
    	when 13..23
    		return (hour - 12).to_s + "pm"
    	when 24
    		return "mdnt"
    	end
    end
    
    # Return a string containing a time range and elapsed time.
    # Params:
    # +start_time+:: Start time
    # +end_time+:: End time
    # +timezone+:: String containing the timezone of the direction
    def time_range(time_range_utc, timezone)
      html = "#{format_time(time_range_utc.begin)} – #{format_time(time_range_utc.end)} #{timezone} "
      html += "(#{elapsed_time(time_range_utc)})"
    end
    
    # Return an x position for a UTC time based on a given UTC time range.
    # Params:
    # +day_time_range_utc+:: The UTC range to position the time in
    # +time_utc+:: The UTC time to position in the range
    def x_position_in_local_day(day_time_range_utc, time_utc)
      return nil unless day_time_range_utc.include?(time_utc)
      return ((time_utc - day_time_range_utc.begin) / (day_time_range_utc.end - day_time_range_utc.begin)) * @chart_width + @chart_left
    end
  
end