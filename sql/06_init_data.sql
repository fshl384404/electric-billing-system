-- ============================================================================
-- 民用电缴费系统 — 初始化数据脚本
-- 兼容版本: Oracle 11g
-- 说明: 插入系统运行必需的种子数据
--   - 三类角色用户（管理员、收费员、居民）
--   - 房产与电表
--   - 阶梯电价配置
--
-- 注意:
--   - 密码明文存储仅用于课程设计演示，实际项目必须使用 BCrypt 等哈希
--   - 身份证号为虚拟生成的测试数据，非真实信息
--   - 序列从 1 开始（演示数据量小），建表脚本的默认 START WITH 1001 可覆盖
--
-- 执行顺序: 第 6 步，在建表、序列、触发器、存储过程、视图之后
-- ============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200

PROMPT ========== 开始插入初始化数据 ==========

-- ---------------------------------------------------------------------------
-- 1. 系统用户 (SYS_USER)
--    密码明文仅用于测试，实际项目必须加密
-- ---------------------------------------------------------------------------

-- 1.1 管理员
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, status, created_at)
VALUES (1, 'admin', 'admin123', '系统管理员', 'ADMIN', '13800000001', 'admin@power.com', 'ACTIVE', SYSDATE);

-- 1.2 收费员
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, status, created_at)
VALUES (2, 'collector01', 'col123', '张收费', 'COLLECTOR', '13800000002', 'zhang@power.com', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, status, created_at)
VALUES (3, 'collector02', 'col123', '李收费', 'COLLECTOR', '13800000003', 'li@power.com', 'ACTIVE', SYSDATE);

