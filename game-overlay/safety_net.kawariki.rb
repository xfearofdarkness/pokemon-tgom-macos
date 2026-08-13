# Late-game / latent crash nets for mkxp-z + Essentials 18 (TGOM).
# Installed on_boot after Scripts.rxdata so PE's Ruby Utilities / FileTests
# have already overwritten MRI and we can put safe versions back.
#
# Guards:
#   - MRI String#bytesize / Array#first(n) / empty capitalize
#   - missing Map052–075 / Map087 (leftover Essentials sample IDs)
#   - EISDIR via safeExists?
#   - missing bitmap / empty panorama
#   - .PNG vs .png on case-sensitive volumes
#   - Win32 HTTP / Mystery Gift

STDOUT.sync = true

def tg_map_rxdata_exists?(id)
  return false if id.nil?
  n = id.to_i
  return false if n <= 0
  if respond_to?(:pbRxdataExists?, true)
    return pbRxdataExists?(sprintf("Data/Map%03d", n))
  end
  File.file?(sprintf("Data/Map%03d.rxdata", n))
rescue StandardError
  false
end

def tg_filter_roam_hash!(h)
  return h unless h.is_a?(Hash)
  h.delete_if { |k, _| !tg_map_rxdata_exists?(k) }
  h.each_value do |dests|
    dests.select! { |d| tg_map_rxdata_exists?(d) } if dests.is_a?(Array)
  end
  h
end

