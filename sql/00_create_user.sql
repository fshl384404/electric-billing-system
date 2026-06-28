-- ============================================================================
-- 创建数据库用户（由 test-all.bat 在第 1 步调用）
-- 直接连接 FREEPDB1 服务
-- ============================================================================
SET SERVEROUTPUT ON

-- 清理旧用户
BEGIN
  EXECUTE IMMEDIATE 'DROP USER elec_billing CASCADE';
  DBMS_OUTPUT.PUT_LINE('旧用户已清理');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -01918 THEN
      DBMS_OUTPUT.PUT_LINE('用户不存在，跳过清理');
    ELSE
      DBMS_OUTPUT.PUT_LINE('清理异常: ' || SQLERRM);
    END IF;
END;
/

CREATE USER elec_billing
  IDENTIFIED BY elec_billing
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT CONNECT, RESOURCE TO elec_billing;
GRANT CREATE VIEW TO elec_billing;
GRANT CREATE ANY TRIGGER TO elec_billing;
GRANT CREATE ANY PROCEDURE TO elec_billing;
GRANT EXECUTE ON DBMS_RANDOM TO elec_billing;

PROMPT
PROMPT 用户 elec_billing 创建成功
EXIT;