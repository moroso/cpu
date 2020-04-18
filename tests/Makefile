.PHONY: all
#all:
#	sh ./test.sh

tests: $(patsubst %.ma,gen/%.txt,$(wildcard *.ma)) $(patsubst %.ma,gen/%.bin,$(wildcard *.ma))
	(for f in $(patsubst %.bin,%,$(wildcard gen/*.bin)); do echo $$f; $(core_test) $$f.bin $$f.txt || exit 1; done)

gen/%.bin: %.ma
	@mkdir -p bin
	$(MAS) --fmt bin < $< > $@

gen/%.txt: gen/%.bin
	$(cpu_sim) < $< > $@
