import RoleKit

func testEnglishNames() {
    Harness.eq(RoleMap.identifier(forFileName: "Normal"), "com.apple.coregraphics.Arrow", "Normal")
    Harness.eq(RoleMap.identifier(forFileName: "Busy"), "com.apple.coregraphics.Wait", "Busy")
    Harness.eq(RoleMap.identifier(forFileName: "Diagonal2"), "com.apple.cursor.30", "Diagonal2")
    Harness.eq(RoleMap.identifier(forFileName: "Move"), "com.apple.coregraphics.Move", "Move")
}

func testChineseNames() {
    Harness.eq(RoleMap.identifier(forFileName: "正常选择"), "com.apple.coregraphics.Arrow", "正常选择")
    Harness.eq(RoleMap.identifier(forFileName: "忙"), "com.apple.coregraphics.Wait", "忙")
    Harness.eq(RoleMap.identifier(forFileName: "文本选择"), "com.apple.coregraphics.IBeam", "文本选择")
}

func testSkippedRolesReturnNil() {
    Harness.isNil(RoleMap.identifier(forFileName: "Handwriting"), "Handwriting")
    Harness.isNil(RoleMap.identifier(forFileName: "候选"), "候选")
    Harness.isNil(RoleMap.identifier(forFileName: "Pin"), "Pin")
}

func testUnknownReturnsNil() {
    Harness.isNil(RoleMap.identifier(forFileName: "whatever"), "unknown")
}

func testExplicitIdentifierPassesThrough() {
    Harness.eq(RoleMap.identifier(forRoleName: "com.apple.cursor.30"), "com.apple.cursor.30", "explicit id passthrough")
}
