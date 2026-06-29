package com.electric.billing.module.user;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.SysUser;
import com.electric.billing.security.AuthContext;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

@Service
public class UserService {

    private final UserMapper userMapper;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public UserService(UserMapper userMapper) {
        this.userMapper = userMapper;
    }

    /** 全部用户列表 (ADMIN/COLLECTOR) */
    public List<SysUser> listAll() {
        checkNotResident();
        return userMapper.selectList(null);
    }

    /** 用户详情 */
    public SysUser getById(Long id) {
        SysUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BusinessException("用户不存在");
        }
        return user;
    }

    /** 新增用户 */
    public SysUser create(SysUser user) {
        checkAdminOnly();
        // 校验用户名唯一
        Long count = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>().eq(SysUser::getUsername, user.getUsername())
        );
        if (count > 0) {
            throw new BusinessException("用户名已存在");
        }

        user.setUserId(userMapper.nextId());
        user.setPasswordHash(passwordEncoder.encode(user.getPasswordHash()));
        if (user.getStatus() == null) user.setStatus("ACTIVE");
        user.setCreatedAt(new Date());
        userMapper.insert(user);
        user.setPasswordHash(null); // 不返回密码
        return user;
    }

    /** 更新用户基本信息 (不含密码) */
    public SysUser update(SysUser user) {
        checkAdminOnly();
        SysUser existing = userMapper.selectById(user.getUserId());
        if (existing == null) {
            throw new BusinessException("用户不存在");
        }
        // 保持不变的字段
        user.setPasswordHash(existing.getPasswordHash());
        user.setUsername(existing.getUsername()); // 用户名不可改
        user.setCreatedAt(existing.getCreatedAt());
        user.setUpdatedAt(new Date());
        userMapper.updateById(user);
        user.setPasswordHash(null);
        return user;
    }

    /** 禁用用户 */
    public void disable(Long id) {
        checkAdminOnly();
        SysUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BusinessException("用户不存在");
        }
        if ("ADMIN".equals(user.getRole())) {
            throw new BusinessException("不能禁用管理员账户");
        }
        user.setStatus("DISABLED");
        user.setUpdatedAt(new Date());
        userMapper.updateById(user);
    }

    /** 重置密码 */
    public void resetPassword(Long id, String newPassword) {
        checkAdminOnly();
        SysUser user = userMapper.selectById(id);
        if (user == null) {
            throw new BusinessException("用户不存在");
        }
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setUpdatedAt(new Date());
        userMapper.updateById(user);
    }

    // ---- 权限检查 ----

    private void checkNotResident() {
        if (AuthContext.isResident()) {
            throw new BusinessException(403, "无权限访问");
        }
    }

    private void checkAdminOnly() {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
    }
}
