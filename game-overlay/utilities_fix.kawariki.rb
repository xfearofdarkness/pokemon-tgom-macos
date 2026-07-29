# Safety net for Kawariki's dummyPSystem_Utilities full-replace of PSystem_Utilities.
# Even with the rebuilt Essentials-18 dummy, re-assert critical APIs after boot so
# bag pickup / give-pokemon / dex never die on stale PE17 leftovers.
#
# Known failure modes this guards:
#   - ItemStorageHelper.pbStoreItem → POCKETAUTOSORT (old dummy clobber)
#   - missing pbGetSpeciesFromFSpecies / pbGetFSpeciesFromForm
#   - missing pbGetRegionalDexLength
#   - missing ItemStorageHelper.pbStoreAllOrNone

STDOUT.sync = true

Preload.on_boot do |_ctx|
  begin
    # --- fSpecies helpers (Essentials 18 forms) — always reinstall ---
    Kernel.send(:define_method, :pbGetFSpeciesFromForm) do |species, form = 0|
      return species if form == 0
      ret = species
      species = pbGetSpeciesFromFSpecies(species)[0] if species > PBSpecies.maxValue
      formData = pbLoadFormToSpecies
      if formData[species] && formData[species][form] && formData[species][form] > 0
        ret = formData[species][form]
      end
      ret
    end

    Kernel.send(:define_method, :pbGetSpeciesFromFSpecies) do |species|
      return [species, 0] if species <= PBSpecies.maxValue
      formdata = pbLoadFormToSpecies
      for i in 1...formdata.length
        next if !formdata[i]
        for j in 0...formdata[i].length
          return [i, j] if formdata[i][j] == species
        end
      end
      [species, 0]
    end

    Kernel.send(:define_method, :pbGetRegionalDexLength) do |region|
      return PBSpecies.maxValue if region < 0
      ret = 0
      dexList = pbLoadRegionalDexes[region]
      return ret if !dexList || dexList.length == 0
      for i in 0...dexList.length
        ret = dexList[i] if dexList[i] && dexList[i] > ret
      end
      ret
    end

    # --- ItemStorageHelper: Essentials 18 bag/PC storage ---
    if defined?(ItemStorageHelper)
      ItemStorageHelper.module_eval do
        def self.pbQuantity(items, maxsize, item)
          ret = 0
          for i in 0...maxsize
            itemslot = items[i]
            ret += itemslot[1] if itemslot && itemslot[0] == item
          end
          ret
        end

        def self.pbDeleteItem(items, maxsize, item, qty)
          raise "Invalid value for qty: #{qty}" if qty < 0
          return true if qty == 0
          ret = false
          for i in 0...maxsize
            itemslot = items[i]
            next if !itemslot || itemslot[0] != item
            amount = [qty, itemslot[1]].min
            itemslot[1] -= amount
            qty -= amount
            items[i] = nil if itemslot[1] == 0
            next if qty > 0
            ret = true
            break
          end
          items.compact!
          ret
        end

        def self.pbCanStore?(items, maxsize, maxPerSlot, item, qty)
          raise "Invalid value for qty: #{qty}" if qty < 0
          return true if qty == 0
          for i in 0...maxsize
            itemslot = items[i]
            if !itemslot
              qty -= [qty, maxPerSlot].min
              return true if qty == 0
            elsif itemslot[0] == item && itemslot[1] < maxPerSlot
              newamt = itemslot[1]
              newamt = [newamt + qty, maxPerSlot].min
              qty -= (newamt - itemslot[1])
              return true if qty == 0
            end
          end
          false
        end

        def self.pbStoreItem(items, maxsize, maxPerSlot, item, qty, sorting = false)
          raise "Invalid value for qty: #{qty}" if qty < 0
          return true if qty == 0
          itemPocket = pbGetPocket(item)
          for i in 0...maxsize
            itemslot = items[i]
            if !itemslot
              items[i] = [item, [qty, maxPerSlot].min]
              qty -= items[i][1]
              # Essentials 18: BAG_POCKET_AUTO_SORT (not PE17 POCKETAUTOSORT/$ItemData)
              begin
                auto = defined?(BAG_POCKET_AUTO_SORT) ? BAG_POCKET_AUTO_SORT[itemPocket] : false
              rescue StandardError
                auto = false
              end
              items.sort! if sorting && auto
              return true if qty == 0
            elsif itemslot[0] == item && itemslot[1] < maxPerSlot
              newamt = itemslot[1]
              newamt = [newamt + qty, maxPerSlot].min
              qty -= (newamt - itemslot[1])
              itemslot[1] = newamt
              return true if qty == 0
            end
          end
          false
        end

        # Used by PokemonBag#pbStoreAllOrNone — missing in some PE script sets
        def self.pbStoreAllOrNone(items, maxsize, maxPerSlot, item, qty)
          return false unless pbCanStore?(items, maxsize, maxPerSlot, item, qty)
          pbStoreItem(items, maxsize, maxPerSlot, item, qty, false)
        end
      end
    end

    Preload.print "utilities_fix: fSpecies + regional dex + ItemStorageHelper (E18 bag)"
  rescue => e
    Preload.print "utilities_fix ERROR: #{e} @ #{e.backtrace&.first}"
  end
end

Preload.print "utilities_fix: on_boot hook registered"
