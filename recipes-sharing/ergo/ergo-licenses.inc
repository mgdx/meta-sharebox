# Licenses of the Go modules vendored by ergo (vendor/ directory) that are
# linked into the binary built with the tags used by ergo_*.bb.
#
# Generated with "go list -deps -tags sqlite ." and oe.license_finder, then
# Unknown licenses checked manually and completed.

LICENSE += "& Apache-2.0 & BSD-2-Clause & BSD-3-Clause & ISC & MIT"

LIC_FILES_CHKSUM += "\
    file://src/${GO_IMPORT}/vendor/code.cloudfoundry.org/bytefmt/LICENSE;md5=2b42edef8fa55315f34f2370b4715ca9;spdx=Apache-2.0 \
    file://src/${GO_IMPORT}/vendor/github.com/GehirnInc/crypt/LICENSE;md5=d562a9d2fdabb4826751081bd90658da;spdx=BSD-2-Clause \
    file://src/${GO_IMPORT}/vendor/github.com/docopt/docopt-go/LICENSE;md5=d23bb93e1219e0cfe34c0417b3d2a96a;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/dustin/go-humanize/LICENSE;md5=8c6127b79304a5e0a5756d03c7a58766;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/emersion/go-msgauth/LICENSE;md5=ac5a2269482607202afa3fc8d061665e;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/ergochat/go-ident/LICENSE;md5=076b4e0f6a3e632b430c3b7bce3380d9;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/ergochat/irc-go/LICENSE;md5=09e0b251831ad60500f5e9d306462cc1;spdx=ISC \
    file://src/${GO_IMPORT}/vendor/github.com/ergochat/webpush-go/v2/LICENSE;md5=e207d8974864ac94581d8fd4555e1246;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/gofrs/flock/LICENSE;md5=4e7459b34ebe4461b4dbc9eb5856431f;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/github.com/golang-jwt/jwt/v5/LICENSE;md5=a21b708d8b320c68979c44ac9dba9b0d;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/google/uuid/LICENSE;md5=88073b6dd8ec00fe09da59e0b6dfded1;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/github.com/gorilla/websocket/LICENSE;md5=c007b54a1743d596f46b2748d9f8c044;spdx=BSD-2-Clause \
    file://src/${GO_IMPORT}/vendor/github.com/okzk/sdnotify/LICENSE;md5=b733e8baa35b1b923b5fa7b3bc8d1ae2;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/remyoudompheng/bigfft/LICENSE;md5=591778525c869cdde0ab5a1bf283cd81;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/btree/LICENSE;md5=9e95e04b54918a19c07e05ef28345454;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/buntdb/LICENSE;md5=f1ccda76a282fada49760e27335f1c28;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/gjson/LICENSE;md5=f1ccda76a282fada49760e27335f1c28;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/grect/LICENSE.md;md5=f1ccda76a282fada49760e27335f1c28;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/match/LICENSE;md5=f1ccda76a282fada49760e27335f1c28;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/pretty/LICENSE;md5=898bc94f87439245e8cf1c5797098e90;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/rtred/LICENSE;md5=57cafd6066144e7a7fc446fba4f6ce90;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/github.com/tidwall/tinyqueue/LICENSE;md5=0731884aabbdb37771724007da4cc131;spdx=ISC \
    file://src/${GO_IMPORT}/vendor/github.com/xdg-go/pbkdf2/LICENSE;md5=34400b68072d710fecd0a2940a0d1658;spdx=Apache-2.0 \
    file://src/${GO_IMPORT}/vendor/github.com/xdg-go/scram/LICENSE;md5=34400b68072d710fecd0a2940a0d1658;spdx=Apache-2.0 \
    file://src/${GO_IMPORT}/vendor/golang.org/x/crypto/LICENSE;md5=7998cb338f82d15c0eff93b7004d272a;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/golang.org/x/exp/LICENSE;md5=7998cb338f82d15c0eff93b7004d272a;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/golang.org/x/sys/LICENSE;md5=7998cb338f82d15c0eff93b7004d272a;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/golang.org/x/term/LICENSE;md5=7998cb338f82d15c0eff93b7004d272a;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/gopkg.in/yaml.v2/LICENSE;md5=e3fc50a88d0a364313df4b21ef20c29e;spdx=Apache-2.0 \
    file://src/${GO_IMPORT}/vendor/modernc.org/libc/COPYRIGHT-MUSL;md5=b03f1cc25363d094011f8f4fd8bcfb68;spdx=MIT \
    file://src/${GO_IMPORT}/vendor/modernc.org/libc/LICENSE;md5=e8aca590db3d9304f507bcd5fe4de5a0;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/modernc.org/libc/LICENSE-GO;md5=5d4950ecb7b26d2c5e4e7b4e0dd74707;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/modernc.org/mathutil/LICENSE;md5=2604a98416f52ae5aaceb3630431020c;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/modernc.org/memory/LICENSE;md5=c4dac399c2cb8794cc72e762c9f07263;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/modernc.org/memory/LICENSE-GO;md5=5d4950ecb7b26d2c5e4e7b4e0dd74707;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/modernc.org/memory/LICENSE-MMAP-GO;md5=8c3f6072b212265c9f4b89a0c247b169;spdx=BSD-3-Clause \
    file://src/${GO_IMPORT}/vendor/modernc.org/sqlite/LICENSE;md5=3cd92e5f84bae63802a058f3ff54fbe7;spdx=BSD-3-Clause \
"
