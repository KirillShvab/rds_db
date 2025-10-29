-- newbi space
WITH dates_cte AS (
    SELECT
        CASE
            WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 3 
                THEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::timestamp
            ELSE DATE_TRUNC('month', CURRENT_DATE)::timestamp
        END AS actual_date
),
deposits AS
(
    SELECT 
        d.date_deposit,
        d.city_name,
        d.rieltor_name, 
        d.rieltor_id,
        e.date_employment 
    FROM reports."257_11_deposit" AS d
    JOIN dates_cte AS dt ON TRUE
    JOIN hr_new.employees AS e 
        ON d.rieltor_id = e.employee_id
        AND e.period = dt.actual_date
    WHERE d.date_deposit >= dt.actual_date
        AND d.date_deposit < (dt.actual_date + INTERVAL '1 month')
    AND e.employee_work_status IN ('В ежегодном отпуске', 'В работе', 'Приостановить прием заявок') 
    AND d.deposit_status NOT IN ('Сорвался') 
    AND e.employee_status = 'Активен' -- кто-то уволен раньше (по базе), а сделка позже во времени
    AND e.employee_type = 'Специалист отдела продаж'
    AND e.employee_work_type = 'Риэлтор' 
    AND d.employee_group_0 = 'Нет'
    AND e.employee_status_priority = True
    AND e.department_name IN (  'Департамент межрегиональных сделок',
                                'Департамент новостроек',
                                'Отдел межрегиональных и международных сделок',
                                'Департамент продаж',
                                'Отдел загородной недвижимости',
                                'Отдел коммерческой недвижимости',
                                'Отдел новостроек',
                                'Отдел продаж',
                                'Департамент коммерческой недвижимости')
)
select count(*)
from deposits
