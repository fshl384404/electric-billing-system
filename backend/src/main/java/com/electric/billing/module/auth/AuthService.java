package com.electric.billing.module.auth;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.SysUser;
import com.electric.billing.security.JwtUtils;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class AuthService {

    private final AuthMapper authMapper;
    private final JwtUtils jwtUtils;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public AuthService(AuthMapper authMapper, JwtUtils jwtUtils) {
        this.authMapper = authMapper;
        this.jwtUtils = jwtUtils;
    }

    /**
     * 登录 — 验证用户名密码，返回 Token + 用户信息
     */
    public Map<String, Object> login(String username, String password) {
        // 查用户
        SysUser user = authMapper.selectOne(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getUsername, username)
        );
        if (user == null) {
            throw new BusinessException("用户名或密码错误");
        }
        if ("DISABLED".equals(user.getStatus())) {
            throw new BusinessException("账户已被禁用，请联系管理员");
        }

        // 验证密码 (兼容明文密码自动升级为 BCrypt)
        String storedHash = user.getPasswordHash();
        boolean matched = false;

        // 1. 尝试 BCrypt 匹配
        if (storedHash.startsWith("$2a$") || storedHash.startsWith("$2b$") || storedHash.startsWith("$2y$")) {
            matched = passwordEncoder.matches(password, storedHash);
        }
        // 2. 明文密码兼容 — 匹配后自动升级为 BCrypt
        else if (password.equals(storedHash)) {
            matched = true;
            // 自动升级为 BCrypt 哈希
            String newHash = passwordEncoder.encode(password);
            SysUser updateUser = new SysUser();
            updateUser.setUserId(user.getUserId());
            updateUser.setPasswordHash(newHash);
            authMapper.updateById(updateUser);
        }

        if (!matched) {
            throw new BusinessException("用户名或密码错误");
        }

        // 生成 Token
        String token = jwtUtils.generateToken(user.getUserId(), user.getUsername(), user.getRole());

        // 组装返回
        Map<String, Object> result = new HashMap<>();
        result.put("token", token);
        result.put("userId", user.getUserId());
        result.put("username", user.getUsername());
        result.put("realName", user.getRealName());
        result.put("role", user.getRole());
        return result;
    }

    /**
     * 忘记密码 — 第一步: 验证身份 (用户名 + 手机号或邮箱)
     * @return 匹配的用户 (含 userId / username / realName)，供前端确认后展示重置表单
     */
    public SysUser verifyIdentity(String username, String phoneOrEmail) {
        SysUser user = authMapper.selectOne(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getUsername, username)
        );
        if (user == null) {
            throw new BusinessException("用户不存在");
        }
        if ("DISABLED".equals(user.getStatus())) {
            throw new BusinessException("账户已被禁用，请联系管理员");
        }
        // 校验手机号或邮箱匹配
        String phone = user.getPhone();
        String email = user.getEmail();
        if ((phone == null || !phone.equals(phoneOrEmail))
                && (email == null || !email.equals(phoneOrEmail))) {
            throw new BusinessException("手机号或邮箱不匹配");
        }
        // 不返回敏感信息
        user.setPasswordHash(null);
        return user;
    }

    /**
     * 忘记密码 — 第二步: 重置密码 (需先通过身份验证)
     */
    public void resetPasswordSelf(String username, String phoneOrEmail, String newPassword) {
        if (newPassword == null || newPassword.isBlank()) {
            throw new BusinessException("新密码不能为空");
        }
        if (newPassword.length() < 4) {
            throw new BusinessException("密码长度不能少于4位");
        }
        // 再次校验身份
        SysUser user = verifyIdentity(username, phoneOrEmail);
        // 更新密码
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        authMapper.updateById(user);
    }

    /**
     * 居民自助注册
     */
    public SysUser register(SysUser user) {
        // 校验用户名唯一
        Long count = authMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getUsername, user.getUsername())
        );
        if (count > 0) {
            throw new BusinessException("用户名已存在");
        }

        user.setUserId(authMapper.nextId());
        user.setPasswordHash(passwordEncoder.encode(user.getPasswordHash()));
        user.setRole("RESIDENT");
        user.setStatus("ACTIVE");
        authMapper.insert(user);
        return user;
    }
}
