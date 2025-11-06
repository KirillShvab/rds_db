CREATE OR REPLACE FUNCTION get_rieltors_deals_slice()
RETURNS TABLE (
    deal_date                timestamp,
    city_name                text,
    hsd_name                 text,
    msd_name                 text,
    rieltor_name             text,
    rieltor_id               bigint,
    date_employment          date,
    experience_ten_days      int,
    old_experience_ten_days  int,
    experience               text,
    old_experience           text,
    country_house            boolean,
    secondary_apartment      boolean,
    commercial               boolean,
    new_building             boolean,
    other_income             boolean,
    scripts_indicator        boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH dates_cte AS (
        SELECT
            CASE
                WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 3 
                    THEN (DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month')::timestamp
                ELSE DATE_TRUNC('month', CURRENT_DATE)::timestamp
            END AS actual_date
    ),
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
            (
                (EXTRACT(YEAR FROM dt.actual_date) - EXTRACT(YEAR FROM e.date_employment)) * 12
                + (EXTRACT(MONTH FROM dt.actual_date) - EXTRACT(MONTH FROM e.date_employment))
                + CASE WHEN EXTRACT(DAY FROM e.date_employment) <= 10 THEN 1 ELSE 0 END
            )::int AS old_experience_ten_days
        FROM hr_new.employees AS e
        JOIN dates_cte AS dt ON TRUE
        WHERE
            e.period = dt.actual_date
            AND e.employee_type = 'Специалист отдела продаж'
            AND e.employee_work_type = 'Риэлтор'
            AND e.employee_status_priority = TRUE
            AND e.department_name IN (
                'Отдел новостроек',
                'Отдел продаж',
                'Департамент межрегиональных сделок',
                'Департамент новостроек',
                'Департамент продаж',
                'Отдел загородной недвижимости',
                'Отдел коммерческой недвижимости',
                'Отдел межрегиональных и международных сделок'
            )
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
    deals AS (
        SELECT
            d.date_deal_findep,
            d.city_name,
            d.rieltor_id,
            (object_class = 'Загородная') AS country_house,
            (object_class IN ('Вторичная', 'Квартира')) AS secondary_apartment,
            (object_class IN ('Новостройка','Новостройки')) AS new_building,
            (object_class = 'Коммерческая') AS commercial,
            (object_class = 'Прочие поступления') AS other_income,
            d.scripts_indicator
        FROM reports."278_6_deal" AS d
        JOIN dates_cte AS dt ON TRUE
        WHERE d.date_deal_findep >= dt.actual_date
          AND d.date_deal_findep < dt.actual_date + INTERVAL '1 month'
          AND LOWER(d.employee_group_0) = 'нет'
          AND LOWER(d.deal_type_sell_buyer) IN ('покупка', 'продажа') 
    ),
    interregional_deals AS (
        SELECT 
            d.date_close_month,
            d.city_name,
            d.rieltor_id,
            (object_class = 'Загородная') AS country_house,
            (object_class IN ('Вторичная', 'Квартира')) AS secondary_apartment,
            (object_class = 'Коммерческая') AS commercial,
            (object_class IN ('Новостройка','Новостройки')) AS new_building,
            (object_class = 'Прочие поступления') AS other_income,
            d.scripts_indicator
        FROM reports."532_187_interregional_commissions" AS d
        JOIN dates_cte AS dt ON TRUE
        WHERE d.date_close_month >= dt.actual_date 
          AND d.date_close_month < dt.actual_date + INTERVAL '1 month'
          AND LOWER(d.employee_group_0) = 'нет'
          AND (
                (d.kosmos = 0
                 AND d.deal_status = 'Закрыта (успех)'
                 AND d.deal_sub_type NOT IN ('Общий')
                 AND d.mortgage_ticket_type NOT ILIKE 'общее'
                 AND d.revenue_type ILIKE 'комиссия%')
                OR
                (d.kosmos = 1
                 AND d.deal_status = 'Закрыта'
                 AND LOWER(d.mortgage_ticket_type) IN ('покупка', 'продажа')
                 AND d.revenue_type = 'Сделка')
            )
    ),
    general_deals AS (
        SELECT  
            d.date_deal_findep AS deal_date,
            d.city_name,
            d.rieltor_id,
            d.country_house,
            d.secondary_apartment,
            d.commercial,
            d.new_building,
            d.other_income,
            d.scripts_indicator
        FROM deals AS d
        UNION ALL
        SELECT  
            di.date_close_month AS deal_date,
            di.city_name,
            di.rieltor_id,
            di.country_house,
            di.secondary_apartment,
            di.commercial,
            di.new_building,
            di.other_income,
            di.scripts_indicator
        FROM interregional_deals AS di
    )
    SELECT
        d.deal_date,
        d.city_name,
        r.hsd_name,
        r.msd_name,
        r.rieltor_name,
        r.rieltor_id,
        r.date_employment,
        r.experience_ten_days,
        r.old_experience_ten_days,
        r.experience,
        r.old_experience,
        d.country_house,
        d.secondary_apartment,
        d.commercial,
        d.new_building,
        d.other_income,
        d.scripts_indicator
    FROM general_deals AS d
    JOIN rieltors AS r ON d.rieltor_id = r.rieltor_id
    WHERE d.country_house 
       OR d.secondary_apartment 
       OR d.commercial 
       OR d.new_building 
       OR d.other_income;

END;
$$;