.PHONY: tests
tests: $(patsubst %.ma,gen/%.vcd,$(wildcard *.ma))

.PHONY: gen/%.vcd
gen/%.vcd: gen/%.txt gen/%.bin
	$(core_test) $(patsubst %.vcd,%.bin,$@) $(patsubst %.vcd,%.txt,$@)
# TODO: core_test really should take a commandline option to tell it where
# to put the vcd.
	mv trace.vcd $@

gen/%.bin: %.ma
	@mkdir -p bin
	$(MAS) --fmt bin < $< > $@

gen/%.txt: gen/%.bin
	$(cpu_sim) < $< > $@
