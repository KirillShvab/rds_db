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
        * experience_ten_days — общий показатель опыта из таблицы сотрудников.
        * old_experience_ten_days — вычисленный опыт в месяцах на дату среза, с бонусом +1, если день трудоустройства ≤ 10.
 */
filtred_rieltors AS (
    SELECT 
        dt.actual_date AS date_slice,
        e.city_name,
        e.hsd_name,
        e.msd_name,
        e.employee_name AS rieltor_name,
        e.employee_id AS rieltor_id,
        e.date_employment,
        e.experience_month AS experience_ten_days,
        ((EXTRACT(YEAR FROM dt.actual_date) - EXTRACT(YEAR FROM e.date_employment)) * 12
              + (EXTRACT(MONTH FROM dt.actual_date) - EXTRACT(MONTH FROM e.date_employment))
              + CASE WHEN EXTRACT(DAY FROM e.date_employment) <= 10 THEN 1 ELSE 0 END
            )::int AS old_experience_ten_days        
    FROM hr_new.employees AS e
    JOIN dates_cte AS dt ON TRUE
    WHERE
        e.period = dt.actual_date
        -- AND e.employee_work_status IN ('В ежегодном отпуске', 'В работе', 'Приостановить прием заявок') -- сделка есть а человек на больничном
        -- AND e.employee_status = 'Активен'  -- проблемная зона, не всегда актуальные статусы
        AND e.employee_type = 'Специалист отдела продаж'
        AND e.employee_work_type = 'Риэлтор'
        AND e.employee_status_priority = TRUE
        AND e.department_name IN ( 'Отдел новостроек',
                                   'Отдел продаж',
                                   'Департамент межрегиональных сделок',
                                   'Департамент новостроек',
                                   'Департамент продаж',
                                   'Отдел загородной недвижимости',
                                   'Отдел коммерческой недвижимости',
                                   'Отдел межрегиональных и международных сделок')
),
rieltors AS (
	SELECT  
        e.date_slice,
        e.city_name,
        e.hsd_name,
        e.msd_name,
        e.rieltor_name,
        e.rieltor_id,
        e.date_employment,
        e.experience_ten_days,
		e.old_experience_ten_days,
		CASE
            WHEN e.experience_ten_days BETWEEN 0 AND 3 THEN 'experience_0_3'
            WHEN e.experience_ten_days BETWEEN 4 AND 6 THEN 'experience_3_6'
            WHEN e.experience_ten_days >= 7 THEN 'experience_6_plus'
        END AS experience,
        CASE
            WHEN e.old_experience_ten_days BETWEEN 0 AND 3 THEN 'experience_0_3'
            WHEN e.old_experience_ten_days BETWEEN 4 AND 6 THEN 'experience_3_6'
            WHEN e.old_experience_ten_days >= 7 THEN 'experience_6_plus'
        END AS old_experience
	FROM filtred_rieltors AS e
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
		CASE WHEN object_class = 'Загородная' THEN TRUE ELSE FALSE END AS country_house,
		CASE WHEN object_class IN ('Вторичная', 'Квартира') THEN TRUE ELSE FALSE END AS secondary_apartment,
		CASE WHEN object_class IN ('Новостройка','Новостройки') THEN TRUE ELSE FALSE END AS new_building,
		CASE WHEN object_class = 'Коммерческая' THEN TRUE ELSE FALSE END AS commercial,
		CASE WHEN object_class = 'Прочие поступления' THEN TRUE ELSE FALSE END AS other_income,
        d.scripts_indicator
	FROM reports."278_6_deal" AS d
    JOIN dates_cte AS dt ON TRUE
    WHERE d.date_deal_findep >= dt.actual_date
      AND d.date_deal_findep < (dt.actual_date + INTERVAL '1 month')
      AND LOWER(d.employee_group_0) = 'нет'
      AND LOWER(d.deal_type_sell_buyer) IN ('покупка', 'продажа') 
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
		CASE WHEN object_class = 'Загородная' THEN TRUE ELSE FALSE END AS country_house,
		CASE WHEN object_class IN ('Вторичная', 'Квартира') THEN TRUE ELSE FALSE END AS secondary_apartment,
		CASE WHEN object_class = 'Коммерческая' THEN TRUE ELSE FALSE END AS commercial,
		CASE WHEN object_class IN ('Новостройка','Новостройки') THEN TRUE ELSE FALSE END AS new_building,
		CASE WHEN object_class = 'Прочие поступления' THEN TRUE ELSE FALSE END AS other_income,
        d.scripts_indicator
    FROM reports."532_187_interregional_commissions" AS d
    JOIN dates_cte AS dt ON TRUE
    WHERE d.date_close_month >= dt.actual_date 
    AND d.date_close_month < (dt.actual_date + INTERVAL '1 month')
    AND LOWER(d.employee_group_0) = 'нет'
    AND
    (
        (   d.kosmos = 0
            AND d.deal_status = 'Закрыта (успех)'
            AND d.deal_sub_type NOT IN ('Общий')
            AND d.mortgage_ticket_type IN ( 'Новостройки',
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
            AND LOWER(d.mortgage_ticket_type) IN ('покупка', 'продажа')
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
		    d.country_house,            		
		    d.secondary_apartment,       
		    d.commercial,                  		
		    d.new_building AS new_building,
		    d.other_income,
            d.scripts_indicator
    from deals AS d
    UNION ALL
    select  di.date_close_month AS deal_date,
            di.city_name,
            di.rieltor_id,
		    di.country_house,            		
		    di.secondary_apartment,       
		    di.commercial,                  		
		    di.new_building AS new_building,
		    di.other_income,
            di.scripts_indicator
    from interregional_deals AS di
)
SELECT
	d.city_name,
    r.hsd_name,
    r.msd_name,
    r.rieltor_name,
    SUM(r.experience_ten_days) AS experience_ten_days,
    SUM(r.old_experience_ten_days) AS old_experience_ten_days,
    COUNT(r.experience) AS experience,
    COUNT(r.old_experience) AS old_experience,
    COUNT(CASE WHEN r.experience = 'experience_0_3' THEN 1 ELSE NULL END) AS experience_0_3,
    COUNT(CASE WHEN r.experience = 'experience_3_6' THEN 1 ELSE NULL END) AS experience_3_6,
    COUNT(CASE WHEN r.experience = 'experience_6_plus' THEN 1 ELSE NULL END) AS experience_6_plus,
    COUNT(CASE WHEN r.old_experience = 'experience_0_3' THEN 1 ELSE NULL END) AS old_experience_0_3,
    COUNT(CASE WHEN r.old_experience = 'experience_3_6' THEN 1 ELSE NULL END) AS old_experience_3_6,
    COUNT(CASE WHEN r.old_experience = 'experience_6_plus' THEN 1 ELSE NULL END) AS old_experience_6_plus
FROM general_deals AS d
JOIN rieltors AS r 
        ON d.rieltor_id = r.rieltor_id
WHERE 
 ( d.country_house OR d.secondary_apartment OR d.commercial OR d.new_building OR  d.other_income )
GROUP BY d.city_name, r.hsd_name, r.msd_name, r.rieltor_name
