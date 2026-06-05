-- Pharmacy closures 2019 vs 2024
-- Compares two DOHMH permit snapshots to identify pharmacies that closed
-- between the two periods, broken out by pharmacy type (chain vs independent)
-- Registration number + coordinates used as dual key to avoid false matches
-- from relocated or re-licensed pharmacies
-- Hadeer Eid, Bureau of Mental Health, DOHMH Pipeline Fellowship


WITH pharmacies_2019 AS (
    SELECT
        REGNO as reg_no,
        LEG_NAME as pharmacy_name,
        ADDRESS_MODIFIED as address,
        BORO_CODE as borough,
        CommunityDistrict as community_district,
        CD_CAT_DESC as category_desc,
        CASE
            WHEN CD_CAT_DESC IN ('Large chain', 'Small chain') THEN 'chain'
            WHEN CD_CAT_DESC = 'Community pharmacy' THEN 'independent'
            ELSE 'other'
        END as pharmacy_type,
        ROUND(CAST(Latitude AS NUMERIC), 4) as lat,
        ROUND(CAST(Longitude AS NUMERIC), 4) as lon
    FROM dohmh_pharmacies_2019
    WHERE ACTIVE = 'T'
        AND NYC_INDICATOR = 'NYC'
        AND REGNO IS NOT NULL
        AND Latitude IS NOT NULL
        AND Longitude IS NOT NULL
        AND PH_TYPE = 17  -- pharmacy only, excludes wholesalers/manufacturers
),

pharmacies_2024 AS (
    SELECT
        REGNO as reg_no,
        ROUND(CAST(Latitude AS NUMERIC), 4) as lat,
        ROUND(CAST(Longitude AS NUMERIC), 4) as lon
    FROM dohmh_pharmacies_2024
    WHERE ACTIVE = 'T'
        AND NYC_INDICATOR = 'NYC'
        AND REGNO IS NOT NULL
        AND Latitude IS NOT NULL
        AND Longitude IS NOT NULL
        AND PH_TYPE = 17
),

closures AS (
    SELECT
        p19.reg_no,
        p19.pharmacy_name,
        p19.address,
        p19.borough,
        p19.community_district,
        p19.category_desc,
        p19.pharmacy_type,
        p19.lat,
        p19.lon,
        CASE WHEN p24.reg_no IS NULL THEN 'closed' ELSE 'open' END as status_2024
    FROM pharmacies_2019 p19
    LEFT JOIN pharmacies_2024 p24
        ON p19.reg_no = p24.reg_no
        AND p19.lat = p24.lat
        AND p19.lon = p24.lon
),

confirmed_closures AS (
    SELECT *
    FROM closures
    WHERE status_2024 = 'closed'
        AND pharmacy_type IN ('chain', 'independent')
),

baseline_counts AS (
    SELECT borough, pharmacy_type, COUNT(*) as total_2019
    FROM pharmacies_2019
    WHERE pharmacy_type IN ('chain', 'independent')
    GROUP BY borough, pharmacy_type
),

closure_summary AS (
    SELECT
        borough,
        pharmacy_type,
        COUNT(*) as closures,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY borough), 1) as pct_of_borough_closures
    FROM confirmed_closures
    GROUP BY borough, pharmacy_type
)

SELECT
    cs.borough,
    cs.pharmacy_type,
    cs.closures,
    cs.pct_of_borough_closures,
    bc.total_2019,
    ROUND(cs.closures * 100.0 / bc.total_2019, 1) as closure_rate_pct
FROM closure_summary cs
JOIN baseline_counts bc
    ON cs.borough = bc.borough
    AND cs.pharmacy_type = bc.pharmacy_type
ORDER BY cs.borough, cs.pharmacy_type;


-- community district breakdown for spatial export (ArcGIS input)
SELECT
    borough,
    community_district,
    pharmacy_type,
    COUNT(*) as closures,
    AVG(lat) as centroid_lat,
    AVG(lon) as centroid_lon
FROM confirmed_closures
GROUP BY borough, community_district, pharmacy_type
ORDER BY closures DESC;
