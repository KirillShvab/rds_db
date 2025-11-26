CREATE OR REPLACE PROCEDURE rmd_new.update_rmd_slice(p_date_slice date DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
	curent_date_slice date;
    actual_date date;
BEGIN
    -- Если дата передана, используем её, иначе CURRENT_DATE
    actual_date := COALESCE(p_date_slice, CURRENT_DATE);

    -- Определяем фактическую дату среза по правилам функции
    WITH dates_cte AS (
        SELECT
            CASE
                WHEN EXTRACT(DAY FROM actual_date) <= 3 
                    THEN (DATE_TRUNC('month', actual_date) - INTERVAL '1 month')::date
                ELSE DATE_TRUNC('month', actual_date)::date
            END AS actual_date
    )
    SELECT actual_date
    INTO curent_date_slice
    FROM dates_cte;

	-- Удаляем существующие записи за эту дату
	DELETE FROM rmd_new.rieltors_making_deals as all_rmd
    WHERE all_rmd.date_slice = curent_date_slice;

	-- Вставляем новые данные
	INSERT INTO rmd_new.rieltors_making_deals (
        date_slice, city_name, hrm_id, hrm_name,
        hsd_id, hsd_name, msd_id, msd_name,
        rieltor_id, rieltor_name,
        country_house, secondary_apartment, commercial, new_building, other_income,
        experience_ten_days, old_experience_ten_days, experience, old_experience
    )
	SELECT
	    date_slice, city_name, hrm_id, hrm_name,
	    hsd_id, hsd_name, msd_id, msd_name,
	    rieltor_id, rieltor_name,
	    country_house, secondary_apartment, commercial, new_building, other_income,
	    experience_ten_days, old_experience_ten_days, experience, old_experience
	FROM rmd_new.get_rmd_slice(curent_date_slice);

END;
$$;

call update_rmd_slice();
