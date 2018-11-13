#!/bin/sh 

# shellcheck disable=SC1091
cd ../../../../utils
    .        ./sys_info.sh
    .        ./sh-test-lib
cd -
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
SKIP_INSTALL="false"

RELEASE="pm-qa-v0.5.2"
TESTS="cpufreq cpuidle cpuhotplug thermal cputopology"

usage() {
    echo "usage: $0 [-r <release>] [-t <tests>] [-s <true|false>] 1>&2"
    exit 1
}

while getopts ":r:t:s:" opt; do
    case "${opt}" in
        r) RELEASE="${OPTARG}" ;;
        t) TESTS="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
install_deps "git build-essential linux-libc-dev" "${SKIP_INSTALL}"
print_info $? install-pkg
create_out_dir "${OUTPUT}"

case "$distro" in 
	debian)
		apt-get install -y git
		;;
esac
rm -rf pm-qa
git clone https://git.linaro.org/power/pm-qa.git
print_info $? git-pm-qa
cd pm-qa
git checkout -b "${RELEASE}" "${RELEASE}"
make -C utils

for test in ${TESTS}; do
    logfile="${OUTPUT}/${test}.log"
    make -C "${test}" check 2>&1 | tee  "${logfile}"
    print_info $? ${test}
    grep -E "^[a-z0-9_]+: (pass|fail|skip)" "${logfile}" \
        | sed 's/://g' \
        | tee -a "${RESULT_FILE}"
done
