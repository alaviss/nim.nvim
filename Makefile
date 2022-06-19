.PHONY: check

check:
	nvim --headless -u tests/minimal_init.lua --noplugin -c 'RunTests'
