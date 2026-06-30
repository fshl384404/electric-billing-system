package com.electric.billing.module.auth;

import com.electric.billing.common.R;
import com.electric.billing.entity.SysUser;
import com.electric.billing.security.AuthContext;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /** 登录 */
    @PostMapping("/login")
    public R<Map<String, Object>> login(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String password = body.get("password");
        if (username == null || password == null) {
            return R.fail("用户名和密码不能为空");
        }
        Map<String, Object> result = authService.login(username, password);
        return R.ok(result);
    }

    /** 居民注册 */
    @PostMapping("/register")
    public R<SysUser> register(@RequestBody SysUser user) {
        if (user.getUsername() == null || user.getPasswordHash() == null) {
            return R.fail("用户名和密码不能为空");
        }
        SysUser saved = authService.register(user);
        // 不返回密码哈希
        saved.setPasswordHash(null);
        return R.ok(saved);
    }

    /** 忘记密码 — 第一步：验证身份（用户名 + 手机号/邮箱匹配） */
    @PostMapping("/forgot-password")
    public R<SysUser> verifyIdentity(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String phoneOrEmail = body.get("phoneOrEmail");
        if (username == null || phoneOrEmail == null) {
            return R.fail("用户名和手机号/邮箱不能为空");
        }
        SysUser user = authService.verifyIdentity(username.trim(), phoneOrEmail.trim());
        return R.ok(user);
    }

    /** 忘记密码 — 第二步：重置密码（公开接口，无需登录） */
    @PostMapping("/reset-password-public")
    public R<?> resetPasswordSelf(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String phoneOrEmail = body.get("phoneOrEmail");
        String newPassword = body.get("newPassword");
        if (username == null || phoneOrEmail == null || newPassword == null) {
            return R.fail("参数不能为空");
        }
        authService.resetPasswordSelf(username.trim(), phoneOrEmail.trim(), newPassword);
        return R.ok();
    }

    /** 获取当前登录用户信息 */
    @GetMapping("/me")
    public R<Map<String, String>> me() {
        return R.ok(Map.of(
                "userId", String.valueOf(AuthContext.getCurrentUserId()),
                "username", AuthContext.getCurrentUsername(),
                "role", AuthContext.getCurrentRole()
        ));
    }
}
