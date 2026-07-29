# Fonts + text clip fix for mkxp-z + Pokémon Essentials
#
# Symptom: Power Green (and similar pixel fonts) look "garbled" / cut in half.
# Cause: bitmap.draw_text(x,y,w,h,str) CLIPS to the rect. For these fonts
#        text_size() often under-reports height/width (~half), so glyphs are
#        sliced mid-character. Arial's metrics match FreeType better, so it
#        looked fine.
#
# Fix: expand draw_text rects to at least font.size-based bounds; restore Power Green.

STDOUT.sync = true

DEBUG_FONT = File.join(Dir.pwd, "font_debug.txt")

def tg_force_utf8(str)
  return str if str.nil?
  s = str.to_s
  s = s.dup.force_encoding(Encoding::UTF_8) if s.encoding != Encoding::UTF_8
  s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
rescue StandardError
  str.to_s
end

def tg_clean_font!(font, name, size)
  begin
    font.name = name
  rescue StandardError
    font.name = [name]
  end
  font.size = size
  font.bold = false
  font.italic = false
  font.outline = false if font.respond_to?(:outline=)
  font.shadow  = false if font.respond_to?(:shadow=)
end

def tg_pick_system_font
  if defined?(Font) && Font.respond_to?(:exist?) && Font.exist?("Power Green")
    "Power Green"
  else
    "Arial"
  end
end

def tg_system_font_size(name)
  case name
  when "Power Red and Green", "Pokemon FireLeaf" then 29
  when "Power Green Small", "Pokemon Emerald Small" then 25
  else 31
  end
end

