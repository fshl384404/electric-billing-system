package com.electric.billing.module.user;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.SysUser;
import com.electric.billing.security.AuthContext;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.Map;

@Service
public class UserService {

    private final UserMapper userMapper;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public UserService(UserMapper userMapper) {
        this.userMapper = userMapper;
    }

    /** 全部用户列表 (ADMIN/COLLECTOR) */
    public Map<String, Object> listAll(int page, int pageSize) {
        checkNotResident();
        return PageUtils.paginate(userMapper,
            new LambdaQueryWrapper<SysUser>().orderByAsc(SysUser::getUserId), page, pageSize);
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
        if (user.getUsername() == null || user.getUsername().isBlank()) {
            throw new BusinessException("用户名不能为空");
        }
        if (user.getPasswordHash() == null || user.getPasswordHash().isBlank()) {
            throw new BusinessException("密码不能为空");
        }
        if (user.getPhone() != null && !user.getPhone().matches("^1[3-9]\\d{9}$")) {
            throw new BusinessException("手机号格式不正确");
        }
        if (user.getEmail() != null && !user.getEmail().matches("^[\\w.-]+@[\\w.-]+\\.[a-zA-Z]{2,}$")) {
            throw new BusinessException("邮箱格式不正确");
        }
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
        if (user == null) throw new BusinessException("用户不存在");
        if ("ADMIN".equals(user.getRole())) throw new BusinessException("不能禁用管理员账户");
        if ("DISABLED".equals(user.getStatus())) throw new BusinessException("该账户已被禁用");
        user.setStatus("DISABLED");
        user.setUpdatedAt(new Date());
        userMapper.updateById(user);
    }

    /** 解禁用户 */
    public void enable(Long id) {
        checkAdminOnly();
        SysUser user = userMapper.selectById(id);
        if (user == null) throw new BusinessException("用户不存在");
        if (!"DISABLED".equals(user.getStatus())) throw new BusinessException("该账户未被禁用");
        user.setStatus("ACTIVE");
        user.setUpdatedAt(new Date());
        userMapper.updateById(user);
    }

    /** 重置密码为默认值 123456 */
    public void resetPassword(Long id) {
        checkAdminOnly();
        SysUser user = userMapper.selectById(id);
        if (user == null) throw new BusinessException("用户不存在");
        user.setPasswordHash(passwordEncoder.encode("123456"));
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
