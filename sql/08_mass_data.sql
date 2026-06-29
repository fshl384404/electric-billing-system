-- ============================================================================
-- Mass Data Generation Script — Large-scale testing (no Chinese chars)
-- Scale: 100 users + 120 houses + 120 meters + 21,600 readings + 720 bills
-- ============================================================================

SET ECHO OFF
SET SERVEROUTPUT ON
SET FEEDBACK OFF

PROMPT === Phase 1: 100 Residents ===

DECLARE
    v_next_id NUMBER;
    TYPE t_names IS TABLE OF VARCHAR2(20);
    first_names t_names := t_names('James','Mary','John','Patricia','Robert','Linda','Michael','Barbara','William','Elizabeth','David','Jennifer','Richard','Susan','Joseph','Jessica','Thomas','Sarah','Charles','Karen');
    last_names t_names := t_names('Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez','Wilson','Anderson','Taylor','Thomas','Moore','Jackson','Martin','Lee','White','Harris');
BEGIN
    SELECT MAX(user_id) + 1 INTO v_next_id FROM sys_user;

    FOR i IN 1..100 LOOP
        INSERT INTO sys_user (user_id, username, password_hash, real_name, role, phone, email, id_card, status, created_at)
        VALUES (
            v_next_id + i - 1,
            'user' || LPAD(i, 4, '0'),
            'res123',
            first_names(TRUNC(DBMS_RANDOM.VALUE(1, 21))) || ' ' || last_names(TRUNC(DBMS_RANDOM.VALUE(1, 21))),
            'RESIDENT',
            '138' || LPAD(TRUNC(DBMS_RANDOM.VALUE(10000000, 99999999)), 8, '0'),
            'user' || i || '@test.com',
            '110101' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1980, 2005))) || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 12)), 2, '0') || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 28)), 2, '0') || LPAD(i, 4, '0'),
            'ACTIVE',
            SYSDATE
        );
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Residents created: 100');
END;
/

PROMPT === Phase 2: 120 Houses ===

DECLARE
    v_next_id NUMBER;
    v_user_id NUMBER;
    TYPE t_streets IS TABLE OF VARCHAR2(40);
    streets t_streets := t_streets('Sunshine Garden Chaoyang','Cuiwei Community Haidian','Xinghe Court Fengtai','Longhu Spring Daxing','Xinhua Garden Tongzhou',
        'Tiantongyuan Changping','Jinding Street Shijingshan','Deshengli Xicheng','Hepingli Dongcheng','Wangjing New Town Chaoyang');
    TYPE t_user_ids IS TABLE OF NUMBER;
    v_residents t_user_ids;
    v_count NUMBER := 0;
BEGIN
    SELECT MAX(house_id) + 1 INTO v_next_id FROM house;
    SELECT user_id BULK COLLECT INTO v_residents FROM sys_user WHERE role = 'RESIDENT' ORDER BY user_id;

    FOR i IN 1..120 LOOP
        v_user_id := v_residents(TRUNC(DBMS_RANDOM.VALUE(1, v_residents.COUNT + 1)));
        INSERT INTO house (house_id, user_id, address, area, house_type, created_at)
        VALUES (
            v_next_id + i - 1, v_user_id,
            streets(TRUNC(DBMS_RANDOM.VALUE(1, 11))) || ' Block' || TRUNC(DBMS_RANDOM.VALUE(1, 30)) || ' Bldg' || TRUNC(DBMS_RANDOM.VALUE(1, 20)) || ' Rm' || TRUNC(DBMS_RANDOM.VALUE(101, 2501)),
            TRUNC(DBMS_RANDOM.VALUE(55, 160), 1),
            'RESIDENTIAL', SYSDATE
        );
        v_count := v_count + 1;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Houses created: ' || v_count);
END;
/

PROMPT === Phase 3: 120 Meters ===

DECLARE
    v_next_id NUMBER;
    v_reading NUMBER;
    v_count NUMBER := 0;
