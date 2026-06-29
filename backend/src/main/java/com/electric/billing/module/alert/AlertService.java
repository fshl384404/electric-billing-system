package com.electric.billing.module.alert;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.Alert;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.Map;

@Service
public class AlertService {

    private final AlertMapper alertMapper;

    public AlertService(AlertMapper alertMapper) {
        this.alertMapper = alertMapper;
    }

    /** 告警列表 (ADMIN/COLLECTOR) */
    public Map<String, Object> listAll(int page, int pageSize, String status) {
        if (AuthContext.isResident()) throw new BusinessException(403, "无权限");
        return PageUtils.paginate(alertMapper,
            new LambdaQueryWrapper<Alert>()
                .eq(status != null, Alert::getStatus, status)
                .orderByDesc(Alert::getCreatedAt), page, pageSize);
    }

    /** 处理告警 */
    public void handle(Long alertId) {
        if (AuthContext.isResident()) {
            throw new BusinessException(403, "无权限");
        }
        Alert alert = alertMapper.selectById(alertId);
        if (alert == null) {
            throw new BusinessException("告警不存在");
        }
        if ("HANDLED".equals(alert.getStatus())) {
            throw new BusinessException("该告警已处理");
        }
        alert.setStatus("HANDLED");
        alert.setHandlerId(AuthContext.getCurrentUserId());
        alert.setHandledAt(new Date());
        alertMapper.updateById(alert);
    }
}
