# In-engine smoke (optional). Activate with:
#   TGOM_SMOKE=1 ./scripts/play.sh
# Writes logs/smoke_boot_result.txt and exits the process after boot hooks.
# Offline tests (./scripts/test-smoke.sh) are preferred for day-to-day.

STDOUT.sync = true

if ENV["TGOM_SMOKE"].to_s != "1" && ENV["TGOM_SMOKE"].to_s.downcase != "true"
  Preload.print "smoke_boot: idle (set TGOM_SMOKE=1 to run in-engine checks)"
else
  Preload.on_boot do |_ctx|
    results = []
    begin
      def check(name)
        ok = yield
        results << [name, !!ok, ok.is_a?(String) ? ok : nil]
      rescue => e
        results << [name, false, "#{e.class}: #{e.message}"]
      end

      check("pbGetSpeciesFromFSpecies defined") { respond_to?(:pbGetSpeciesFromFSpecies) }
      check("pbGetFSpeciesFromForm defined") { respond_to?(:pbGetFSpeciesFromForm) }
      check("pbGetRegionalDexLength defined") { respond_to?(:pbGetRegionalDexLength) }
      check("ItemStorageHelper defined") { defined?(ItemStorageHelper) }
      check("ItemStorageHelper.pbStoreItem") {
        ItemStorageHelper.respond_to?(:pbStoreItem)
      }
      check("ItemStorageHelper.pbStoreAllOrNone") {
        ItemStorageHelper.respond_to?(:pbStoreAllOrNone)
      }
      check("BAG_POCKET_AUTO_SORT defined") { defined?(BAG_POCKET_AUTO_SORT) }
      check("no POCKETAUTOSORT constant") {
        !(defined?(ItemStorageHelper) && ItemStorageHelper.const_defined?(:POCKETAUTOSORT) rescue false)
      }

      # Live bag store if bag exists (may be nil at pure boot before New Game)
      if defined?($PokemonBag) && $PokemonBag && defined?(PBItems)
        check("live pbStoreItem potion") {
          item = getID(PBItems, :POTION) rescue 0
          next "skip no potion id" if !item || item < 1
          before = ($PokemonBag.pbQuantity(item) rescue 0)
          $PokemonBag.pbStoreItem(item, 1)
          after = $PokemonBag.pbQuantity(item)
          after >= before + 1
        }
      else
        results << ["live bag store", true, "skipped (no \$PokemonBag yet)"]
      end

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

      # Prefer project logs/ via relative path from game cwd parent
      candidates = [
        File.expand_path("../../logs/smoke_boot_result.txt", Dir.pwd),
        File.expand_path("smoke_boot_result.txt", Dir.pwd),
        "/tmp/tg_smoke_boot_result.txt"
      ]
      path = candidates.find { |p| File.directory?(File.dirname(p)) } || candidates.last
      File.write(path, out)
      Preload.print "smoke_boot: wrote #{path}"
      lines.each { |l| Preload.print "smoke_boot: #{l}" }

      # Quit so CI/scripts don't hang on the title screen
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
