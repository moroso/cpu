.PHONY: all
all:
	sh ./test.sh

tests: $(patsubst %.ma,results/%.txt,$(wildcard *.ma))

bin/%.bin: %.ma
	@mkdir -p bin
	@$(MAS) --fmt bin < $< > $@

results/%.txt: bin/%.bin %.txt
	@echo $<
	@mkdir -p results
	@$(VMCPU_core) $^ | awk 'P==1 { print } /Beginning register dump/ { P=1 }' > $@
	@diff $@ $(patsubst results/%,%,$@) || (rm $@; false)
