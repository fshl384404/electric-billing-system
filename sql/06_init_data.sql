-- ============================================================================
-- 民用电缴费系统 — 初始化数据脚本 (大规模运营模拟版)
-- 执行顺序: 第 6 步, 请在 00-05 执行完毕后运行
-- ============================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 300
SET FEEDBACK OFF
PROMPT ========== 06_init_data.sql 开始执行 ==========

PROMPT [Phase 0] 清理旧数据...
DELETE FROM ticket_reply;
DELETE FROM ticket;
DELETE FROM notification;
DELETE FROM alert;
DELETE FROM payment;
DELETE FROM bill;
DELETE FROM meter_reading;
DELETE FROM meter;
DELETE FROM house;
DELETE FROM price_config;
DELETE FROM sys_user;
COMMIT;

DROP SEQUENCE seq_user_id;          CREATE SEQUENCE seq_user_id          START WITH 1001;
DROP SEQUENCE seq_house_id;         CREATE SEQUENCE seq_house_id         START WITH 1001;
DROP SEQUENCE seq_meter_id;         CREATE SEQUENCE seq_meter_id         START WITH 1001;
DROP SEQUENCE seq_reading_id;       CREATE SEQUENCE seq_reading_id       START WITH 1001;
DROP SEQUENCE seq_price_config_id;  CREATE SEQUENCE seq_price_config_id  START WITH 1001;
DROP SEQUENCE seq_bill_id;          CREATE SEQUENCE seq_bill_id          START WITH 1001;
DROP SEQUENCE seq_payment_id;       CREATE SEQUENCE seq_payment_id       START WITH 1001;
DROP SEQUENCE seq_notif_id;         CREATE SEQUENCE seq_notif_id         START WITH 1001;
DROP SEQUENCE seq_alert_id;         CREATE SEQUENCE seq_alert_id         START WITH 1001;
DROP SEQUENCE seq_ticket_id;        CREATE SEQUENCE seq_ticket_id        START WITH 1001;
DROP SEQUENCE seq_reply_id;         CREATE SEQUENCE seq_reply_id         START WITH 1001;
PROMPT [Phase 0] 清理完毕, 序列已重置

PROMPT [Phase 1] 创建 30 个用户...

-- 管理员
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, status, created_at)
VALUES (1, 'admin', 'admin123', '系统管理员', 'ADMIN', '13800000001', 'admin@power.com', 'ACTIVE', SYSDATE);

-- 收费员
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, status, created_at)
VALUES (2, 'collector01', 'col123', '张建国', 'COLLECTOR', '13901012345', 'zhangjg@power.com', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, status, created_at)
VALUES (3, 'collector02', 'col123', '李美玲', 'COLLECTOR', '13901012346', 'liml@power.com', 'ACTIVE', SYSDATE);

