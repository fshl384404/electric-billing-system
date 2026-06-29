package com.electric.billing.module.user;

import com.electric.billing.common.R;
import com.electric.billing.entity.SysUser;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/user")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) { this.userService = userService; }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize) {
        Map<String, Object> result = userService.listAll(page, pageSize);
        @SuppressWarnings("unchecked")
        java.util.List<SysUser> users = (java.util.List<SysUser>) result.get("records");
        users.forEach(u -> u.setPasswordHash(null));
        return R.ok(result);
    }

    @GetMapping("/{id}")
    public R<SysUser> get(@PathVariable Long id) { SysUser u = userService.getById(id); u.setPasswordHash(null); return R.ok(u); }

    @PostMapping
    public R<SysUser> create(@RequestBody SysUser user) { return R.ok(userService.create(user)); }

    @PutMapping
    public R<SysUser> update(@RequestBody SysUser user) { return R.ok(userService.update(user)); }

    @PutMapping("/{id}/disable")
    public R<?> disable(@PathVariable Long id) { userService.disable(id); return R.ok(); }

    @PutMapping("/{id}/reset-password")
    public R<?> resetPassword(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userService.resetPassword(id, body.get("password")); return R.ok();
    }
}