Preload.on_boot do |_ctx|
  begin
    TGMriCompat.restore! if defined?(TGMriCompat)
    TGMriCompat.ensure_temp! if defined?(TGMriCompat)
    TGMriCompat.install_safe_exists! if defined?(TGMriCompat)

    # --- refuse to load maps that are not on disk ---
    if defined?(Game_Map)
      Game_Map.class_eval do
        alias_method :__tg_map_setup, :setup unless method_defined?(:__tg_map_setup)
        def setup(map_id)
          unless tg_map_rxdata_exists?(map_id)
            raise Errno::ENOENT, sprintf("Data/Map%03d.rxdata", map_id.to_i)
          end
          __tg_map_setup(map_id)
        end
      end
    end

    if defined?(PokemonMapFactory)
      PokemonMapFactory.class_eval do
        alias_method :__tg_mf_setup, :setup unless method_defined?(:__tg_mf_setup)
        def setup(id)
          unless tg_map_rxdata_exists?(id)
            Preload.print "safety_net: refuse MapFactory.setup(#{id})"
            pbMessage(_INTL("This area is not in this game.")) if respond_to?(:pbMessage)
            return
          end
          __tg_mf_setup(id)
        end

        alias_method :__tg_mf_getmap, :getMap unless method_defined?(:__tg_mf_getmap)
        def getMap(id, add = true)
          unless tg_map_rxdata_exists?(id)
            Preload.print "safety_net: refuse getMap(#{id})"
            return @maps && @maps[0] ? @maps[0] : $game_map
          end
          __tg_mf_getmap(id, add)
        end
      end
    end

    if defined?(Scene_Map)
      Scene_Map.class_eval do
        alias_method :__tg_transfer, :transfer_player unless method_defined?(:__tg_transfer)
        def transfer_player(*args)
          dest = $game_temp && $game_temp.player_new_map_id
          if dest && $game_map && dest != $game_map.map_id && !tg_map_rxdata_exists?(dest)
            $game_temp.player_transferring = false
            $game_temp.transition_processing = false if $game_temp.respond_to?(:transition_processing=)
            pbMessage(_INTL("This area is not in this game.")) if respond_to?(:pbMessage)
            return
          end
          __tg_transfer(*args)
        end

        if method_defined?(:autofade) || private_method_defined?(:autofade)
          alias_method :__tg_autofade, :autofade unless method_defined?(:__tg_autofade)
          def autofade(mapid)
            return unless tg_map_rxdata_exists?(mapid)
            __tg_autofade(mapid)
          end
        end
      end
    end

    if respond_to?(:pbStartOver, true)
      Kernel.send(:alias_method, :__tg_start_over, :pbStartOver) unless Kernel.private_method_defined?(:__tg_start_over)
      Kernel.send(:define_method, :pbStartOver) do |gameover = false|
        if $PokemonGlobal && $PokemonGlobal.pokecenterMapId &&
           $PokemonGlobal.pokecenterMapId >= 0 &&
           !tg_map_rxdata_exists?($PokemonGlobal.pokecenterMapId)
          $PokemonGlobal.pokecenterMapId = -1
        end
        __tg_start_over(gameover)
      end
    end

    if defined?(PokemonRegionMap_Scene)
      PokemonRegionMap_Scene.class_eval do
        alias_method :__tg_healspot, :pbGetHealingSpot unless method_defined?(:__tg_healspot)
        def pbGetHealingSpot(x, y)
          spot = __tg_healspot(x, y)
          return nil if spot && !tg_map_rxdata_exists?(spot[0])
          spot
        end
      end
    end

    if defined?(RoamingAreas) && RoamingAreas.is_a?(Hash)
      tg_filter_roam_hash!(RoamingAreas)
    end
    if defined?(RoamingSpecies) && RoamingSpecies.is_a?(Array)
      RoamingSpecies.each do |entry|
        tg_filter_roam_hash!(entry[5]) if entry.is_a?(Array) && entry[5].is_a?(Hash)
      end
    end

    # --- bitmaps / panoramas ---
    if defined?(AnimatedBitmap)
      AnimatedBitmap.class_eval do
        alias_method :__tg_ab_init, :initialize unless method_defined?(:__tg_ab_init)
        def initialize(file, hue = 0)
          file = "" if file.nil?
          __tg_ab_init(file, hue)
        rescue StandardError
          if defined?(GifBitmap)
            @bitmap = GifBitmap.new("", hue)
          else
            raise
          end
        end
      end
    end

    if defined?(AnimatedPlane)
      AnimatedPlane.class_eval do
        alias_method :__tg_set_pan, :setPanorama unless method_defined?(:__tg_set_pan)
        alias_method :__tg_set_fog, :setFog unless method_defined?(:__tg_set_fog)
        alias_method :__tg_set_bm, :setBitmap unless method_defined?(:__tg_set_bm)

        def setPanorama(file, hue = 0)
          clearBitmaps
          return if file.nil? || file.to_s.empty?
          __tg_set_pan(file, hue)
        rescue StandardError
          @bitmap = nil
        end

        def setFog(file, hue = 0)
          clearBitmaps
          return if file.nil? || file.to_s.empty?
          __tg_set_fog(file, hue)
        rescue StandardError
          @bitmap = nil
        end

        def setBitmap(file, hue = 0)
          clearBitmaps
          return if file.nil? || file.to_s.empty?
          __tg_set_bm(file, hue)
        rescue StandardError
          @bitmap = nil
        end
      end
    end

    if respond_to?(:pbResolveBitmap, true)
      Kernel.send(:alias_method, :__tg_resolve_bitmap, :pbResolveBitmap) unless Kernel.private_method_defined?(:__tg_resolve_bitmap)
      Kernel.send(:define_method, :pbResolveBitmap) do |x|
        ret = __tg_resolve_bitmap(x)
        next ret if ret
        next nil if x.nil? || x == ""
        noext = x.to_s.sub(/\.(bmp|png|gif|jpg|jpeg)\z/i, "")
        found = nil
        %w[.png .PNG .gif .GIF].each do |ext|
          candidate = noext + ext
          if (File.file?(candidate) rescue false)
            found = candidate
            break
          end
        end
        found
      end
    end

    # --- Mystery Gift / Win32 sockets: never crash, never hang ---
    if respond_to?(:pbDownloadData, true)
      Kernel.send(:define_method, :pbDownloadData) { |*_args| "" }
    end
    if respond_to?(:pbPostData, true)
      Kernel.send(:define_method, :pbPostData) { |*_args| "" }
    end
    if respond_to?(:pbDownloadMysteryGift, true)
      Kernel.send(:define_method, :pbDownloadMysteryGift) do |_trainer|
        pbMessage(_INTL("This feature is not in this game.")) if respond_to?(:pbMessage)
        _trainer
      end
    end

    Preload.print "safety_net: MRI restore + missing maps + bitmaps + download stubs"
  rescue => e
    Preload.print "safety_net ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "safety_net: on_boot hook registered"