Preload.on_boot do |_ctx|
  begin
    File.open(DEBUG_FONT, "w") { |f| f.puts "fonts_fix boot #{Time.now}" }

    if defined?(FontInstaller)
      def FontInstaller.install
        true
      end
    end

    primary = tg_pick_system_font
    size = tg_system_font_size(primary)

    if defined?(Font)
      Font.default_outline = false if Font.respond_to?(:default_outline=)
      Font.default_shadow  = false if Font.respond_to?(:default_shadow=)
      Font.default_bold    = false if Font.respond_to?(:default_bold=)
      Font.default_italic  = false if Font.respond_to?(:default_italic=)
      begin
        Font.default_name = primary
      rescue StandardError
        Font.default_name = [primary]
      end
      Font.default_size = size if Font.respond_to?(:default_size=)
    end

    if defined?(MessageConfig)
      if MessageConfig.const_defined?(:FontName)
        MessageConfig.send(:remove_const, :FontName)
      end
      MessageConfig.const_set(:FontName, primary)
      if MessageConfig.const_defined?(:FontSubstitutes)
        MessageConfig.send(:remove_const, :FontSubstitutes)
      end
      MessageConfig.const_set(:FontSubstitutes, {
        "Pokemon Emerald" => "Power Green",
        "Pokemon Emerald Narrow" => "Power Green Narrow",
        "Pokemon Emerald Small" => "Power Green Small",
        "Pokemon DP" => "Power Clear",
        "Pokemon RS" => "Power Red and Blue",
        "Pokemon FireLeaf" => "Power Red and Green"
      })
      if MessageConfig.class_variable_defined?(:@@systemFont)
        MessageConfig.class_variable_set(:@@systemFont, nil)
      end
    end

    Kernel.send(:define_method, :pbSetSystemFont) do |bitmap|
      name = tg_pick_system_font
      if defined?(MessageConfig) && MessageConfig.respond_to?(:pbGetSystemFontName)
        n = MessageConfig.pbGetSystemFontName
        name = n if n && n != "" && (Font.exist?(n) rescue true)
      end
      tg_clean_font!(bitmap.font, name, tg_system_font_size(name))
    end

    Kernel.send(:define_method, :pbSetSmallFont) do |bitmap|
      name = (Font.exist?("Power Green Small") ? "Power Green Small" : "Arial" rescue "Arial")
      tg_clean_font!(bitmap.font, name, 25)
    end

    Kernel.send(:define_method, :pbSetNarrowFont) do |bitmap|
      name = (Font.exist?("Power Green Narrow") ? "Power Green Narrow" : "Arial" rescue "Arial")
      tg_clean_font!(bitmap.font, name, 31)
    end

    # ---- Core clip fix: draw_text rect must fit full FreeType glyph bbox ----
    if defined?(Bitmap)
      Bitmap.class_eval do
        alias_method :__tg_draw_text, :draw_text unless method_defined?(:__tg_draw_text)
        alias_method :__tg_text_size, :text_size unless method_defined?(:__tg_text_size)

        def text_size(str)
          # Keep FreeType metrics — inflating height shifts Power Green down in UI
          __tg_text_size(str)
        end

        def draw_text(*args)
          font.outline = false if font.respond_to?(:outline=)
          font.shadow  = false if font.respond_to?(:shadow=)

          begin
            fname = font.name
            fname = fname[0].to_s if fname.is_a?(Array)
            power = fname.to_s.include?("Power")
            if args.length >= 5 && (args[4].is_a?(String) || args[4].is_a?(Numeric))
              # (x, y, width, height, str, align=0)
              str = tg_force_utf8(args[4].to_s)
              args[4] = str
              ts = __tg_text_size(str)
              args[2] = [args[2].to_i, ts.width + 4].max  # width only
              fs = font.size.to_i
              fs = 31 if fs <= 0
              if args[3].to_i > 0 && args[3].to_i < (fs * 0.55)
                args[3] = fs
              end
              # Power Green FreeType baseline sits ~1px low vs Essentials
              args[1] = args[1].to_i - 1 if power
            elsif args.length >= 2 && args[0].is_a?(Rect)
              str = tg_force_utf8(args[1].to_s)
              args[1] = str
              ts = __tg_text_size(str)
              r = args[0]
              nw = [r.width, ts.width + 4].max
              nh = r.height
              fs = font.size.to_i
              fs = 31 if fs <= 0
              nh = fs if nh > 0 && nh < (fs * 0.55)
              ry = power ? r.y - 1 : r.y
              args[0] = Rect.new(r.x, ry, nw, nh)
            end
          rescue StandardError
          end
          __tg_draw_text(*args)
        end
      end
    end

    # Essentials helpers: expand width only; keep original y/height
    if defined?(Kernel) || true
      Kernel.send(:define_method, :pbDrawShadowText) do |bitmap, x, y, width, height, string, baseColor, shadowColor = nil, align = 0|
        return if !bitmap || !string
        string = tg_force_utf8(string)
        ts = bitmap.text_size(string)
        width = (width < 0) ? ts.width + 4 : [width, ts.width + 4].max
        height = (height < 0) ? ts.height : height
        if shadowColor && shadowColor.alpha > 0
          bitmap.font.color = shadowColor
          bitmap.draw_text(x + 2, y, width, height, string, align)
          bitmap.draw_text(x, y + 2, width, height, string, align)
          bitmap.draw_text(x + 2, y + 2, width, height, string, align)
        end
        if baseColor && baseColor.alpha > 0
          bitmap.font.color = baseColor
          bitmap.draw_text(x, y, width, height, string, align)
        end
      end

      Kernel.send(:define_method, :pbDrawOutlineText) do |bitmap, x, y, width, height, string, baseColor, shadowColor = nil, align = 0|
        return if !bitmap || !string
        string = tg_force_utf8(string)
        ts = bitmap.text_size(string)
        width = (width < 0) ? ts.width + 4 : [width, ts.width + 4].max
        height = (height < 0) ? ts.height : height
        if shadowColor && shadowColor.alpha > 0
          bitmap.font.color = shadowColor
          [-2, 0, 2].each do |ox|
            [-2, 0, 2].each do |oy|
              next if ox == 0 && oy == 0
              bitmap.draw_text(x + ox, y + oy, width, height, string, align)
            end
          end
        end
        if baseColor && baseColor.alpha > 0
          bitmap.font.color = baseColor
          bitmap.draw_text(x, y, width, height, string, align)
        end
      end
    end

    if defined?(PokemonLoadPanel)
      PokemonLoadPanel.class_eval do
        alias_method :__tg_refresh, :refresh unless method_defined?(:__tg_refresh)
        def refresh
          __tg_refresh
          begin
            File.open(DEBUG_FONT, "a") do |f|
              f.puts "panel title=#{@title.inspect}"
              if self.bitmap && !self.bitmap.disposed?
                f.puts "  font=#{self.bitmap.font.name.inspect} size=#{self.bitmap.font.size}"
                ts = self.bitmap.text_size(@title.to_s)
                f.puts "  text_size=#{ts.width}x#{ts.height} panel=#{self.bitmap.width}x#{self.bitmap.height}"
              end
            end
          rescue StandardError
          end
        end
      end
    end

    Preload.print "fonts_fix: Power Green, width-only clip (no height inflate / no Y shift)"
    File.open(DEBUG_FONT, "a") { |f| f.puts "primary=#{primary} size=#{size}" }
  rescue => e
    Preload.print "fonts_fix ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "fonts_fix: on_boot hook registered"
