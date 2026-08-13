# In-engine smoke (optional). Activate with:
#   TGOM_SMOKE=1 ./scripts/play.sh
# Filename zz_* so this hook runs after utilities_fix / safety_net.
# Writes logs/smoke_boot_result.txt and exits the process after boot hooks.
# Offline tests (./scripts/test-smoke.sh) are preferred for day-to-day.

STDOUT.sync = true

if ENV["TGOM_SMOKE"].to_s != "1" && ENV["TGOM_SMOKE"].to_s.downcase != "true"
  Preload.print "smoke_boot: idle (set TGOM_SMOKE=1 to run in-engine checks)"
else
  Preload.on_boot do |_ctx|
    results = []
    begin
      check = lambda do |name, &blk|
        begin
          ok = blk.call
          # Only literal true is a pass. Skips, strings, and nil are failures.
          results << [name, ok == true, ok.is_a?(String) ? ok : nil]
        rescue => e
          results << [name, false, "#{e.class}: #{e.message}"]
        end
      end

      check.call("pbGetSpeciesFromFSpecies defined") { respond_to?(:pbGetSpeciesFromFSpecies, true) }
      check.call("pbGetFSpeciesFromForm defined") { respond_to?(:pbGetFSpeciesFromForm, true) }
      check.call("pbGetRegionalDexLength defined") { respond_to?(:pbGetRegionalDexLength, true) }
      check.call("ItemStorageHelper defined") { !defined?(ItemStorageHelper).nil? }
      check.call("ItemStorageHelper.pbStoreItem") {
        ItemStorageHelper.respond_to?(:pbStoreItem)
      }
      check.call("ItemStorageHelper.pbStoreAllOrNone") {
        ItemStorageHelper.respond_to?(:pbStoreAllOrNone)
      }
      check.call("BAG_POCKET_AUTO_SORT defined") { !defined?(BAG_POCKET_AUTO_SORT).nil? }
      check.call("no POCKETAUTOSORT constant") {
        !(defined?(ItemStorageHelper) && ItemStorageHelper.const_defined?(:POCKETAUTOSORT) rescue false)
      }
      check.call("tg_map_rxdata_exists? defined") { respond_to?(:tg_map_rxdata_exists?, true) }
      check.call("missing Map052 refused") {
        respond_to?(:tg_map_rxdata_exists?, true) && !tg_map_rxdata_exists?(52)
      }
      check.call("home Map043 present") {
        respond_to?(:tg_map_rxdata_exists?, true) && tg_map_rxdata_exists?(43)
      }

      # Always exercise a real bag. $PokemonBag is nil until New Game; that
      # is not a pass — construct PokemonBag and store a Potion on it.
      check.call("live pbStoreItem potion") {
        raise "PokemonBag class missing" unless defined?(PokemonBag)
        raise "PBItems missing" unless defined?(PBItems)
        item = (getID(PBItems, :POTION) rescue 0)
        raise "POTION id missing (#{item.inspect})" if !item || item.to_i < 1
        bag = PokemonBag.new
        before = bag.pbQuantity(item)
        stored = bag.pbStoreItem(item, 1)
        after = bag.pbQuantity(item)
        raise "pbStoreItem returned #{stored.inspect}" unless stored
        raise "qty #{before} -> #{after}, expected #{before + 1}" unless after == before + 1
        true
      }

      lines = results.map { |n, ok, d|
        "#{ok ? "PASS" : "FAIL"}  #{n}#{d ? " — #{d}" : ""}"
      }
      failed = results.any? { |_, ok, _| !ok }
      out = [
        "TGOM in-engine smoke #{Time.now}",
        "failed=#{failed}",
        *lines,
        ""
      ].join("\n")

      candidates = [
        File.expand_path("../../logs/smoke_boot_result.txt", Dir.pwd),
        File.expand_path("smoke_boot_result.txt", Dir.pwd),
        "/tmp/tg_smoke_boot_result.txt"
      ]
      path = candidates.find { |p| File.directory?(File.dirname(p)) } || candidates.last
      File.write(path, out)
      Preload.print "smoke_boot: wrote #{path}"
      lines.each { |l| Preload.print "smoke_boot: #{l}" }

      begin
        exit!(failed ? 1 : 0)
      rescue SystemExit
        raise
      rescue => e
        Preload.print "smoke_boot: exit failed: #{e}"
      end
    rescue => e
      Preload.print "smoke_boot ERROR: #{e} @ #{e.backtrace&.first}"
    end
  end
  Preload.print "smoke_boot: TGOM_SMOKE=1 — will run checks on_boot"
end
