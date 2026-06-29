package com.electric.billing.module.house;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.House;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.Map;

@Service
public class HouseService {

    private final HouseMapper houseMapper;

    public HouseService(HouseMapper houseMapper) {
        this.houseMapper = houseMapper;
    }

    /** 房产列表 — 居民只能看自己的 */
    public Map<String, Object> listAll(int page, int pageSize) {
        LambdaQueryWrapper<House> wrapper = new LambdaQueryWrapper<House>()
                .orderByAsc(House::getHouseId);
        if (AuthContext.isResident()) {
            wrapper.eq(House::getUserId, AuthContext.getCurrentUserId());
        }
        return PageUtils.paginate(houseMapper, wrapper, page, pageSize);
    }

    /** 房产详情 */
    public House getById(Long id) {
        House house = houseMapper.selectById(id);
        if (house == null) {
            throw new BusinessException("房产不存在");
        }
        // 居民只能看自己的
        if (AuthContext.isResident() && !house.getUserId().equals(AuthContext.getCurrentUserId())) {
            throw new BusinessException(403, "无权查看");
        }
        return house;
    }

    /** 新增房产 (ADMIN) */
    public House create(House house) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        house.setHouseId(houseMapper.nextId());
        house.setCreatedAt(new Date());
        houseMapper.insert(house);
        return house;
    }

    /** 更新房产 */
    public House update(House house) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        House existing = houseMapper.selectById(house.getHouseId());
        if (existing == null) {
            throw new BusinessException("房产不存在");
        }
        house.setCreatedAt(existing.getCreatedAt());
        houseMapper.updateById(house);
        return house;
    }

    /** 删除房产 (前提：无关联电表) */
    public void delete(Long id) {
        if (!AuthContext.isAdmin()) {
            throw new BusinessException(403, "仅管理员可操作");
        }
        houseMapper.deleteById(id);
    }
}
