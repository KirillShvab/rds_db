-- interregional deals
WITH dates_cte AS (
    SELECT
        CASE
            WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 3 
                THEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::timestamp
            ELSE DATE_TRUNC('month', CURRENT_DATE)::timestamp
        END AS actual_date
),
interregional_deals AS (
    SELECT 
        d.date_deal_findep,
        d.city_name,
        d.rieltor_name, 
        d.rieltor_id,
        e.date_employment 
    FROM reports."532_187_interregional_commissions" AS d
    JOIN dates_cte AS dt ON TRUE
    JOIN hr_new.employees AS e 
        ON d.rieltor_id = e.employee_id
        AND e.period = dt.actual_date
    JOIN hr_new.cities AS c
    ON e.city_name = c.city_name 
    WHERE d.date_deal_findep >= dt.actual_date
      AND d.date_deal_findep < (dt.actual_date + INTERVAL '1 month')
    AND e.employee_type = 'Специалист отдела продаж'
    AND d.msd_rieltor_result = 'Риэлтор'
    AND LOWER(d.employee_group_0) = 'Нет'
    AND e.employee_status_priority = True
    AND
    (
        (   -- newbi
            d.deal_status = 'Закрыта (успех)'
            AND d.city_name IS NOT NULL
            AND d.deal_sub_type NOT IN ('Общий')
            AND e.department_name IN (  'Департамент межрегиональных сделок',
                                        'Департамент новостроек',
                                        'Департамент продаж',
                                        'Отдел загородной недвижимости',
                                        'Отдел коммерческой недвижимости',
                                        'Отдел межрегиональных и международных сделок',
                                        'Отдел новостроек',
                                        'Отдел продаж')
            AND d.mortage_ticket_type IN (  'Новостройки',
                                            'Покупка вторичная',
                                            'Покупка гаражи',
                                            'Покупка загородной',
                                            'Покупка коммерческой',
                                            'Продажа вторичная',
                                            'Продажа гаражи',
                                            'Продажа загородной') 
            AND d.revenue_type IN (
                'Комиссия (покупатель / наниматель)',
                'Комиссия (продавец / наймодатель)',
                'Комиссия (услуга)')
        )
        OR
        (   -- space
            -- для всех городов, даже NULL
            d.deal_status = 'Закрыта'
            AND e.department_name IN (  'Департамент коммерческой недвижимости', 
                                        'Департамент межрегиональных сделок', 
                                        'Департамент новостроек', 
                                        'Департамент продаж', 
                                        'Отдел коммерческой недвижимости', 
                                        'Отдел межрегиональных и международных сделок', 
                                        'Отдел продаж')           
            AND d.mortage_ticket_type IN (  'Покупка',
                                            'Продажа')
            AND d.revenue_type IN ('Сделка')
        )
    )
SELECT count(*)
FROM deals;