CREATE OR REPLACE FUNCTION get_rieltors_experience_slice()
RETURNS TABLE (
    city_name text,
    hsd_name text,
    msd_name text,
    rieltor_name text,
    experience_ten_days int,
    old_experience_ten_days int,
    experience int,
    old_experience int,
    experience_0_3 int,
    experience_3_6 int,
    experience_6_plus int,
    old_experience_0_3 int,
    old_experience_3_6 int,
    old_experience_6_plus int
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
    ),
    general_deals AS (
        SELECT * FROM deals
        UNION ALL
        SELECT * FROM interregional_deals
    )
    SELECT
        d.city_name,
        r.hsd_name,
        r.msd_name,
        r.rieltor_name,
        SUM(r.experience_ten_days),
        SUM(r.old_experience_ten_days),
        COUNT(r.experience),
        COUNT(r.old_experience),
        COUNT(CASE WHEN r.experience = 'experience_0_3' THEN 1 END),
        COUNT(CASE WHEN r.experience = 'experience_3_6' THEN 1 END),
        COUNT(CASE WHEN r.experience = 'experience_6_plus' THEN 1 END),
        COUNT(CASE WHEN r.old_experience = 'experience_0_3' THEN 1 END),
        COUNT(CASE WHEN r.old_experience = 'experience_3_6' THEN 1 END),
        COUNT(CASE WHEN r.old_experience = 'experience_6_plus' THEN 1 END)
    FROM general_deals AS d
    JOIN rieltors AS r ON d.rieltor_id = r.rieltor_id
    WHERE d.country_house OR d.secondary_apartment OR d.commercial OR d.new_building OR d.other_income
    GROUP BY d.city_name, r.hsd_name, r.msd_name, r.rieltor_name;

END;
$$;