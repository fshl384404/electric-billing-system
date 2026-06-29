package com.electric.billing.module.user;

import com.electric.billing.common.R;
import com.electric.billing.entity.SysUser;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/user")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /** 用户列表 */
    @GetMapping("/list")
    public R<List<SysUser>> list() {
        List<SysUser> users = userService.listAll();
        users.forEach(u -> u.setPasswordHash(null));
        return R.ok(users);
    }

    /** 用户详情 */
    @GetMapping("/{id}")
    public R<SysUser> get(@PathVariable Long id) {
        SysUser user = userService.getById(id);
        user.setPasswordHash(null);
        return R.ok(user);
    }

    /** 新增用户 */
    @PostMapping
    public R<SysUser> create(@RequestBody SysUser user) {
        return R.ok(userService.create(user));
    }

    /** 更新用户 */
    @PutMapping
    public R<SysUser> update(@RequestBody SysUser user) {
        return R.ok(userService.update(user));
    }

    /** 禁用用户 */
    @PutMapping("/{id}/disable")
    public R<?> disable(@PathVariable Long id) {
        userService.disable(id);
        return R.ok();
    }

    /** 重置密码 */
    @PutMapping("/{id}/reset-password")
    public R<?> resetPassword(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String newPassword = body.get("password");
        if (newPassword == null || newPassword.isEmpty()) {
            return R.fail("密码不能为空");
        }
        userService.resetPassword(id, newPassword);
        return R.ok();
    }
}
