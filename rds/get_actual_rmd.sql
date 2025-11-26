CREATE OR REPLACE FUNCTION rmd_new.get_rmd_slice(p_date_slice date DEFAULT NULL)
RETURNS TABLE (
	date_slice date,
    city_name text,
    hrm_id int,
    hrm_name text,
    hsd_id int,
    hsd_name text,
    msd_id int,
    msd_name text,
    rieltor_id int,
    rieltor_name text,
    country_house boolean,
    secondary_apartment boolean,
    commercial boolean,
    new_building boolean,
    other_income boolean,
   	experience_ten_days int,
	old_experience_ten_days int,
	experience text,
	old_experience text
)
LANGUAGE plpgsql
AS $$
DECLARE
    actual_date date;
BEGIN
    -- Если дата передана, используем её, иначе CURRENT_DATE
    actual_date := COALESCE(p_date_slice, CURRENT_DATE);

    RETURN QUERY
    WITH dates_cte AS (
        SELECT
            CASE
                WHEN EXTRACT(DAY FROM actual_date) <= 3 
                    THEN (DATE_TRUNC('month', actual_date) - INTERVAL '1 month')::date
                ELSE DATE_TRUNC('month', actual_date)::date
            END AS actual_date
    ),
    filtred_rieltors AS (
        SELECT 
            dt.actual_date AS date_slice,
            e.city_name,
            e.hrm_id,
			e.hrm_name,
			e.hsd_id,
            e.hsd_name,
			e.msd_id,
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
			e.hrm_id,
			e.hrm_name,
			e.hsd_id,
            e.hsd_name,
			e.msd_id,
            e.msd_name,
            e.rieltor_id,
            e.rieltor_name,
            e.date_employment,
            e.experience_ten_days,
            e.old_experience_ten_days,
            CASE
                WHEN e.experience_ten_days BETWEEN 0 AND 3 THEN '0_3'
                WHEN e.experience_ten_days BETWEEN 4 AND 6 THEN '3_6'
                WHEN e.experience_ten_days >= 7 THEN '6_plus'
            END AS experience,
            CASE
                WHEN e.old_experience_ten_days BETWEEN 0 AND 3 THEN '0_3'
                WHEN e.old_experience_ten_days BETWEEN 4 AND 6 THEN '3_6'
                WHEN e.old_experience_ten_days >= 7 THEN '6_plus'
            END AS old_experience
        FROM filtred_rieltors AS e
    ),
    deals AS (
        SELECT
            d.date_deal_findep as deal_date,
            d.city_name as deal_city_name,
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
            d.date_close_month as deal_date,
            d.city_name as deal_city_name,
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
		DATE_TRUNC('month', r.date_slice)::date,
		r.city_name::text,
	    r.hrm_id::int,
	    r.hrm_name::text,
	    r.hsd_id::int,
	    r.hsd_name::text,
	    r.msd_id::int,
	    r.msd_name::text,
	    r.rieltor_id::int,
	    r.rieltor_name::text,
	    BOOL_OR(d.country_house)::boolean,
	    BOOL_OR(d.secondary_apartment)::boolean,
	    BOOL_OR(d.commercial)::boolean,
	    BOOL_OR(d.new_building)::boolean,
	    BOOL_OR(d.other_income)::boolean,
	    r.experience_ten_days::int,
	    r.old_experience_ten_days::int,
	    r.experience,
	    r.old_experience
    FROM general_deals AS d
    JOIN rieltors AS r ON d.rieltor_id = r.rieltor_id
    WHERE d.country_house OR d.secondary_apartment OR d.commercial OR d.new_building OR d.other_income
	GROUP BY 	r.city_name::text,
				r.date_slice,
			    r.hrm_id,
			    r.hrm_name,
			    r.hsd_id,
			    r.hsd_name,
			    r.msd_id,
			    r.msd_name,
			    r.rieltor_id,
			    r.rieltor_name,
			    r.experience_ten_days,
			    r.old_experience_ten_days,
			    r.experience,
			    r.old_experience;
END;
$$;