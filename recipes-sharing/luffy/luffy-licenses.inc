
# luffy's go.mod has no third-party requirement (standard library only), so
# there is no module license to add. go-mod-update-modules writes
# 'LICENSE += "& "' in that case, which is not a valid license expression:
# keep this file by hand and regenerate it if upstream adds a dependency.

LIC_FILES_CHKSUM += "\
"
