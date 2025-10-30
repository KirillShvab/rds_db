/*
Определение количества активных риэлторов за актуальный отчётный месяц.
*/
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
        dt.actual_date as date_slice,
        e.city_name,
        e.employee_name as rieltor_name,
        e.employee_id as rieltor_id,
        e.date_employment
    FROM hr_new.employees AS e
    JOIN dates_cte AS dt ON TRUE
    WHERE
    e.period = dt.actual_date
    AND e.employee_work_status IN ('В ежегодном отпуске', 'В работе', 'Приостановить прием заявок') 
    AND e.employee_status = 'Активен' -- тут возможны однозначно проблемы
    AND e.employee_type = 'Специалист отдела продаж'
    AND e.employee_work_type = 'Риэлтор' 
    AND e.employee_group_0 = FALSE -- тут возможны проблемы
    AND e.employee_status_priority = True
    AND e.department_name IN (  'Департамент межрегиональных сделок', 
                                'Департамент новостроек',
                                'Департамент коммерческой недвижимости',
                                'Департамент продаж', 
                                'Отдел загородной недвижимости',
                                'Отдел коммерческой недвижимости', 
                                'Отдел новостроек',
                                'Отдел продаж')
)
select count(*)
from deposits