-- 1.3 居民用户 (10 户)
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (4, 'resident01', 'res123', '王小明', 'RESIDENT', '13900000001', 'wangxm@test.com', '110101199001011234', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (5, 'resident02', 'res123', '赵小红', 'RESIDENT', '13900000002', 'zhaoxh@test.com', '110101199102023456', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (6, 'resident03', 'res123', '刘大伟', 'RESIDENT', '13900000003', 'liudw@test.com', '110101199203035678', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (7, 'resident04', 'res123', '陈美丽', 'RESIDENT', '13900000004', 'chenml@test.com', '110101199304047890', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (8, 'resident05', 'res123', '杨建国', 'RESIDENT', '13900000005', 'yangjg@test.com', '110101199405050123', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (9, 'resident06', 'res123', '黄丽丽', 'RESIDENT', '13900000006', 'huangll@test.com', '110101199506062345', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (10, 'resident07', 'res123', '周文博', 'RESIDENT', '13900000007', 'zhouwb@test.com', '110101199607074567', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (11, 'resident08', 'res123', '吴小芳', 'RESIDENT', '13900000008', 'wuxf@test.com', '110101199708086789', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (12, 'resident09', 'res123', '郑志强', 'RESIDENT', '13900000009', 'zhengzq@test.com', '110101199809098901', 'ACTIVE', SYSDATE);

INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (13, 'resident10', 'res123', '孙晓燕', 'RESIDENT', '13900000010', 'sunxy@test.com', '110101199910101234', 'ACTIVE', SYSDATE);

PROMPT 用户数据插入完毕 (3 角色 × 13 条)


-- ---------------------------------------------------------------------------
-- 2. 房产信息 (HOUSE)
--    每个居民至少拥有一套房产。
--    部分居民拥有多套房产（体现一户多宅）。
--
--    分配方案:
--      resident01 (王小明): 2 宅  (house 1, 2)
--      resident02 (赵小红): 1 宅  (house 3)
--      resident03 (刘大伟): 2 宅  (house 4, 5)
--      resident04 (陈美丽): 1 宅  (house 6)
--      resident05 (杨建国): 1 宅  (house 7)
--      resident06 (黄丽丽): 1 宅  (house 8)
--      resident07 (周文博): 1 宅  (house 9)
--      resident08 (吴小芳): 1 宅  (house 10)
--      resident09 (郑志强): 1 宅  (house 11)
--      resident10 (孙晓燕): 1 宅  (house 12)
-- ---------------------------------------------------------------------------

-- resident01 王小明 — 2 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (1, 4, '北京市朝阳区阳光花园1号楼101室', 89.5, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (2, 4, '北京市海淀区翠微小区3号楼502室', 120.0, 'RESIDENTIAL', SYSDATE);

-- resident02 赵小红 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (3, 5, '北京市朝阳区阳光花园2号楼201室', 95.0, 'RESIDENTIAL', SYSDATE);

-- resident03 刘大伟 — 2 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (4, 6, '北京市丰台区星河苑1号楼1501室', 135.0, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (5, 6, '北京市大兴区龙湖家园6号楼303室', 78.0, 'RESIDENTIAL', SYSDATE);

-- resident04 陈美丽 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (6, 7, '北京市朝阳区阳光花园3号楼1102室', 88.0, 'RESIDENTIAL', SYSDATE);

-- resident05 杨建国 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (7, 8, '北京市通州区新华小区8号楼402室', 102.0, 'RESIDENTIAL', SYSDATE);

-- resident06 黄丽丽 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (8, 9, '北京市海淀区翠微小区5号楼701室', 76.5, 'RESIDENTIAL', SYSDATE);

-- resident07 周文博 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (9, 10, '北京市昌平区天通苑东区15号楼2103室', 145.0, 'RESIDENTIAL', SYSDATE);

-- resident08 吴小芳 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (10, 11, '北京市石景山区金顶阳光2号楼602室', 68.0, 'RESIDENTIAL', SYSDATE);

-- resident09 郑志强 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (11, 12, '北京市丰台区星河苑3号楼901室', 110.0, 'RESIDENTIAL', SYSDATE);

-- resident10 孙晓燕 — 1 套房
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (12, 13, '北京市大兴区龙湖家园2号楼505室', 92.0, 'RESIDENTIAL', SYSDATE);

PROMPT 房产数据插入完毕 (12 条)


-- ---------------------------------------------------------------------------
-- 3. 电表信息 (METER)
--    一宅一表，每个房产绑定一个电表
--    电表安装日期统一设为 2025-12-01（在测试数据的时间线之前）
--    初始读数设为模拟值（已使用一段时间的电表）
-- ---------------------------------------------------------------------------

-- 电表编号规则: METER-YYYY-NNNNN
-- 初始读数是安装后到 2025-12-01 的累计读数

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (1, 1, 'METER-2025-00001', 'DDZY102-Z', DATE '2025-12-01', 5230.5, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (2, 2, 'METER-2025-00002', 'DDZY102-Z', DATE '2025-12-01', 8450.0, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (3, 3, 'METER-2025-00003', 'DDZY102-Z', DATE '2025-12-01', 3120.8, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (4, 4, 'METER-2025-00004', 'DDZY102-Z', DATE '2025-12-01', 6780.2, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (5, 5, 'METER-2025-00005', 'DDZY102-Z', DATE '2025-12-01', 1560.0, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (6, 6, 'METER-2025-00006', 'DDZY102-Z', DATE '2025-12-01', 4100.3, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (7, 7, 'METER-2025-00007', 'DDZY102-Z', DATE '2025-12-01', 5540.6, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (8, 8, 'METER-2025-00008', 'DDZY102-Z', DATE '2025-12-01', 2890.1, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (9, 9, 'METER-2025-00009', 'DDZY102-Z', DATE '2025-12-01', 7200.0, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (10, 10, 'METER-2025-00010', 'DDZY102-Z', DATE '2025-12-01', 1980.4, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (11, 11, 'METER-2025-00011', 'DDZY102-Z', DATE '2025-12-01', 6340.7, 'NORMAL', SYSDATE);

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (12, 12, 'METER-2025-00012', 'DDZY102-Z', DATE '2025-12-01', 4450.9, 'NORMAL', SYSDATE);

PROMPT 电表数据插入完毕 (12 条，全部为 NORMAL 状态)


-- ---------------------------------------------------------------------------
-- 4. 电价配置 (PRICE_CONFIG)
--    全国统一阶梯电价，3 个档位
--    第一档: 0 – 200 度, 0.50 元/度
--    第二档: 201 – 400 度, 0.55 元/度
--    第三档: 400 度以上, 0.80 元/度
--    生效日期: 2025-01-01
--    修改人: admin (user_id=1)
-- ---------------------------------------------------------------------------

INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, updated_by, created_at)
VALUES (1, 1, '第一档', 0, 200, 0.50, DATE '2025-01-01', 'Y', 1, SYSDATE);

INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, updated_by, created_at)
VALUES (2, 2, '第二档', 201, 400, 0.55, DATE '2025-01-01', 'Y', 1, SYSDATE);

INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, updated_by, created_at)
VALUES (3, 3, '第三档', 401, NULL, 0.80, DATE '2025-01-01', 'Y', 1, SYSDATE);

PROMPT 电价配置插入完毕 (3 档阶梯电价)


-- ---------------------------------------------------------------------------
-- 提交所有数据
-- ---------------------------------------------------------------------------
COMMIT;

PROMPT
PROMPT ========== 初始化数据汇总 ==========
PROMPT   SYS_USER       : 13 条 (1管理员 + 2收费员 + 10居民)
PROMPT   HOUSE          : 12 条 (2个业主各2套, 其余各1套)
PROMPT   METER          : 12 条 (一宅一表)
PROMPT   PRICE_CONFIG   : 3 条 (三级阶梯电价)
PROMPT
PROMPT   演示账号:
PROMPT     管理员   : admin      / admin123
PROMPT     收费员   : collector01 / col123
PROMPT     居民     : resident01 / res123   (王小明, 2套房)
PROMPT               resident03 / res123   (刘大伟, 2套房)
PROMPT               resident05 / res123   (杨建国, 1套房)
PROMPT ========== 06_init_data.sql 执行完毕 ==========
