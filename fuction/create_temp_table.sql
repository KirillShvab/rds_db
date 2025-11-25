DROP TABLE IF EXISTS rmd_new.rieltors_experience_slice;

CREATE TABLE rmd_new.rieltors_experience_slice (
    deal_city_name 				text,
	rieltor_city_name			text,
    hrm_id                      int,
    hrm_name                    text,
    hsd_id                      int,
    hsd_name                    text,
    msd_id                      int,
    msd_name                    text,
    rieltor_id                  int,
    rieltor_name                text,

    country_house               boolean,
    secondary_apartment         boolean,
    commercial                  boolean,
    new_building                boolean,
    other_income                boolean,

    experience_ten_days         int,
    old_experience_ten_days     int,

    experience	                text,
    old_experience	            text

    
);