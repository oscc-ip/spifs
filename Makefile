
comp-smoke:
	make -C dv/smoke comp

run-smoke:
	make -C dv/smoke run

wave-smoke:
	make -C dv/smoke wave

clean :
	rm -rf build

.PHONY : comp-smoke run-smoke wave-smoke clean