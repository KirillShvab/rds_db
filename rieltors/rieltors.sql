WITH dates_cte AS (
    SELECT
        CASE
            WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 3 
                THEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::timestamp
            ELSE DATE_TRUNC('month', CURRENT_DATE)::timestamp
        END AS actual_date
),
/*rieltors формирует список активных риэлторов на текущий отчетный месяц*/
rieltors AS (
    SELECT 
        dt.actual_date AS date_slice,
        e.city_name,
        e.hsd_name,
        e.msd_name,
        e.employee_name AS rieltor_name,
        e.employee_id AS rieltor_id,
        e.date_employment,
        e.experience_month AS experience_metric,
        ((EXTRACT(YEAR FROM dt.actual_date) - EXTRACT(YEAR FROM e.date_employment)) * 12
              + (EXTRACT(MONTH FROM dt.actual_date) - EXTRACT(MONTH FROM e.date_employment))
              + CASE WHEN EXTRACT(DAY FROM e.date_employment) <= 10 THEN 1 ELSE 0 END
            )::int AS old_experience_month
    FROM hr_new.employees AS e
    JOIN dates_cte AS dt ON TRUE
    WHERE
        e.period = dt.actual_date
        AND e.employee_work_status IN ('В ежегодном отпуске', 'В работе', 'Приостановить прием заявок')
        --AND e.employee_status = 'Активен'  -- проблемная зона, не всегда актуальные статусы
        AND e.employee_type = 'Специалист отдела продаж'
        AND e.employee_work_type = 'Риэлтор'
        AND e.employee_group_0 = FALSE
        AND e.employee_status_priority = TRUE
        AND e.department_name IN (
            'Департамент межрегиональных сделок', 
            'Департамент новостроек',
            'Департамент коммерческой недвижимости',
            'Департамент продаж', 
            'Отдел загородной недвижимости',
            'Отдел коммерческой недвижимости', 
            'Отдел новостроек',
            'Отдел продаж'
        )
),
