# Source this file into your shell environment to define important variables:
#   source $HOME/src/fare/glow/env.sh

if [ -n "${BASH_VERSION-}" ] ; then
    this=${BASH_SOURCE[0]}
elif [ -n "${ZSH_VERSION-}" ] ; then
    this=$0
elif [ -n "$this" ] ; then
    : Assuming the caller set the path to $this
else
    echo "Unknown shell and \$this not defined" ; unset this ; set -u ; return 1
fi

export GLOW_SRC="$(dirname $this)"
export GLOW_HOME
: ${GLOW_HOME:=/home/glow}
bindir=${GLOW_SRC}/.build_outputs
GERBIL_PACKAGE=gerbil-unstable

. "${HOME}/.gerbil/pkg/github.com/fare/gerbil-utils/gerbil-nix-env.sh"

#srcdir="$(realpath "$GLOW_SRC/..")"
### export GERBIL_LOADPATH=$GLOW_SRC:$srcdir/gerbil-utils
# Don't change the GERBIL_LOADPATH, instead configure your gxpkg with:
#   gxpkg link github.com/fare/gerbil-utils $srcdir/gerbil-utils

# Manage the git submodule
subm_reset () {(cd $GLOW_SRC ; git submodule update --init )} # Reset to version pinned in git
subm_update () {(cd $GLOW_SRC ; git submodule update --remote )} # Update version from upstream
subm_remove () {(cd $GLOW_SRC ; git submodule deinit . )} # Remove contents altogether

#. $srcdir/gerbil-utils/gerbil-nix-env.sh

build_glo () {(
  cd "$GLOW_SRC" &&
  ./build.ss "$@"
)}

glo_dirs () { : ;}
glo_proxy () { glo_dirs ; exec "$bindir/glow" run-proxy-server > ~/data/proxy.log 2>&1 & }
_glo () { "$bindir/glow" "$@" ;}
glo () { build_glo build-only && _glo "$@" ;}
bglo () { build_glo && glo_unit_tests ;}

glo_unit_tests () {(
  cd "$srcdir" &&
  #gxi clan/utils/tests/run-unit-tests.ss &&
  gxi tests/run-unit-tests.ss
)}
glo_integration_tests () { (cd "$srcdir" && gxi tests/run-integration-tests.ss) }
glo_tests () { glo_unit_tests ; glo_integration_tests ; }
tf () { glo_tests ; }
wcssd () {( cd ${GLOW_SRC} ; cat $(find $@ -type f -name '*.ss') | wc -l )}
wcss () {
    a=$(wcssd) u=$(wcssd clan time-series) t=$(wcssd tests)
    echo "utils: $u"
    echo "tests: $t"
    echo "glow: $(($a-$u-$t))"
    echo "all: $a"
}
glo_gxi () { gxi ${GLOW_SRC}/all-glow.ss $GERBIL_HOME/lib/gxi-interactive - ;}