BEGIN
    SELECT NVL(MAX(meter_id), 1000) + 1 INTO v_next_id FROM meter;

    FOR rec IN (
        SELECT h.house_id FROM house h
        WHERE NOT EXISTS (SELECT 1 FROM meter m WHERE m.house_id = h.house_id)
        ORDER BY h.house_id
    ) LOOP
        v_reading := TRUNC(DBMS_RANDOM.VALUE(800, 9500), 2);
        INSERT INTO meter (meter_id, house_id, meter_no, model, install_date, initial_reading, last_reading, last_reading_date, status, created_at)
        VALUES (
            v_next_id, rec.house_id,
            'METER-MASS-' || LPAD(v_next_id, 6, '0'),
            'DDZY102-Z',
            TO_DATE('2025-01-01', 'YYYY-MM-DD'),
            v_reading, v_reading, TO_DATE('2025-01-01', 'YYYY-MM-DD'),
            'NORMAL', SYSDATE
        );
        v_next_id := v_next_id + 1;
        v_count := v_count + 1;
        EXIT WHEN v_count >= 120;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Meters created: ' || v_count);
END;
/

PROMPT === Phase 4: Daily Readings (6 months x 120 meters = 21,600) ===

-- Disable triggers temporarily for bulk insert performance
ALTER TRIGGER tr1_calc_daily_usage DISABLE;
ALTER TRIGGER trg_meter_update_snapshot DISABLE;
ALTER TRIGGER tr4a_reversal_detect DISABLE;

DECLARE
    v_next_id NUMBER;
    v_last_read NUMBER;
    v_curr_read NUMBER;
    v_daily NUMBER;
    v_date DATE;
    v_count NUMBER := 0;
    v_season_factor NUMBER;
    v_weekend_factor NUMBER;
BEGIN
    SELECT NVL(MAX(reading_id), 0) + 1 INTO v_next_id FROM meter_reading;

    FOR m IN (SELECT meter_id, last_reading FROM meter WHERE status = 'NORMAL') LOOP
        v_last_read := m.last_reading;
        v_date := TO_DATE('2026-01-01', 'YYYY-MM-DD');

        FOR d IN 1..180 LOOP
            v_daily := TRUNC(DBMS_RANDOM.VALUE(3, 20), 2);

            -- Seasonal factor
            IF EXTRACT(MONTH FROM v_date) IN (6,7,8) THEN
                v_season_factor := 1.5;
            ELSIF EXTRACT(MONTH FROM v_date) IN (12,1,2) THEN
                v_season_factor := 1.3;
            ELSE
                v_season_factor := 1.0;
            END IF;

            -- Weekend factor
            IF TO_CHAR(v_date, 'D') IN (1,7) THEN
                v_weekend_factor := 1.2;
            ELSE
                v_weekend_factor := 1.0;
            END IF;

            v_daily := TRUNC(v_daily * v_season_factor * v_weekend_factor * DBMS_RANDOM.VALUE(0.8, 1.2), 2);
            v_curr_read := TRUNC(v_last_read + v_daily, 2);

            INSERT INTO meter_reading (reading_id, meter_id, reading_date, reading_value, daily_usage, reading_type, created_at)
            VALUES (v_next_id, m.meter_id, v_date, v_curr_read, v_daily, 'AUTO', SYSDATE);

            v_last_read := v_curr_read;
            v_date := v_date + 1;
            v_next_id := v_next_id + 1;
            v_count := v_count + 1;
        END LOOP;

        UPDATE meter SET last_reading = v_last_read, last_reading_date = v_date - 1
        WHERE meter_id = m.meter_id;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Readings created: ' || v_count);
END;
/

-- Re-enable triggers
ALTER TRIGGER tr1_calc_daily_usage ENABLE;
ALTER TRIGGER trg_meter_update_snapshot ENABLE;
ALTER TRIGGER tr4a_reversal_detect ENABLE;

PROMPT === Phase 5: Monthly Bills (6 months x 120 meters ~720) ===

