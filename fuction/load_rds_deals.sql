CREATE OR REPLACE PROCEDURE rmd_new.load_rieltors_experience()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO rmd_new.rieltors_experience_slice
    SELECT *
    FROM rmd_new.get_rieltors_experience_slice();
END;
$$;