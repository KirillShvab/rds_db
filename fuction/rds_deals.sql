CREATE OR REPLACE PROCEDURE rmd_new.rds_deals()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL rmd_new.create_or_truncate_rieltors_experience_slice();
    CALL rmd_new.load_rieltors_experience();
END;
$$;
