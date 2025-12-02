-- Sample Athena query:
-- Weekly classification of service units by number of "pains"
-- (signal quality and throughput conditions per band).
-- NOTE: Schema, table and column names are anonymized placeholders.


WITH
-- ===== Q1: Signal quality condition =====
q1 AS (
  WITH t AS (
    SELECT
      CAST(EXTRACT(week FROM CAST(date_parse(event_date, '%Y-%m-%d') AS date)) AS INTEGER) AS week_number,
      service_unit_id,
      device_id,
      TRY_CAST(average_signal AS DOUBLE) AS signal_value
    FROM "analytics_db"."device_service_quality"
    WHERE connection_type <> 'WIRED'
      AND NOT REGEXP_LIKE(device_type, '(?i)(SPECIAL1|SPECIAL2)')
  ),
  mins AS (
    SELECT
      week_number,
      service_unit_id,
      device_id,
      MIN(signal_value) AS min_week_signal
    FROM t
    GROUP BY 1, 2, 3
  )
  SELECT
    week_number,
    service_unit_id,
    CASE
      WHEN SUM(CASE WHEN min_week_signal < -55 THEN 1 ELSE 0 END) >= 6
        THEN 'PAIN'
      ELSE 'NO_PAIN'
    END AS is_signal_pain
  FROM mins
  GROUP BY 1, 2
),

-- ===== Q2: Throughput condition on band A =====
q_band_a AS (
  WITH t AS (
    SELECT
      CAST(EXTRACT(week FROM CAST(date_parse(event_date, '%Y-%m-%d') AS date)) AS INTEGER) AS week_number,
      service_unit_id,
      device_id,
      TRY_CAST(average_downlink_rate AS DOUBLE) AS downlink_rate
    FROM "analytics_db"."device_service_quality"
    WHERE connection_band = 'BAND_A'
      AND NOT REGEXP_LIKE(device_type, '(?i)(SPECIAL1|SPECIAL2)')
  ),
  mins AS (
    SELECT
      week_number,
      service_unit_id,
      device_id,
      MIN(downlink_rate) AS min_week_downlink_rate
    FROM t
    GROUP BY 1, 2, 3
  ),
  agg AS (
    SELECT
      week_number,
      service_unit_id,
      SUM(CASE WHEN min_week_downlink_rate < 30 THEN 1 ELSE 0 END) AS num_devices_below_threshold
    FROM mins
    GROUP BY 1, 2
  )
  SELECT
    week_number,
    service_unit_id,
    CASE
      WHEN num_devices_below_threshold >= 6
        THEN 'PAIN'
      ELSE 'NO_PAIN'
    END AS is_band_a_pain
  FROM agg
),

-- ===== Q3: Throughput condition on band B =====
q_band_b AS (
  WITH t AS (
    SELECT
      CAST(EXTRACT(week FROM CAST(date_parse(event_date, '%Y-%m-%d') AS date)) AS INTEGER) AS week_number,
      service_unit_id,
      device_id,
      TRY_CAST(average_downlink_rate AS DOUBLE) AS downlink_rate
    FROM "analytics_db"."device_service_quality"
    WHERE connection_band = 'BAND_B'
      AND NOT REGEXP_LIKE(device_type, '(?i)(SPECIAL1|SPECIAL2)')
  ),
  mins AS (
    SELECT
      week_number,
      service_unit_id,
      device_id,
      MIN(downlink_rate) AS min_week_downlink_rate
    FROM t
    GROUP BY 1, 2, 3
  ),
  agg AS (
    SELECT
      week_number,
      service_unit_id,
      SUM(CASE WHEN min_week_downlink_rate < 300 THEN 1 ELSE 0 END) AS num_devices_below_threshold
    FROM mins
    GROUP BY 1, 2
  )
  SELECT
    week_number,
    service_unit_id,
    CASE
      WHEN num_devices_below_threshold >= 6
        THEN 'PAIN'
      ELSE 'NO_PAIN'
    END AS is_band_b_pain
  FROM agg
),

-- ===== Unified keys =====
keys AS (
  SELECT week_number, service_unit_id FROM q1
  UNION
  SELECT week_number, service_unit_id FROM q_band_a
  UNION
  SELECT week_number, service_unit_id FROM q_band_b
),

-- ===== Base table per service unit =====
base AS (
  SELECT
    k.week_number,
    k.service_unit_id,
    COALESCE(q1.is_signal_pain, 'NO_PAIN')    AS signal_pain,
    COALESCE(q_band_a.is_band_a_pain, 'NO_PAIN') AS band_a_pain,
    COALESCE(q_band_b.is_band_b_pain, 'NO_PAIN') AS band_b_pain
  FROM keys k
  LEFT JOIN q1       ON q1.week_number       = k.week_number AND q1.service_unit_id       = k.service_unit_id
  LEFT JOIN q_band_a ON q_band_a.week_number = k.week_number AND q_band_a.service_unit_id = k.service_unit_id
  LEFT JOIN q_band_b ON q_band_b.week_number = k.week_number AND q_band_b.service_unit_id = k.service_unit_id
),

-- ===== Count of pains per service unit =====
pain_count AS (
  SELECT
    week_number,
    (
      (CASE WHEN signal_pain = 'PAIN' THEN 1 ELSE 0 END) +
      (CASE WHEN band_a_pain = 'PAIN' THEN 1 ELSE 0 END) +
      (CASE WHEN band_b_pain = 'PAIN' THEN 1 ELSE 0 END)
    ) AS num_pains
  FROM base
)

-- ===== Final aggregation per week =====
SELECT
  week_number,
  SUM(CASE WHEN num_pains = 0 THEN 1 ELSE 0 END) AS units_with_0_pains,
  SUM(CASE WHEN num_pains = 1 THEN 1 ELSE 0 END) AS units_with_1_pain,
  SUM(CASE WHEN num_pains = 2 THEN 1 ELSE 0 END) AS units_with_2_pains,
  SUM(CASE WHEN num_pains = 3 THEN 1 ELSE 0 END) AS units_with_3_pains
FROM pain_count
GROUP BY week_number
ORDER BY week_number;
 