CREATE OR REPLACE PROCEDURE rmd_new.create_or_truncate_rieltors_experience_slice()
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'rmd_new' 
          AND table_name = 'rieltors_experience_slice'
    ) THEN
        TRUNCATE TABLE rmd_new.rieltors_experience_slice;
    ELSE
        CREATE TABLE rmd_new.rieltors_experience_slice (
            id                        int,
            deal_city_name            text,
            rieltor_city_name         text,
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
    END IF;
END;
$$;