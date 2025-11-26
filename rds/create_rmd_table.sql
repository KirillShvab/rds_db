CREATE OR REPLACE PROCEDURE rmd_new.create_rmd_table()
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'rmd_new' 
          AND table_name = 'rieltors_making_deals'
    ) THEN
        CREATE TABLE rmd_new.rieltors_making_deals (
            id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
			date_slice 				  date,
            city_name         		  text,
            hrm_id                    int,
            hrm_name                  text,
            hsd_id                    int,
            hsd_name                  text,
            msd_id                    int,
            msd_name                  text,
            rieltor_id                int,
            rieltor_name              text,
            country_house             boolean,
            secondary_apartment       boolean,
            commercial                boolean,
            new_building              boolean,
            other_income              boolean,
            experience_ten_days       int,
            old_experience_ten_days   int,
            experience                text,
            old_experience            text
        );
		
		INSERT INTO rmd_new.rieltors_making_deals (	date_slice,
												    city_name,
												    hrm_id,
												    hrm_name,
												    hsd_id,
												    hsd_name,
												    msd_id,
												    msd_name,
												    rieltor_id,
												    rieltor_name,
												    country_house,
												    secondary_apartment,
												    commercial,
												    new_building,
												    other_income,
												    experience_ten_days,
												    old_experience_ten_days,
												    experience,
												    old_experience)
		SELECT *
		FROM rmd_new.get_rmd_slice();
    END IF;
	END;
$$;

call create_rmd_table();
