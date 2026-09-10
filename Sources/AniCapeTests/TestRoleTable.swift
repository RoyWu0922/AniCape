import Foundation
import RoleKit

func testAssignableRolesCoverThirteenSlots() {
    Harness.eq(RoleMap.assignableRoles.count, 13, "13 个可指派槽位")
    Harness.eq(Set(RoleMap.assignableRoles.map { $0.identifier }).count, 13, "identifier 唯一")
    Harness.eq(Set(RoleMap.assignableRoles.map { $0.name }).count, 13, "名称唯一")
    Harness.eq(RoleMap.assignableRoles.first?.identifier, "com.apple.coregraphics.Arrow", "顺序稳定：首项 Arrow")
}

func testAssignableRolesMatchTableViaChineseNames() {
    for role in RoleMap.assignableRoles {
        Harness.eq(RoleMap.identifier(forFileName: role.name), role.identifier, "\(role.name) → \(role.identifier)")
    }
}

func testDisplayNameRoundTrip() {
    for role in RoleMap.assignableRoles {
        Harness.eq(RoleMap.displayName(forIdentifier: role.identifier), role.name, "往返 \(role.identifier)")
    }
    Harness.isNil(RoleMap.displayName(forIdentifier: "com.apple.cursor.999"), "未知 identifier → nil")
}

func testIsSkippedMatchesSkippedRoleNames() {
    Harness.check(RoleMap.isSkipped("手写"), "手写 is skipped")
    Harness.check(RoleMap.isSkipped("Handwriting"), "Handwriting is skipped")
    Harness.check(!RoleMap.isSkipped("Normal"), "Normal is not skipped")
    Harness.check(!RoleMap.isSkipped("whatever"), "unknown is not skipped")
}