DECLARE
    v_next_bill NUMBER;
    v_next_pay NUMBER;
    v_next_notif NUMBER;
    v_prev_read NUMBER;
    v_curr_read NUMBER;
    v_usage NUMBER;
    v_t1_u NUMBER; v_t2_u NUMBER; v_t3_u NUMBER;
    v_t1_a NUMBER; v_t2_a NUMBER; v_t3_a NUMBER;
    v_total NUMBER;
    v_p1 NUMBER; v_p2 NUMBER; v_p3 NUMBER;
    v_status VARCHAR2(20);
    v_due_date DATE;
    v_months VARCHAR2(6);
    v_payer_id NUMBER;
    v_count_b NUMBER := 0;
    v_count_p NUMBER := 0;
    v_count_n NUMBER := 0;
BEGIN
    SELECT NVL(MAX(bill_id), 0) + 1 INTO v_next_bill FROM bill;
    SELECT NVL(MAX(payment_id), 0) + 1 INTO v_next_pay FROM payment;
    SELECT NVL(MAX(notif_id), 0) + 1 INTO v_next_notif FROM notification;

    SELECT unit_price INTO v_p1 FROM price_config WHERE tier_no=1 AND is_active='Y';
    SELECT unit_price INTO v_p2 FROM price_config WHERE tier_no=2 AND is_active='Y';
    SELECT unit_price INTO v_p3 FROM price_config WHERE tier_no=3 AND is_active='Y';

    FOR m IN (SELECT meter_id FROM meter WHERE status = 'NORMAL') LOOP
        -- Get payer (house owner) for this meter
        BEGIN
            SELECT u.user_id INTO v_payer_id
            FROM sys_user u JOIN house h ON u.user_id = h.user_id
            WHERE h.house_id = (SELECT house_id FROM meter WHERE meter_id = m.meter_id) AND u.role = 'RESIDENT';
        EXCEPTION WHEN NO_DATA_FOUND THEN v_payer_id := 4; END;

        FOR month_i IN 1..6 LOOP
            v_months := '2026' || LPAD(month_i, 2, '0');

            BEGIN
                SELECT reading_value INTO v_prev_read FROM meter_reading
                WHERE meter_id = m.meter_id
                  AND reading_date = TO_DATE('2026-' || LPAD(month_i, 2, '0') || '-01', 'YYYY-MM-DD')
                  AND ROWNUM = 1;
            EXCEPTION WHEN NO_DATA_FOUND THEN CONTINUE; END;

            BEGIN
                SELECT MAX(reading_value) INTO v_curr_read FROM meter_reading
                WHERE meter_id = m.meter_id
                  AND reading_date >= TO_DATE('2026-' || LPAD(month_i, 2, '0') || '-01', 'YYYY-MM-DD')
                  AND reading_date < ADD_MONTHS(TO_DATE('2026-' || LPAD(month_i, 2, '0') || '-01', 'YYYY-MM-DD'), 1);
            EXCEPTION WHEN NO_DATA_FOUND THEN CONTINUE; END;

            v_usage := TRUNC(v_curr_read - v_prev_read, 2);
            IF v_usage <= 0 THEN CONTINUE; END IF;

            -- Tier calculation
            v_t1_u := LEAST(v_usage, 200);
            v_t2_u := GREATEST(0, LEAST(v_usage - 200, 200));
            v_t3_u := GREATEST(0, v_usage - 400);
            v_t1_a := TRUNC(v_t1_u * v_p1, 2);
            v_t2_a := TRUNC(v_t2_u * v_p2, 2);
            v_t3_a := TRUNC(v_t3_u * v_p3, 2);
            v_total := v_t1_a + v_t2_a + v_t3_a;

            -- Status distribution
            IF month_i <= 4 THEN
                v_status := CASE TRUNC(DBMS_RANDOM.VALUE(1, 10))
                    WHEN 1 THEN 'PENDING' WHEN 2 THEN 'PENDING' WHEN 3 THEN 'PENDING'
                    WHEN 4 THEN 'OVERDUE' WHEN 5 THEN 'OVERDUE' WHEN 6 THEN 'OVERDUE'
                    ELSE 'PAID' END;
            ELSIF month_i = 5 THEN
                v_status := CASE TRUNC(DBMS_RANDOM.VALUE(1, 3))
                    WHEN 1 THEN 'PAID' ELSE 'PENDING' END;
            ELSE
                v_status := 'PENDING';
            END IF;

            v_due_date := ADD_MONTHS(TO_DATE(v_months || '01', 'YYYYMM'), 1) + 14;

            INSERT INTO bill (bill_id, meter_id, bill_month, prev_reading, curr_reading,
                total_usage, tier1_usage, tier2_usage, tier3_usage,
                tier1_amount, tier2_amount, tier3_amount, total_amount, late_fee,
                status, due_date, created_at)
            VALUES (v_next_bill, m.meter_id, v_months, v_prev_read, v_curr_read,
                v_usage, v_t1_u, v_t2_u, v_t3_u, v_t1_a, v_t2_a, v_t3_a, v_total,
                CASE WHEN v_status = 'OVERDUE' THEN TRUNC(v_total * 0.02, 2) ELSE 0 END,
                v_status, v_due_date, SYSDATE);
            v_count_b := v_count_b + 1;

            -- Paid: generate payment
            IF v_status = 'PAID' THEN
                INSERT INTO payment (payment_id, bill_id, amount, late_fee_paid, channel,
                    payer_id, payment_time, transaction_no, created_at)
                VALUES (v_next_pay, v_next_bill, v_total, 0,
                    CASE TRUNC(DBMS_RANDOM.VALUE(1,3)) WHEN 1 THEN 'OFFLINE' ELSE 'ONLINE' END,
                    v_payer_id,
                    v_due_date - TRUNC(DBMS_RANDOM.VALUE(1, 5)),
                    'TXN-MASS-' || v_next_pay, SYSDATE);
                v_next_pay := v_next_pay + 1;
                v_count_p := v_count_p + 1;
            END IF;

            -- Overdue: notification
            IF v_status = 'OVERDUE' THEN
                INSERT INTO notification (notif_id, user_id, type, title, content, related_id, is_read, created_at)
                VALUES (v_next_notif, v_payer_id, 'ARREARS',
                    'Arrears Notice',
                    'Your ' || v_months || ' bill is overdue. Please pay ASAP.',
                    v_next_bill, 'N', SYSDATE);
                v_next_notif := v_next_notif + 1;
                v_count_n := v_count_n + 1;
            END IF;

            v_next_bill := v_next_bill + 1;
        END LOOP;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Bills: ' || v_count_b || ' | Payments: ' || v_count_p || ' | Notifs: ' || v_count_n);
