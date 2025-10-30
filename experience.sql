/*
Определяет дату среза: начало текущего месяца, или предыдущего месяца, если сегодня первые 3 дня месяца.
*/
WITH dates_cte AS (
    SELECT
        CASE
            WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 3 
                THEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::timestamp
            ELSE DATE_TRUNC('month', CURRENT_DATE)::timestamp
        END AS actual_date
),
/*
 rieltors формирует список активных риэлторов на текущий отчетный месяц с метриками опыта.
    - Добавляются метрики опыта:
        * experience_metric — общий показатель опыта из таблицы сотрудников.
        * old_experience_metric — вычисленный опыт в месяцах на дату среза, с бонусом +1, если день трудоустройства ≤ 10.
 * */
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
/*
    Формирует сделки риэлторов по дате среза с булевыми флагами по типу объекта 
    (гараж, загородная, вторичная квартира, коммерческая, новостройка) 
    для сотрудников отдела продаж из выбранных подразделений
*/
deals AS (
    SELECT
        d.date_deal_findep,
        d.city_name,
        d.rieltor_id,
		CASE WHEN object_class = 'Гараж' THEN TRUE ELSE FALSE END AS garage,
		CASE WHEN object_class = 'Загородная' THEN TRUE ELSE FALSE END AS country_house,
		CASE WHEN object_class IN ('Вторичная', 'Квартира') THEN TRUE ELSE FALSE END AS secondary_apartment,
		CASE WHEN object_class = 'Коммерческая' THEN TRUE ELSE FALSE END AS commercial,
		CASE WHEN object_class = 'Новостройка' THEN TRUE ELSE FALSE END AS new_building
	FROM reports."278_6_deal" AS d
    JOIN dates_cte AS dt ON TRUE
    JOIN hr_new.employees AS e
        ON d.rieltor_id = e.employee_id
        AND e.period = dt.actual_date
    JOIN hr_new.cities AS c
    ON e.city_name = c.city_name 
    WHERE  d.date_deal_findep >= dt.actual_date
      AND d.date_deal_findep < (dt.actual_date + INTERVAL '1 month')
      AND d.msd_rieltor_result = 'Риэлтор'
      AND LOWER(d.employee_group_0) = 'нет'
      AND e.employee_status_priority = TRUE
      AND LOWER(d.deal_type_sell_buyer) IN ('покупка', 'продажа') 
      AND e.employee_type = 'Специалист отдела продаж'
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
),
/*
    Формирует межрегиональные сделки риэлторов по дате закрытия месяца с булевыми флагами по типу объекта 
    (гараж, загородная, вторичная квартира, коммерческая, новостройка)
    для сотрудников отдела продаж с фильтром по статусу сделки, типу комиссии и подразделению.
*/
interregional_deals AS (
    SELECT 
        d.date_close_month,
        d.city_name,
        d.rieltor_id,
        CASE WHEN object_class = 'Гараж' THEN TRUE ELSE FALSE END AS garage,
		CASE WHEN object_class = 'Загородная' THEN TRUE ELSE FALSE END AS country_house,
		CASE WHEN object_class IN ('Вторичная', 'Квартира') THEN TRUE ELSE FALSE END AS secondary_apartment,
		CASE WHEN object_class = 'Коммерческая' THEN TRUE ELSE FALSE END AS commercial,
		CASE WHEN object_class = 'Новостройка' THEN TRUE ELSE FALSE END AS new_building
    FROM reports."532_187_interregional_commissions" AS d
    JOIN dates_cte AS dt ON TRUE
    JOIN hr_new.employees AS e 
        ON d.rieltor_id = e.employee_id
        AND e.period = dt.actual_date
    JOIN hr_new.cities AS c
    ON e.city_name = c.city_name 
    WHERE d.date_close_month >= dt.actual_date 
    AND d.date_close_month < (dt.actual_date + INTERVAL '1 month')
    AND e.employee_type = 'Специалист отдела продаж'
    AND d.msd_rieltor_result = 'Риэлтор'
    AND LOWER(d.employee_group_0) = 'Нет'
    AND e.employee_status_priority = True
    AND
    (
        (   d.kosmos = 0
            AND d.deal_status = 'Закрыта (успех)'
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
            AND d.mortgage_ticket_type IN (  'Новостройки',
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
        (   d.kosmos = 1
            AND d.deal_status = 'Закрыта'
            AND e.department_name IN (  'Департамент коммерческой недвижимости', 
                                        'Департамент межрегиональных сделок', 
                                        'Департамент новостроек', 
                                        'Департамент продаж', 
                                        'Отдел коммерческой недвижимости', 
                                        'Отдел межрегиональных и международных сделок', 
                                        'Отдел продаж')           
            AND d.mortgage_ticket_type IN (  'Покупка',
                                            'Продажа')
            AND d.revenue_type IN ('Сделка')
        )
    )
),
/*
Объединяет все сделки риэлторов из CTE deals и interregional_deals
в единый набор с булевыми флагами по типу объекта и датой сделки.
 */
general_deals as (
    select  d.date_deal_findep AS deal_date,
            d.city_name,
            d.rieltor_id,
            d.garage,                          		
		    d.country_house,            		
		    d.secondary_apartment,       
		    d.commercial,                  		
		    d.new_building AS new_building              		
    from deals AS d
    UNION ALL
    select  di.date_close_month AS deal_date,
            di.city_name,
            di.rieltor_id,
            di.garage,                          		
		    di.country_house,            		
		    di.secondary_apartment,       
		    di.commercial,                  		
		    di.new_building AS new_building              		
    from interregional_deals AS di
)
SELECT
    d.city_name,
    r.hsd_name,
    r.msd_name,
    r.rieltor_name,
    r.experience_metric,
    r.old_experience_metric,
    d.garage AS garage,                          		-- гараж  
    d.country_house AS country_house,            		-- загородная недвижимость  
    d.secondary_apartment AS secondary_apartment,       -- квартира + вторичная
    d.commercial AS commercial,                  		-- коммерческая недвижимость  
    d.new_building AS new_building              		-- новостройка  
FROM general_deals AS d
JOIN rieltors AS r
    ON r.rieltor_id = d.rieltor_id
WHERE 
 d.garage OR d.country_house OR d.secondary_apartment OR d.commercial OR d.new_building
LIMIT 100;
