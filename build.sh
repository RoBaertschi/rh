
if [[ $1 == "debug" ]]; then
    shift
    odin build src/ -show-timings -collection:src=src -out:rh -microarch:native -debug $@
    exit 0
fi

odin build src/ -show-timings -collection:src=src -out:rh -microarch:native $@