END;
/

PROMPT === Phase 6: Alerts and Tickets ===

DECLARE
    v_next_alert NUMBER;
    v_next_ticket NUMBER;
    v_next_reply NUMBER;
    v_meter_id NUMBER;
    v_user_id NUMBER;
    v_replier_id NUMBER;
    v_count_a NUMBER := 0;
    v_count_t NUMBER := 0;
    v_count_r NUMBER := 0;
BEGIN
    SELECT NVL(MAX(alert_id), 0) + 1 INTO v_next_alert FROM alert;
    SELECT NVL(MAX(ticket_id), 0) + 1 INTO v_next_ticket FROM ticket;
    SELECT NVL(MAX(reply_id), 0) + 1 INTO v_next_reply FROM ticket_reply;

    -- 50 random alerts
    FOR i IN 1..50 LOOP
        SELECT meter_id INTO v_meter_id FROM (SELECT meter_id FROM meter ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
        INSERT INTO alert (alert_id, meter_id, type, alert_level, description, status, handler_id, handled_at, created_at)
        VALUES (v_next_alert, v_meter_id,
            CASE TRUNC(DBMS_RANDOM.VALUE(1,4)) WHEN 1 THEN 'SURGE' WHEN 2 THEN 'PLUNGE' ELSE 'REVERSAL' END,
            CASE TRUNC(DBMS_RANDOM.VALUE(1,4)) WHEN 1 THEN 'INFO' WHEN 2 THEN 'WARN' ELSE 'CRITICAL' END,
            'Mass test alert #' || i || ' for meter ' || v_meter_id,
            CASE TRUNC(DBMS_RANDOM.VALUE(1,3)) WHEN 1 THEN 'HANDLED' ELSE 'PENDING' END,
            CASE WHEN TRUNC(DBMS_RANDOM.VALUE(1,3)) = 1 THEN 1 END,
            CASE WHEN TRUNC(DBMS_RANDOM.VALUE(1,3)) = 1 THEN SYSDATE END,
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 60)));
        v_next_alert := v_next_alert + 1; v_count_a := v_count_a + 1;
    END LOOP;

    -- 30 tickets with replies
    FOR i IN 1..30 LOOP
        SELECT user_id INTO v_user_id FROM (SELECT user_id FROM sys_user WHERE role='RESIDENT' ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
        INSERT INTO ticket (ticket_id, user_id, type, title, description, status, created_at, replied_at, replied_by)
        VALUES (v_next_ticket, v_user_id,
            CASE TRUNC(DBMS_RANDOM.VALUE(1,5)) WHEN 1 THEN 'BILL_INQUIRY' WHEN 2 THEN 'METER_FAULT' WHEN 3 THEN 'COMPLAINT' ELSE 'OTHER' END,
            'Mass test ticket #' || i, 'Large-scale test ticket description.',
            CASE TRUNC(DBMS_RANDOM.VALUE(1,3)) WHEN 1 THEN 'PENDING' ELSE 'REPLIED' END,
            SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 30)),
            CASE WHEN TRUNC(DBMS_RANDOM.VALUE(1,3)) > 1 THEN SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 10)) END,
            CASE WHEN TRUNC(DBMS_RANDOM.VALUE(1,3)) > 1 THEN (SELECT user_id FROM (SELECT user_id FROM sys_user WHERE role IN ('ADMIN','COLLECTOR') ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1) END);
        v_count_t := v_count_t + 1;

        IF TRUNC(DBMS_RANDOM.VALUE(1,3)) > 1 THEN
            SELECT user_id INTO v_replier_id FROM (SELECT user_id FROM sys_user WHERE role IN ('ADMIN','COLLECTOR') ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
            INSERT INTO ticket_reply (reply_id, ticket_id, replier_id, content, created_at)
            VALUES (v_next_reply, v_next_ticket, v_replier_id,
                'Re: ticket #' || i || ' - reviewed and resolved.', SYSDATE - TRUNC(DBMS_RANDOM.VALUE(1, 9)));
            v_next_reply := v_next_reply + 1; v_count_r := v_count_r + 1;
        END IF;

        v_next_ticket := v_next_ticket + 1;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Alerts: ' || v_count_a || ' | Tickets: ' || v_count_t || ' | Replies: ' || v_count_r);
END;
/

PROMPT === Phase 7: Final Statistics ===

DECLARE
    v_u NUMBER; v_h NUMBER; v_m NUMBER; v_r NUMBER; v_b NUMBER; v_p NUMBER; v_n NUMBER; v_a NUMBER; v_t NUMBER; v_tr NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_u FROM sys_user;
    SELECT COUNT(*) INTO v_h FROM house;
    SELECT COUNT(*) INTO v_m FROM meter;
    SELECT COUNT(*) INTO v_r FROM meter_reading;
    SELECT COUNT(*) INTO v_b FROM bill;
    SELECT COUNT(*) INTO v_p FROM payment;
    SELECT COUNT(*) INTO v_n FROM notification;
    SELECT COUNT(*) INTO v_a FROM alert;
    SELECT COUNT(*) INTO v_t FROM ticket;
    SELECT COUNT(*) INTO v_tr FROM ticket_reply;
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Mass Data Generation Complete!');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Users:          ' || v_u);
    DBMS_OUTPUT.PUT_LINE('Houses:         ' || v_h);
    DBMS_OUTPUT.PUT_LINE('Meters:         ' || v_m);
    DBMS_OUTPUT.PUT_LINE('Readings:       ' || v_r);
    DBMS_OUTPUT.PUT_LINE('Bills:          ' || v_b);
    DBMS_OUTPUT.PUT_LINE('Payments:       ' || v_p);
    DBMS_OUTPUT.PUT_LINE('Notifications:  ' || v_n);
    DBMS_OUTPUT.PUT_LINE('Alerts:         ' || v_a);
    DBMS_OUTPUT.PUT_LINE('Tickets:        ' || v_t);
    DBMS_OUTPUT.PUT_LINE('Ticket Replies: ' || v_tr);
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

PROMPT === Done! Mass data ready for testing. ===
