-- space and newbi
WITH dates_cte AS (
    SELECT
        CASE
            WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 3 
                THEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::timestamp
            ELSE DATE_TRUNC('month', CURRENT_DATE)::timestamp
        END AS actual_date
),
deals AS (
    SELECT 
        d.date_deal_findep,
        d.city_name,
        d.rieltor_name, 
        d.rieltor_id,
        e.date_employment 
    FROM reports."278_6_deal" AS d
    JOIN dates_cte AS dt ON TRUE
    JOIN hr_new.employees AS e 
        ON d.rieltor_id = e.employee_id
        AND e.period = dt.actual_date
    JOIN hr_new.cities AS c
    ON e.city_name = c.city_name 
    WHERE d.date_deal_findep >= dt.actual_date
      AND d.date_deal_findep < (dt.actual_date + INTERVAL '1 month')
      AND d.msd_rieltor_result = 'Риэлтор'
      AND LOWER(d.employee_group_0) = 'нет'
      AND e.employee_status_priority = TRUE
      AND LOWER(d.deal_type_sell_buyer) IN ('покупка', 'продажа') -- TODO нужны ли нам и другие сделки для newbi?
      AND e.employee_type = 'Специалист отдела продаж'
      -- депатаменты для newbi и space
      AND e.department_name IN (
            'Департамент межрегиональных сделок', 
            'Департамент новостроек',
            'Департамент продаж', 
            'Отдел загородной недвижимости',
            'Отдел коммерческой недвижимости', 
            'Отдел новостроек',
            'Отдел продаж',
		    'Департамент коммерческой недвижимости',
		    'Отдел межрегиональных и международных сделок'
      )
)
SELECT *
FROM deals;