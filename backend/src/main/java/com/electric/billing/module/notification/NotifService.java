package com.electric.billing.module.notification;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.entity.Notification;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NotifService {

    private final NotifMapper notifMapper;

    public NotifService(NotifMapper notifMapper) {
        this.notifMapper = notifMapper;
    }

    /** 当前用户的通知列表 */
    public List<Notification> listMy() {
        return notifMapper.selectList(
                new LambdaQueryWrapper<Notification>()
                        .eq(Notification::getUserId, AuthContext.getCurrentUserId())
                        .orderByDesc(Notification::getCreatedAt)
        );
    }

    /** 未读数量 */
    public long unreadCount() {
        return notifMapper.selectCount(
                new LambdaQueryWrapper<Notification>()
                        .eq(Notification::getUserId, AuthContext.getCurrentUserId())
                        .eq(Notification::getIsRead, "N")
        );
    }

    /** 标记已读 */
    public void markRead(Long id) {
        Notification notif = notifMapper.selectById(id);
        if (notif == null) {
            throw new BusinessException("通知不存在");
        }
        if (!notif.getUserId().equals(AuthContext.getCurrentUserId())) {
            throw new BusinessException(403, "无权操作");
        }
        notif.setIsRead("Y");
        notifMapper.updateById(notif);
    }

    /** 全部标记已读 */
    public void markAllRead() {
        LambdaUpdateWrapper<Notification> wrapper = new LambdaUpdateWrapper<Notification>()
                .eq(Notification::getUserId, AuthContext.getCurrentUserId())
                .eq(Notification::getIsRead, "N")
                .set(Notification::getIsRead, "Y");
        notifMapper.update(wrapper);
    }
}
