# Character / New Game fixes for mkxp-z + Essentials 18
# - EISDIR on Graphics/Characters/ when name is empty
# - GifBitmap placeholder must set @currentIndex
# - Empty charset: hide sprite, do not leave bad cw/ch/ox/oy
# - On charset change: recompute ox/oy from real sheet (32x48 frames for trchar*)

STDOUT.sync = true

Preload.on_boot do |_ctx|
  begin
    Kernel.send(:define_method, :pbGetFileChar) do |file|
      return nil if file.nil? || file == ""
      file = canonicalize(file) rescue file
      begin
        return nil if File.directory?(file)
      rescue StandardError
      end
      if !safeExists?("./Game.rgssad") && !safeExists?("./Game.rgss2a")
        return nil if !safeExists?(file)
        begin
          File.open(file, "rb") { |f| return f.read(1) }
        rescue Errno::ENOENT, Errno::EINVAL, Errno::EACCES, Errno::EISDIR
          return nil
        end
      end
      if defined?(Marshal) && Marshal.respond_to?(:neverload=)
        Marshal.neverload = true
      end
      str = nil
      begin
        str = load_data(file)
      rescue Errno::ENOENT, Errno::EINVAL, Errno::EACCES, Errno::EISDIR, RGSSError
        str = nil
      ensure
        Marshal.neverload = false if defined?(Marshal) && Marshal.respond_to?(:neverload=)
      end
      str
    end

    Kernel.send(:define_method, :pbGetFileString) do |file|
      return nil if file.nil? || file == ""
      file = canonicalize(file) rescue file
      begin
        return nil if File.directory?(file)
      rescue StandardError
      end
      if !(safeExists?("./Game.rgssad") || safeExists?("./Game.rgss2a"))
        return nil if !safeExists?(file)
        begin
          File.open(file, "rb") { |f| return f.read }
        rescue Errno::ENOENT, Errno::EINVAL, Errno::EACCES, Errno::EISDIR
          return nil
        end
      end
      if defined?(Marshal) && Marshal.respond_to?(:neverload=)
        Marshal.neverload = true
      end
      str = nil
      begin
        str = load_data(file)
      rescue Errno::ENOENT, Errno::EINVAL, Errno::EACCES, Errno::EISDIR, RGSSError
        str = nil
      ensure
        Marshal.neverload = false if defined?(Marshal) && Marshal.respond_to?(:neverload=)
      end
      str
    end

    if defined?(GifBitmap)
      GifBitmap.class_eval do
        alias_method :__tg_gif_init, :initialize unless method_defined?(:__tg_gif_init)

        def initialize(file, hue = 0)
          path = file.nil? ? "" : file.to_s
          base = File.basename(path.chomp("/").chomp("\\"))
          if path.empty? || base.empty? || path.end_with?("/") || path.end_with?("\\") ||
             (File.directory?(path) rescue false)
            # Transparent-ish placeholder matching trchar frame size (32x48 * 4x4)
            @gifbitmaps   = [BitmapWrapper.new(128, 192)]
            @gifdelays    = [1]
            @totalframes  = 2
            @framecount   = 0
            @currentIndex = 0
            @disposed     = false
            return
          end
          __tg_gif_init(file, hue)
        end

        alias_method :__tg_gif_bitmap, :bitmap unless method_defined?(:__tg_gif_bitmap)
        def bitmap
          idx = @currentIndex
          idx = 0 if idx.nil?
          bm = @gifbitmaps[idx]
          bm = @gifbitmaps[0] if bm.nil? && @gifbitmaps && @gifbitmaps[0]
          bm
        end
      end
    end

    if defined?(Sprite_Character)
      Sprite_Character.class_eval do
        alias_method :__tg_sc_update, :update unless method_defined?(:__tg_sc_update)

        def tg_apply_charset_metrics!
          return if !@charbitmap
          begin
            bw = @charbitmapAnimated ? @charbitmap.width : @charbitmap.width
            bh = @charbitmapAnimated ? @charbitmap.height : @charbitmap.height
          rescue StandardError
            return
          end
          return if bw.to_i <= 0 || bh.to_i <= 0
          if @tile_id.to_i >= 384
            @cw = Game_Map::TILE_WIDTH
            @ch = Game_Map::TILE_HEIGHT
          else
            @cw = bw / 4
            @ch = bh / 4
            @cw = 32 if @cw <= 0
            @ch = 48 if @ch <= 0
          end
          self.ox = @cw / 2
          self.oy = (@spriteoffset rescue false) ? @ch - 16 : @ch
          @character.sprite_size = [@cw, @ch] if @character && @character.respond_to?(:sprite_size=)
        end

        def update
          return if @character.is_a?(Game_Event) && !@character.should_update?

          cname = (@character.character_name rescue nil).to_s
          # Empty graphic: keep invisible, stay synced to map tile (no junk sheet)
          if cname == "" && @character.tile_id.to_i < 384
            if @charbitmap
              begin
                @charbitmap.dispose
              rescue StandardError
              end
              @charbitmap = nil
            end
            @charbitmapAnimated = false
            @bushbitmap.dispose if @bushbitmap
            @bushbitmap = nil
            @character_name = ""
            @tile_id = @character.tile_id
            @cw ||= 32
            @ch ||= 48
            self.bitmap = nil
            self.visible = false
            self.x = @character.screen_x
            self.y = @character.screen_y
            self.z = @character.screen_z(@ch)
            self.opacity = @character.opacity
            self.ox = @cw / 2
            self.oy = @ch
            return
          end

          old_name = @character_name
          old_tile = @tile_id
          __tg_sc_update

          # After any charset/tile change, force correct origin from real bitmap size
          if @character_name != old_name || @tile_id != old_tile || (@cw.to_i <= 0)
            tg_apply_charset_metrics!
          end

          # Perspective tilemap mode overwrites x/y after super — re-assert ox/oy only
          if @cw.to_i > 0
            self.ox = @cw / 2
            self.oy = (@spriteoffset rescue false) ? @ch - 16 : @ch unless @tile_id.to_i >= 384
          end
        end
      end
    end

    # When gender/player graphic changes, refresh charset immediately at current tile
    if defined?(Kernel) || true
      if defined?(pbChangePlayer)
        alias_method_ok = false
      end
      Kernel.send(:define_method, :pbChangePlayer) do |id|
        return false if id < 0 || id >= 8
        meta = pbGetMetadata(0, MetadataPlayerA + id)
        return false if !meta
        $Trainer.trainertype = meta[0] if $Trainer
        $PokemonGlobal.playerID = id
        $Trainer.metaID = id if $Trainer
        if $game_player
          $game_player.character_hue = 0
          # Prefer walk charset (meta[1]); force string so Sprite_Character reloads
          new_name = meta[1].to_s
          $game_player.character_name = new_name
          $game_player.charsetData = nil if $game_player.respond_to?(:charsetData=)
          # Snap real coords to tile (avoids one-frame jump from stale subpixels)
          if defined?(Game_Map::REAL_RES_X)
            $game_player.instance_variable_set(:@real_x, $game_player.x * Game_Map::REAL_RES_X)
            $game_player.instance_variable_set(:@real_y, $game_player.y * Game_Map::REAL_RES_Y)
          end
        end
        true
      end
    end

    # Gender select uses Show Picture trainer000/001 (NOT map events / trchar*).
    # Original Map001 put male at x=-180 (off-screen left on 512-wide). Safety net
    # if Map001 is restored from backup without the coordinate fix.
    if defined?(Game_Picture)
      Game_Picture.class_eval do
        alias_method :__tg_pic_show, :show unless method_defined?(:__tg_pic_show)
        alias_method :__tg_pic_move, :move unless method_defined?(:__tg_pic_move)

        def show(name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
          n = name.to_s
          if n == "trainer000" && x.to_i < 0
            # Left of stage (introbase center ~256,256)
            x = (Graphics.width / 2) - 80
            y = 200 if y.to_i == 178 || y.to_i < 0
            origin = 1
          elsif n == "trainer001" && x.to_i > 0 && x.to_i < (Graphics.width / 2)
            # Only remap classic "x=180" placement to right of stage
            if x.to_i <= 200
              x = (Graphics.width / 2) + 80
              y = 200 if y.to_i == 178 || y.to_i < 0
              origin = 1
            end
          end
          __tg_pic_show(name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
        end

        def move(duration, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
          # After gender pick, original moved chosen portrait to (0,0) UL — glitchy.
          # If name is a trainer portrait and target is origin corner, use stage center.
          if (@name.to_s == "trainer000" || @name.to_s == "trainer001") &&
             x.to_i == 0 && y.to_i == 0 && origin.to_i == 0
            origin = 1
            x = Graphics.width / 2
            y = 200
          end
          __tg_pic_move(duration, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
        end
      end
    end

    Preload.print "map_fix: charset + gender pictures + pbChangePlayer"
  rescue => e
    Preload.print "map_fix ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "map_fix: on_boot hook registered"
