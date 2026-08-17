#!/usr/bin/env bash
# Build one or more Vortex profiles and archive each result under results/.
#
#   scripts/build.sh c1w1t1                    # one profile
#   scripts/build.sh c1w1t1 c1w2t4 c2w4t8      # several, in sequence
#
# A profile name is c<CORES>w<WARPS>t<THREADS>; those are the knobs
# prepare_project.sh exposes (VX_DE10PRO_NUM_CORES / _NUM_WARPS / _NUM_THREADS).
# Everything else in the generated Vortex configuration is fixed.

set -uo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_NAME=vortex_g3x16_ddr4x4
PART=1SG280HU1F50E1VG
VORTEX_HOME=${VORTEX_HOME:-$PROJECT_DIR/../../vortexCrypto}
QUARTUS_ROOT=${QUARTUS_ROOT:-/data/Quartus/tools/19.2/quartus}
PREPARE=$VORTEX_HOME/hw/syn/altera/de10pro/prepare_project.sh
RESULTS_DIR=$PROJECT_DIR/results

usage() {
    echo "usage: $0 c<CORES>w<WARPS>t<THREADS> [...]" >&2
    echo "example: $0 c1w1t1 c1w2t4" >&2
}

if [[ $# -eq 0 ]]; then
    usage
    exit 2
fi

for profile in "$@"; do
    if [[ ! $profile =~ ^c([1-9][0-9]*)w([1-9][0-9]*)t([1-9][0-9]*)$ ]]; then
        echo "error: bad profile name '$profile'" >&2
        usage
        exit 2
    fi
done

for tool in "$PREPARE" "$QUARTUS_ROOT/bin/quartus_sh"; do
    if [[ ! -x $tool ]]; then
        echo "error: missing or not executable: $tool" >&2
        exit 1
    fi
done

runtime_configs() {
    local cores=$1 warps=$2 threads=$3
    echo "-DVX_CFG_NUM_CLUSTERS=1 -DVX_CFG_NUM_CORES=$cores" \
         "-DVX_CFG_NUM_WARPS=$warps -DVX_CFG_NUM_THREADS=$threads" \
         "-DVX_CFG_EXT_F_DISABLE=1 -DVX_CFG_EXT_D_DISABLE=1" \
         "-DVX_CFG_ICACHE_LATENCY=3 -DVX_CFG_DCACHE_LATENCY=3" \
         "-DVX_CFG_PLATFORM_MEMORY_NUM_BANKS=1" \
         "-DVX_CFG_PLATFORM_MEMORY_INTERLEAVE=0" \
         "-DVX_CFG_PLATFORM_CLOCK_RATE=250"
}

# Quartus compiles the board manager from the copies Platform Designer made,
# not from rtl/board_mgmt. prepare_project.sh refreshes those copies, but a bare
# quartus_sh --flow compile does not, so an edit made after the last prepare run
# silently produces a bitstream without it. Prove the copies match before
# spending half an hour on the compile.
verify_board_mgmt_ip() {
    local synth=ip/pcie_ddr4_system/pcie_ddr4_system_board_manager_2/de10pro_board_manager_10/synth
    local file
    for file in board_mgmt_core.v board_mgmt_i2c_master.v \
                de10pro_board_manager.v de10pro_dynamic_clock.v; do
        if ! cmp -s "rtl/board_mgmt/$file" "$synth/$file"; then
            echo "error: $synth/$file does not match the source" >&2
            return 1
        fi
    done
}

write_program_script() {
    local dest=$1 profile=$2

    # Quoted heredoc: everything stays literal, the two values are filled in
    # afterwards so nothing expands while the script is being written.
    cat > "$dest/program.sh" <<'EOF'
#!/usr/bin/env bash
# Program the FPGA with this profile's bitstream.
#
# This drops the PCIe link: the host loses the device until it is rescanned or
# rebooted, and the driver has to be reloaded afterwards. Build the runtime with
# the DE10PRO_CONFIGS line in README.md, or it will not match this bitstream.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
QUARTUS_ROOT=${QUARTUS_ROOT:-@QUARTUS_ROOT@}
exec "$QUARTUS_ROOT/bin/quartus_pgm" -m jtag -c "${CABLE:-1}" -o "p;@SOF@"
EOF
    sed -i -e "s|@QUARTUS_ROOT@|$QUARTUS_ROOT|" \
           -e "s|@SOF@|${PROJECT_NAME}_$profile.sof|" "$dest/program.sh"
    chmod +x "$dest/program.sh"
}

write_readme() {
    local dest=$1 profile=$2 cores=$3 warps=$4 threads=$5 elapsed=$6

    {
        echo "# $profile"
        echo
        echo "| | |"
        echo "| --- | --- |"
        echo "| Cores | $cores |"
        echo "| Warps | $warps |"
        echo "| Threads per warp | $threads |"
        echo "| Built | $(date '+%Y-%m-%d %H:%M:%S') |"
        echo "| Wall clock | $elapsed |"
        echo "| Device | $PART |"
        echo "| Quartus | $("$QUARTUS_ROOT/bin/quartus_sh" --version | sed -n 2p) |"
        echo "| FPGA project | $(git -C "$PROJECT_DIR" describe --always --dirty 2>/dev/null) |"
        echo "| vortexCrypto | $(cat "$PROJECT_DIR/generated/vortexcrypto/VORTEX_SOURCE_REVISION" 2>/dev/null) |"
        echo
        echo "The rest of the profile is fixed by prepare_project.sh: RV32, one"
        echo "cluster, F and D disabled, three-cycle I-cache and D-cache,"
        echo "one platform-memory bank without interleaving, 250 MHz initial Vortex"
        echo "clock with 100/125/200/250 MHz profiles in the bitstream."
        echo
        echo '## Host runtime'
        echo
        echo 'The runtime must be built with the same profile as the bitstream:'
        echo
        echo '```sh'
        echo "DE10PRO_CONFIGS='$(runtime_configs "$cores" "$warps" "$threads")'"
        echo 'make -C sw/runtime de10pro CONFIGS="$DE10PRO_CONFIGS"'
        echo '```'
        echo
        echo '## Programming'
        echo
        echo 'From this directory:'
        echo
        echo '```sh'
        echo './program.sh          # override the JTAG cable with CABLE=2'
        echo '```'
        echo
        echo '## Timing'
        echo
        echo 'The four worst clock domains; the full list is in'
        echo "\`$PROJECT_NAME.sta.summary\`."
        echo
        echo '```'
        sed -n '5,20p' "$dest/$PROJECT_NAME.sta.summary" 2>/dev/null
        echo '```'
        echo
        # grep -c exits 1 on a zero count, so take the count and only fall back
        # to a placeholder when the file itself is missing.
        local failing
        failing=$(grep -c '^Slack : -' "$dest/$PROJECT_NAME.sta.summary" 2>/dev/null)
        echo "Clock domains with negative slack: **${failing:-unknown}**"
        echo
        echo 'Worst-case DDR4 EMIF margins, from the per-interface summaries:'
        echo
        echo '| Interface | Worst setup margin (ns) | Path |'
        echo '| --- | ---: | --- |'
        local csv
        for csv in "$dest"/emif_s10_ddr4*_summary.csv; do
            [[ -e $csv ]] || continue
            awk -F, -v name="$(basename "$csv" | cut -d_ -f1-3)" '
                NR>2 { gsub(/"/,"",$1); if (NR==3 || $2+0 < min) { min=$2+0; p=$1 } }
                END { printf "| %s | %s | %s |\n", name, min, p }' "$csv"
        done
        echo
        echo '## Resources'
        echo
        echo '```'
        cat "$dest/$PROJECT_NAME.fit.summary" 2>/dev/null
        echo '```'
    } > "$dest/README.md"
}

build_one() {
    local profile=$1
    [[ $profile =~ ^c([1-9][0-9]*)w([1-9][0-9]*)t([1-9][0-9]*)$ ]]
    local cores=${BASH_REMATCH[1]} warps=${BASH_REMATCH[2]} threads=${BASH_REMATCH[3]}
    local dest=$RESULTS_DIR/$profile
    local started elapsed

    echo "=== $profile: $cores core(s), $warps warp(s), $threads thread(s) ==="
    started=$SECONDS

    VX_DE10PRO_NUM_CORES=$cores \
    VX_DE10PRO_NUM_WARPS=$warps \
    VX_DE10PRO_NUM_THREADS=$threads \
    VX_DE10PRO_PROJECT_DIR=$PROJECT_DIR \
    QUARTUS_ROOT=$QUARTUS_ROOT \
        "$PREPARE" || return 1

    verify_board_mgmt_ip || return 1

    "$QUARTUS_ROOT/bin/quartus_sh" --flow compile "$PROJECT_NAME" || return 1

    # The EMIF timing summaries are written to the project directory by a
    # relative path hard-coded in generated IP, so they can only be moved after
    # the fact.
    mv -f "$PROJECT_DIR"/emif_s10_ddr4*_summary.csv "$PROJECT_DIR/output_files/" 2>/dev/null

    elapsed=$(printf '%02d:%02d:%02d' $(((SECONDS-started)/3600)) \
                                      $(((SECONDS-started)%3600/60)) \
                                      $(((SECONDS-started)%60)))

    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$PROJECT_DIR/output_files/." "$dest/"
    # Quartus always names its output after the revision, so several profiles
    # would archive an identically named SOF. Stamp the profile into the
    # archived copy and point the programming script at it.
    mv "$dest/$PROJECT_NAME.sof" "$dest/${PROJECT_NAME}_$profile.sof"
    write_program_script "$dest" "$profile"
    write_readme "$dest" "$profile" "$cores" "$warps" "$threads" "$elapsed"
    echo "=== $profile: archived to $dest ($elapsed, $(du -sh "$dest" | cut -f1)) ==="
}

cd "$PROJECT_DIR"
failed=()
for profile in "$@"; do
    if ! build_one "$profile"; then
        echo "=== $profile: FAILED ===" >&2
        failed+=("$profile")
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    echo "failed profiles: ${failed[*]}" >&2
    exit 1
fi
echo "all profiles built: $*"