-- 居民 (27 人, IDs 4-30)
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (4, 'resident01', 'res123', '王小明', 'RESIDENT', '13801010001', 'wangxm@email.com', '110101199003152734', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (5, 'resident02', 'res123', '赵小红', 'RESIDENT', '13801010002', 'zhaoxh@email.com', '110102198507213829', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (6, 'resident03', 'res123', '刘大伟', 'RESIDENT', '13801010003', 'liudw@email.com', '110103198812063512', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (7, 'resident04', 'res123', '陈美玲', 'RESIDENT', '13801010004', 'chenml@email.com', '110104199205184627', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (8, 'resident05', 'res123', '杨建国', 'RESIDENT', '13801010005', 'yangjg@email.com', '110105197811254513', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (9, 'resident06', 'res123', '黄丽丽', 'RESIDENT', '13801010006', 'huangll@email.com', '110106198903084928', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (10, 'resident07', 'res123', '周文博', 'RESIDENT', '13801010007', 'zhouwb@email.com', '110107199108195316', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (11, 'resident08', 'res123', '吴小芳', 'RESIDENT', '13801010008', 'wuxf@email.com', '110108199306227420', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (12, 'resident09', 'res123', '郑志强', 'RESIDENT', '13801010009', 'zhengzq@email.com', '110109198411095918', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (13, 'resident10', 'res123', '孙秀英', 'RESIDENT', '13801010010', 'sunxy@email.com', '110101199412016325', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (14, 'resident11', 'res123', '钱伟民', 'RESIDENT', '13801010011', 'qianwm@email.com', '110102198102163018', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (15, 'resident12', 'res123', '马海燕', 'RESIDENT', '13801010012', 'mahy@email.com', '110103198706244521', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (16, 'resident13', 'res123', '朱建华', 'RESIDENT', '13801010013', 'zhujh@email.com', '110104199009185316', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (17, 'resident14', 'res123', '胡桂英', 'RESIDENT', '13801010014', 'hugy@email.com', '110105198511097829', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (18, 'resident15', 'res123', '林志远', 'RESIDENT', '13801010015', 'linzy@email.com', '110106199301226015', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (19, 'resident16', 'res123', '何秀兰', 'RESIDENT', '13801010016', 'hexl@email.com', '110107198808123324', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (20, 'resident17', 'res123', '郭永强', 'RESIDENT', '13801010017', 'guoyq@email.com', '110108199204285112', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (21, 'resident18', 'res123', '高玉珍', 'RESIDENT', '13801010018', 'gaoyz@email.com', '110109198607154028', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (22, 'resident19', 'res123', '罗学军', 'RESIDENT', '13801010019', 'luoxj@email.com', '110101199002193519', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (23, 'resident20', 'res123', '梁慧敏', 'RESIDENT', '13801010020', 'lianghm@email.com', '110102199307126828', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (24, 'resident21', 'res123', '宋国栋', 'RESIDENT', '13801010021', 'songgd@email.com', '110103198504085013', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (25, 'resident22', 'res123', '韩雪梅', 'RESIDENT', '13801010022', 'hanxm@email.com', '110104199103277421', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (26, 'resident23', 'res123', '唐明辉', 'RESIDENT', '13801010023', 'tangmh@email.com', '110105198910182316', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (27, 'resident24', 'res123', '冯丽华', 'RESIDENT', '13801010024', 'fenglh@email.com', '110106198703155928', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (28, 'resident25', 'res123', '董志强', 'RESIDENT', '13801010025', 'dongzq@email.com', '110107199401086015', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (29, 'resident26', 'res123', '谢雅琴', 'RESIDENT', '13801010026', 'xieyq@email.com', '110108198812217324', 'ACTIVE', SYSDATE);
INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
VALUES (30, 'resident27', 'res123', '曹文斌', 'RESIDENT', '13801010027', 'caowb@email.com', '110109199106144917', 'ACTIVE', SYSDATE);
COMMIT;
PROMPT [Phase 1] 30 个用户创建完毕

PROMPT [Phase 2] 创建 40 套房产 (30 住宅 + 10 商用)...

-- 住宅 (30 套)
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (1, 4, '北京市朝阳区阳光花园小区1号楼1单元101室', 89.5, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (2, 4, '北京市朝阳区阳光花园小区2号楼3单元502室', 92.0, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (3, 5, '北京市海淀区翠微嘉园小区3号楼2单元201室', 76.3, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (4, 6, '北京市丰台区星河苑小区1号楼1单元1501室', 108.0, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (5, 6, '北京市丰台区星河苑小区5号楼4单元803室', 65.8, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (6, 7, '北京市大兴区龙湖春天小区6号楼3单元303室', 88.2, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (7, 8, '北京市通州区新华联家园小区8号楼2单元402室', 95.0, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (8, 8, '北京市通州区新华联家园小区11号楼1单元701室', 72.4, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (9, 9, '北京市昌平区天通苑小区3号楼5单元1201室', 115.6, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (10, 10, '北京市石景山区金顶阳光小区2号楼2单元602室', 82.7, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (11, 10, '北京市石景山区金顶阳光小区7号楼4单元301室', 76.9, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (12, 11, '北京市西城区德胜里小区4号楼1单元501室', 78.5, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (13, 12, '北京市东城区和平里小区2号楼3单元702室', 85.3, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (14, 12, '北京市东城区和平里小区5号楼2单元401室', 68.1, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (15, 13, '北京市朝阳区望京花园小区6号楼1单元901室', 98.4, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (16, 14, '北京市海淀区万柳书院小区1号楼2单元1101室', 145.2, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (17, 14, '北京市海淀区万柳书院小区3号楼1单元502室', 132.8, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (18, 15, '北京市丰台区总部基地花园小区8号楼2单元201室', 102.3, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (19, 16, '北京市大兴区枣园小区12号楼4单元301室', 91.6, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (20, 16, '北京市大兴区枣园小区15号楼2单元802室', 88.9, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (21, 17, '北京市通州区梨园小镇9号楼3单元501室', 79.4, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (22, 18, '北京市昌平区回龙观新村4号楼1单元1001室', 110.7, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (23, 18, '北京市昌平区回龙观新村7号楼5单元303室', 58.2, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (24, 19, '北京市石景山区八角北里小区6号楼2单元901室', 83.5, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (25, 20, '北京市西城区金融街丰汇园小区3号楼1单元1201室', 128.6, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (26, 20, '北京市西城区金融街丰汇园小区1号楼4单元602室', 105.3, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (27, 21, '北京市东城区安定门内小区8号楼2单元802室', 94.8, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (28, 22, '北京市朝阳区双井富力城小区10号楼1单元1502室', 135.0, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (29, 22, '北京市朝阳区双井富力城小区2号楼3单元702室', 112.4, 'RESIDENTIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (30, 23, '北京市海淀区中关村知春里小区5号楼2单元401室', 69.7, 'RESIDENTIAL', SYSDATE);

-- 商业房产 (10 套)
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (31, 24, '北京市朝阳区万达广场B座1201室', 186.5, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (32, 25, '北京市海淀区中关村科技大厦8层801室', 220.0, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (33, 26, '北京市丰台区总部基地12号楼302室', 168.3, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (34, 27, '北京市西城区金融街中心A座1501室', 245.8, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (35, 28, '北京市东城区王府井商业中心5层502室', 198.2, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (36, 29, '北京市朝阳区国贸中心大厦22层2201室', 280.0, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (37, 30, '北京市大兴区生物医药基地研发楼3层301室', 155.6, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (38, 4, '北京市通州区万达广场C座901室', 172.4, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (39, 12, '北京市昌平区未来科学城办公楼6层601室', 210.3, 'COMMERCIAL', SYSDATE);
INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
VALUES (40, 18, '北京市海淀区清华科技园D座1101室', 193.7, 'COMMERCIAL', SYSDATE);
COMMIT;
PROMPT [Phase 2] 40 套房产创建完毕

PROMPT [Phase 3] 创建 40 块电表...

INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (1, 1, 'METER-2025-' || LPAD(1,5,'0'), 'DDZY102-Z', DATE '2024-11-15', 1560.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (2, 2, 'METER-2025-' || LPAD(2,5,'0'), 'DDZY102-Z', DATE '2024-11-18', 2340.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (3, 3, 'METER-2025-' || LPAD(3,5,'0'), 'DDZY102-Z', DATE '2024-12-01', 890.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (4, 4, 'METER-2025-' || LPAD(4,5,'0'), 'DDZY102-Z', DATE '2024-12-05', 3200.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (5, 5, 'METER-2025-' || LPAD(5,5,'0'), 'DDZY102-Z', DATE '2024-11-20', 1800.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (6, 6, 'METER-2025-' || LPAD(6,5,'0'), 'DDZY102-Z', DATE '2024-12-10', 750.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (7, 7, 'METER-2025-' || LPAD(7,5,'0'), 'DDZY102-Z', DATE '2024-11-25', 4100.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (8, 8, 'METER-2025-' || LPAD(8,5,'0'), 'DDZY102-Z', DATE '2024-12-02', 2900.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (9, 9, 'METER-2025-' || LPAD(9,5,'0'), 'DDZY102-Z', DATE '2024-11-30', 5600.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (10, 10, 'METER-2025-' || LPAD(10,5,'0'), 'DDZY102-Z', DATE '2024-12-08', 1350.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (11, 11, 'METER-2025-' || LPAD(11,5,'0'), 'DDZY102-Z', DATE '2024-12-12', 2100.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (12, 12, 'METER-2025-' || LPAD(12,5,'0'), 'DDZY102-Z', DATE '2024-11-22', 4800.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (13, 13, 'METER-2025-' || LPAD(13,5,'0'), 'DDZY102-Z', DATE '2024-12-15', 1100.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (14, 14, 'METER-2025-' || LPAD(14,5,'0'), 'DDZY102-Z', DATE '2024-11-16', 3700.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (15, 15, 'METER-2025-' || LPAD(15,5,'0'), 'DDZY102-Z', DATE '2024-12-20', 980.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (16, 16, 'METER-2025-' || LPAD(16,5,'0'), 'DDZY102-Z', DATE '2025-01-05', 2600.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (17, 17, 'METER-2025-' || LPAD(17,5,'0'), 'DDZY102-Z', DATE '2025-01-08', 1950.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (18, 18, 'METER-2025-' || LPAD(18,5,'0'), 'DDZY102-Z', DATE '2025-01-12', 4300.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (19, 19, 'METER-2025-' || LPAD(19,5,'0'), 'DDZY102-Z', DATE '2025-01-15', 3100.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (20, 20, 'METER-2025-' || LPAD(20,5,'0'), 'DDZY102-Z', DATE '2025-01-20', 2800.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (21, 21, 'METER-2025-' || LPAD(21,5,'0'), 'DDZY102-Z', DATE '2025-02-01', 1450.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (22, 22, 'METER-2025-' || LPAD(22,5,'0'), 'DDZY102-Z', DATE '2025-02-05', 5200.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (23, 23, 'METER-2025-' || LPAD(23,5,'0'), 'DDZY102-Z', DATE '2025-02-10', 680.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (24, 24, 'METER-2025-' || LPAD(24,5,'0'), 'DDZY102-Z', DATE '2025-02-15', 3500.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (25, 25, 'METER-2025-' || LPAD(25,5,'0'), 'DDZY102-Z', DATE '2025-02-20', 6400.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (26, 26, 'METER-2025-' || LPAD(26,5,'0'), 'DDZY102-Z', DATE '2025-03-01', 4700.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (27, 27, 'METER-2025-' || LPAD(27,5,'0'), 'DDZY102-Z', DATE '2025-03-05', 2200.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (28, 28, 'METER-2025-' || LPAD(28,5,'0'), 'DDZY102-Z', DATE '2025-03-10', 5900.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (29, 29, 'METER-2025-' || LPAD(29,5,'0'), 'DDZY102-Z', DATE '2025-03-15', 3800.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (30, 30, 'METER-2025-' || LPAD(30,5,'0'), 'DDZY102-Z', DATE '2025-03-20', 1550.0, 'NORMAL', SYSDATE);

-- 商用电表 31-40
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (31, 31, 'METER-2025-' || LPAD(31,5,'0'), 'DDZY102-C', DATE '2025-01-10', 8500.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (32, 32, 'METER-2025-' || LPAD(32,5,'0'), 'DDZY102-C', DATE '2025-01-15', 12000.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (33, 33, 'METER-2025-' || LPAD(33,5,'0'), 'DDZY102-C', DATE '2025-02-01', 7600.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (34, 34, 'METER-2025-' || LPAD(34,5,'0'), 'DDZY102-C', DATE '2025-02-15', 15000.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (35, 35, 'METER-2025-' || LPAD(35,5,'0'), 'DDZY102-C', DATE '2025-03-01', 9800.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (36, 36, 'METER-2025-' || LPAD(36,5,'0'), 'DDZY102-C', DATE '2025-03-10', 18500.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (37, 37, 'METER-2025-' || LPAD(37,5,'0'), 'DDZY102-C', DATE '2025-02-20', 9200.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (38, 38, 'METER-2025-' || LPAD(38,5,'0'), 'DDZY102-C', DATE '2025-03-05', 11000.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (39, 39, 'METER-2025-' || LPAD(39,5,'0'), 'DDZY102-C', DATE '2025-03-15', 13500.0, 'NORMAL', SYSDATE);
INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, status, created_at)
VALUES (40, 40, 'METER-2025-' || LPAD(40,5,'0'), 'DDZY102-C', DATE '2025-03-20', 10200.0, 'NORMAL', SYSDATE);
COMMIT;
PROMPT [Phase 3] 40 块电表创建完毕

PROMPT [Phase 4] 创建电价配置...

-- 民用电价
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, customer_type, updated_by, created_at)
VALUES (1, 1, '第一档(民用)', 0, 200, 0.50, DATE '2025-01-01', 'Y', 'RESIDENTIAL', 1, SYSDATE);
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, customer_type, updated_by, created_at)
VALUES (2, 2, '第二档(民用)', 201, 400, 0.55, DATE '2025-01-01', 'Y', 'RESIDENTIAL', 1, SYSDATE);
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, customer_type, updated_by, created_at)
VALUES (3, 3, '第三档(民用)', 401, NULL, 0.80, DATE '2025-01-01', 'Y', 'RESIDENTIAL', 1, SYSDATE);

-- 商用电价
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, customer_type, updated_by, created_at)
VALUES (4, 1, '第一档(商用)', 0, 500, 0.78, DATE '2025-01-01', 'Y', 'COMMERCIAL', 1, SYSDATE);
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, customer_type, updated_by, created_at)
VALUES (5, 2, '第二档(商用)', 501, 1000, 0.95, DATE '2025-01-01', 'Y', 'COMMERCIAL', 1, SYSDATE);
INSERT INTO price_config (config_id, tier_no, tier_name, lower_limit, upper_limit, unit_price, effective_date, is_active, customer_type, updated_by, created_at)
VALUES (6, 3, '第三档(商用)', 1001, NULL, 1.25, DATE '2025-01-01', 'Y', 'COMMERCIAL', 1, SYSDATE);
COMMIT;
PROMPT [Phase 4] 6 条电价配置创建完毕

PROMPT [Phase 5] 生成 6 个月抄表数据 (via SP3)...
SET SERVEROUTPUT OFF
EXEC sp_test_backfill_readings(DATE '2026-01-01', DATE '2026-06-29');
SET SERVEROUTPUT ON
PROMPT [Phase 5] 抄表数据生成完毕

PROMPT [Phase 6] 生成 6 个月账单...
BEGIN
    FOR m IN 1..6 LOOP
        sp_generate_monthly_bills('2026' || LPAD(m, 2, '0'));
        COMMIT;
    END LOOP;
END;
/
PROMPT [Phase 6] 账单生成完毕

PROMPT [Phase 7] 修正到期日并设置状态分布...
UPDATE bill SET due_date = TO_DATE(bill_month || '15', 'YYYYMMDD') + INTERVAL '1' MONTH;
COMMIT;

DECLARE
    v_status VARCHAR2(10);
    v_rnd    NUMBER;
BEGIN
    FOR rec IN (SELECT bill_id, bill_month FROM bill) LOOP
        v_rnd := DBMS_RANDOM.VALUE(0, 1);
        IF rec.bill_month <= '202603' THEN
            IF v_rnd < 0.60 THEN v_status := 'PAID';
            ELSIF v_rnd < 0.80 THEN v_status := 'PENDING';
            ELSE v_status := 'OVERDUE';
            END IF;
        ELSIF rec.bill_month <= '202605' THEN
            IF v_rnd < 0.40 THEN v_status := 'PAID';
            ELSIF v_rnd < 0.75 THEN v_status := 'PENDING';
            ELSE v_status := 'OVERDUE';
            END IF;
        ELSE
            IF v_rnd < 0.05 THEN v_status := 'PAID';
            ELSIF v_rnd < 0.85 THEN v_status := 'PENDING';
            ELSE v_status := 'OVERDUE';
            END IF;
        END IF;
        UPDATE bill SET status = v_status WHERE bill_id = rec.bill_id;
    END LOOP;
    COMMIT;
END;
/

-- 拉早部分 OVERDUE 账单的 due_date 以触发 SP4
UPDATE bill SET due_date = due_date - 35
WHERE bill_month = '202606' AND status = 'OVERDUE' AND ROWNUM <= 8;
COMMIT;
PROMPT [Phase 7] 状态分布修正完毕

PROMPT [Phase 8] 创建缴费记录...
DECLARE
    v_house_owner NUMBER;
    v_channel     VARCHAR2(10);
    v_collector   NUMBER;
    v_new_id      NUMBER;
BEGIN
    FOR rec IN (
        SELECT b.bill_id, b.total_amount, b.bill_month, b.meter_id
        FROM bill b WHERE b.status = 'PAID'
    ) LOOP
        BEGIN
            SELECT h.user_id INTO v_house_owner
            FROM house h JOIN meter m ON h.house_id = m.house_id
            WHERE m.meter_id = rec.meter_id;
        EXCEPTION WHEN NO_DATA_FOUND THEN CONTINUE;
        END;

        v_channel := CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.6 THEN 'ONLINE' ELSE 'OFFLINE' END;
        v_collector := CASE WHEN v_channel = 'OFFLINE' THEN TRUNC(DBMS_RANDOM.VALUE(2,4)) ELSE NULL END;
        SELECT seq_payment_id.NEXTVAL INTO v_new_id FROM DUAL;

        INSERT INTO payment (payment_id, bill_id, amount, late_fee_paid, channel, payer_id, collector_id, payment_time, transaction_no, created_at)
        VALUES (v_new_id, rec.bill_id, rec.total_amount, 0, v_channel, v_house_owner, v_collector,
                ADD_MONTHS(TO_DATE(rec.bill_month||'01','YYYYMMDD'), 1) + TRUNC(DBMS_RANDOM.VALUE(1,14)),
                'TXN-' || rec.bill_month || '-' || LPAD(v_new_id, 6, '0'), SYSDATE);
    END LOOP;
    COMMIT;
END;
/
PROMPT [Phase 8] 缴费记录创建完毕

PROMPT [Phase 9] 计算滞纳金 (SP2)...
EXEC sp_calc_late_fees;
PROMPT [Phase 9] 滞纳金计算完毕

PROMPT [Phase 10] 生成断电预警 (SP4)...
EXEC sp_power_cutoff_warning;
PROMPT [Phase 10] 断电预警完毕

PROMPT [Phase 11] 模拟读数倒转异常...
DECLARE
    v_last_reading meter.last_reading%TYPE;
BEGIN
    SELECT last_reading INTO v_last_reading FROM meter WHERE meter_id = 5;
    INSERT INTO meter_reading (reading_id, meter_id, reading_date, reading_value, reading_type, created_at)
    VALUES (seq_reading_id.NEXTVAL, 5, DATE '2026-06-15', v_last_reading - 150, 'AUTO', SYSDATE);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('读数倒转记录已插入 (meter_id=5)');
END;
/
PROMPT [Phase 11] 读数倒转异常完毕

PROMPT [Phase 12] 创建工单与回复...

DECLARE
    v_tid NUMBER;
BEGIN
    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 4, 'BILL_INQUIRY', '电费突然上涨近一倍', '我家2026年3月的电费账单比2月高了将近一倍, 从120多元涨到220多, 想核实一下用电明细.', 'PENDING', DATE '2026-03-20');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 7, 'BILL_INQUIRY', '怀疑电表计量不准', '最近三个月电费持续偏高, 每个月都在300元以上, 想核实一下.', 'REPLIED', 2, DATE '2026-02-18', DATE '2026-02-15');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 2, '您好, 我们核实了您家的用电数据: 2月份用电量为285度, 确实偏高. 可能是春节期间取暖设备使用较多导致.', DATE '2026-02-18');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 12, 'BILL_INQUIRY', '阶梯电价计算方式咨询', '我听说用电超过一定度数价格会上涨, 想了解具体的分档标准和每度电的价格.', 'PENDING', DATE '2026-04-05');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 16, 'BILL_INQUIRY', '商业与民用电价差异咨询', '我们公司是商用房产, 电费比住宅高不少, 想了解商用电价的阶梯分档.', 'REPLIED', 1, DATE '2026-04-12', DATE '2026-04-10');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 1, '商业用电三档分别为: 0-500度 0.78元/度, 501-1000度 0.95元/度, 1000度以上 1.25元/度.', DATE '2026-04-12');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 9, 'METER_FAULT', '电表屏幕不亮了', '今天早上发现电表的液晶屏幕完全不显示, 按了按钮也没反应, 不知道是否还在正常计费.', 'PENDING', DATE '2026-05-10');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 14, 'METER_FAULT', '电表发出异常噪音', '最近一周电表一直发出滋滋的声音, 担心有安全隐患, 请尽快派人检查.', 'REPLIED', 3, DATE '2026-03-22', DATE '2026-03-20');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 3, '收到您的报修, 我们已安排维修人员明天上午到您家检查电表, 请保持电话畅通.', DATE '2026-03-22');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 19, 'METER_FAULT', '电表读数跳变异常', '今天查看电表读数时发现数字突然跳了一大截, 一天之内涨了200多度.', 'PENDING', DATE '2026-06-01');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 24, 'METER_FAULT', '商业电表通讯故障', '我公司智能电表最近远程抄表数据一直没有更新, 怀疑通讯模块出问题了.', 'REPLIED', 2, DATE '2026-05-28', DATE '2026-05-25');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 2, '经核查通讯模块间歇性故障, 已远程重置. 如问题仍存在将安排现场更换.', DATE '2026-05-28');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 6, 'COMPLAINT', '小区电压不稳定经常跳闸', '我们小区最近一个月已经跳闸三次了, 每次都是晚上七八点钟, 给生活带来很大不便.', 'PENDING', DATE '2026-06-05');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 11, 'COMPLAINT', '缴费后账单状态未更新', '我三天前通过在线支付缴了电费, 但系统显示还是未缴费状态, 银行已扣款.', 'REPLIED', 1, DATE '2026-05-10', DATE '2026-05-08');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 1, '经查询银行对账记录付款已到账, 已手动更新账单状态并关闭催缴流程.', DATE '2026-05-10');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 21, 'COMPLAINT', '催缴通知发送错误', '我明明已缴清所有电费, 但上周又收到了欠费催缴通知, 查询账单也无欠费.', 'PENDING', DATE '2026-06-12');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 26, 'COMPLAINT', '商业供电不稳定影响生产', '我们厂房最近频繁电压波动, 导致部分设备自动停机, 已造成经济损失.', 'REPLIED', 3, DATE '2026-04-20', DATE '2026-04-18');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 3, '已上报供电所, 24小时内派技术人员到厂区检测电压质量. 如确认线路问题将优先改造.', DATE '2026-04-20');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at)
    VALUES (v_tid, 18, 'OTHER', '想申请更换为智能电表', '我家目前还是老式机械电表, 想申请更换为智能电表, 请问需要什么手续.', 'PENDING', DATE '2026-06-20');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 23, 'OTHER', '咨询用电增容事宜', '我们打算安装充电桩给电动车充电, 担心电表容量不够, 想了解增容流程和费用.', 'REPLIED', 1, DATE '2026-05-15', DATE '2026-05-12');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 1, '需联系物业确认后携证件到营业厅填增容申请表, 费用约2000-5000元, 约15个工作日.', DATE '2026-05-15');

    SELECT seq_ticket_id.NEXTVAL INTO v_tid FROM DUAL;
    INSERT INTO ticket (ticket_id, user_id, type, title, description, status, replied_by, replied_at, created_at)
    VALUES (v_tid, 30, 'OTHER', '商业用电发票开具咨询', '请问线上缴费能否申请电子发票, 流程是什么, 需要提供哪些资料.', 'REPLIED', 2, DATE '2026-06-08', DATE '2026-06-05');
    INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
    VALUES (seq_reply_id.NEXTVAL, v_tid, 2, '线上缴费支持开具电子发票, 缴费成功后点击对应记录即可申请, 会自动发送到注册邮箱.', DATE '2026-06-08');

    COMMIT;
END;
/

PROMPT [Phase 12] 15 条工单 + 8 条回复创建完毕
PROMPT [Phase 13] 补充通知...
INSERT INTO notification (notif_id, user_id, type, title, content, is_read, created_at)
SELECT seq_notif_id.NEXTVAL, t.user_id, 'TICKET_REPLY', '工单回复通知',
       '您的工单[' || t.title || ']已有新的回复, 请登录系统查看.',
       CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.6 THEN 'Y' ELSE 'N' END, tr.created_at
FROM ticket t JOIN ticket_reply tr ON t.ticket_id = tr.ticket_id
WHERE t.status = 'REPLIED';
COMMIT;
PROMPT [Phase 13] 补充通知完毕

PROMPT
PROMPT ========== 初始化数据统计 ==========
SET SERVEROUTPUT ON

DECLARE
    v_users        NUMBER;  v_houses       NUMBER;  v_meters       NUMBER;
    v_readings     NUMBER;  v_bills        NUMBER;  v_payments     NUMBER;
    v_notifs       NUMBER;  v_alerts       NUMBER;  v_tickets      NUMBER;
    v_replies      NUMBER;  v_res_bills    NUMBER;  v_com_bills    NUMBER;
    v_online_pay   NUMBER;  v_offline_pay  NUMBER;
    v_surge        NUMBER;  v_plunge       NUMBER;  v_reversal     NUMBER;
    v_pending_tkt  NUMBER;  v_replied_tkt  NUMBER;
    v_total_rev    NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_users    FROM sys_user;
    SELECT COUNT(*) INTO v_houses   FROM house;
    SELECT COUNT(*) INTO v_meters   FROM meter;
    SELECT COUNT(*) INTO v_readings FROM meter_reading;
    SELECT COUNT(*) INTO v_bills    FROM bill;
    SELECT COUNT(*) INTO v_payments FROM payment;
    SELECT COUNT(*) INTO v_notifs   FROM notification;
    SELECT COUNT(*) INTO v_alerts   FROM alert;
    SELECT COUNT(*) INTO v_tickets  FROM ticket;
    SELECT COUNT(*) INTO v_replies  FROM ticket_reply;

    SELECT COUNT(*) INTO v_res_bills FROM bill b JOIN meter m ON b.meter_id = m.meter_id JOIN house h ON m.house_id = h.house_id WHERE h.house_type = 'RESIDENTIAL';
    SELECT COUNT(*) INTO v_com_bills FROM bill b JOIN meter m ON b.meter_id = m.meter_id JOIN house h ON m.house_id = h.house_id WHERE h.house_type = 'COMMERCIAL';
    SELECT COUNT(*) INTO v_online_pay  FROM payment WHERE channel = 'ONLINE';
    SELECT COUNT(*) INTO v_offline_pay FROM payment WHERE channel = 'OFFLINE';
    SELECT COUNT(*) INTO v_surge    FROM alert WHERE type = 'SURGE';
    SELECT COUNT(*) INTO v_plunge   FROM alert WHERE type = 'PLUNGE';
    SELECT COUNT(*) INTO v_reversal FROM alert WHERE type = 'REVERSAL';
    SELECT COUNT(*) INTO v_pending_tkt FROM ticket WHERE status = 'PENDING';
    SELECT COUNT(*) INTO v_replied_tkt FROM ticket WHERE status = 'REPLIED';
    SELECT NVL(SUM(amount), 0) INTO v_total_rev FROM payment;

    DBMS_OUTPUT.PUT_LINE('SYS_USER       : ' || v_users    || ' (1管理员 + 2收费员 + ' || (v_users-3) || '居民)');
    DBMS_OUTPUT.PUT_LINE('HOUSE          : ' || v_houses);
    DBMS_OUTPUT.PUT_LINE('METER          : ' || v_meters);
    DBMS_OUTPUT.PUT_LINE('METER_READING  : ' || v_readings);
    DBMS_OUTPUT.PUT_LINE('BILL           : ' || v_bills || ' (民用' || v_res_bills || ' + 商用' || v_com_bills || ')');
    DBMS_OUTPUT.PUT_LINE('PAYMENT        : ' || v_payments || ' (在线' || v_online_pay || ' + 线下' || v_offline_pay || ')');
    DBMS_OUTPUT.PUT_LINE('NOTIFICATION   : ' || v_notifs);
    DBMS_OUTPUT.PUT_LINE('ALERT          : ' || v_alerts || ' (SURGE=' || v_surge || ' PLUNGE=' || v_plunge || ' REVERSAL=' || v_reversal || ')');
    DBMS_OUTPUT.PUT_LINE('TICKET         : ' || v_tickets || ' (待处理' || v_pending_tkt || ' + 已回复' || v_replied_tkt || ')');
    DBMS_OUTPUT.PUT_LINE('TICKET_REPLY   : ' || v_replies);
    DBMS_OUTPUT.PUT_LINE('总营收(元)     : ' || TO_CHAR(v_total_rev, '999,999,999.99'));
END;
/

PROMPT ========== 06_init_data.sql 执行完成 ==========
