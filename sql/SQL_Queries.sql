/* ========================================================================================================================================
	Q1: Executive Scorecard - Core Operational and Clinical KPIs
		Extract the foundational hospital metrics to establish a performance baseline, calculating the total clinical encounters, 
		unique patient volume, overall 30-day readmission rate, and average length of stay (LOS). 
===========================================================================================================================================*/
SELECT 
	COUNT(encounter_id) AS total_encounters,
	COUNT(DISTINCT patient_nbr) AS total_unique_patients,
	SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) AS readmitted_within_30_days,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(*), 2) AS readmission_rate_pct,
	ROUND(AVG(time_in_hospital), 2) AS avg_stay_days
FROM diabetic_data;




/* ========================================================================================================================================
	Q2: Demographic Impact - Age-Group Risk Profiling
		Analyze the distribution of patient volume across different age brackets and calculate their 
		corresponding 30-day readmission rates to identify the most vulnerable demographic segments. 
========================================================================================================================================*/
SELECT
	age AS age_group,
	COUNT(encounter_id) AS total_patients,
	SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) AS readmitted_within_30_days,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS readmitted_rate_pct
FROM diabetic_data
GROUP BY age_group
ORDER BY total_patients DESC;




/* ========================================================================================================================================
	Q3: Medical Interventions - The Impact of Diabetes Medication
		Evaluate the correlation between prescribing diabetes medication and the 30-day readmission rate to 
		assess the effectiveness of standard pharmacological interventions.
========================================================================================================================================*/
SELECT 
	diabetesMed AS prescribed_diabetes_med,
	COUNT(encounter_id) AS total_patients,
	SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) AS readmitted_within_30_days,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS readmitted_rate_pct
    FROM diabetic_data
    GROUP BY diabetesMed;
    

/* ========================================================================================================================================
	Q4: Operational Bottlenecks - Discharge Destination Risk
		Calculate volume and 30-day readmission rates, identifying which discharge pathways carry the highest clinical risk.
========================================================================================================================================*/
SELECT 
	a.discharge_disposition_desc AS discharge_destination,
	COUNT(d.encounter_id) AS total_patients,
	SUM(CASE WHEN d.readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) AS readmitted_count,
	ROUND((SUM(CASE WHEN d.readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(d.encounter_id), 2) AS readmission_rate_pct
FROM diabetic_data d
INNER JOIN discharge_df a 
	ON d.discharge_disposition_id = a.discharge_disposition_id
GROUP BY a.discharge_disposition_desc
HAVING total_patients > 1000
ORDER BY total_patients DESC;




/* ========================================================================================================================================
	Q5: Admission Source Risk - Does Point of Entry Matter?
		Evaluate readmission rates based on the patient's point of entry (e.g., Emergency Room vs. Referrals) 
        to determine if acute admissions correlate with higher post-discharge failure rates.
========================================================================================================================================*/
SELECT
	a.admission_source_desc AS admission_source,
	COUNT(d.encounter_id) AS total_patients,
	ROUND((SUM(CASE WHEN d.readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(d.encounter_id), 2) AS readmission_rate_pct
FROM diabetic_data d
INNER JOIN admission_source_df a
	ON d.admission_source_id = a.admission_source_id
GROUP BY a.admission_source_desc
HAVING total_patients > 500
ORDER BY total_patients DESC;





/* ========================================================================================================================================
	Q6: Behavioral Patterns - The "Frequent Flyer" Impact
		Segment the patient population based on historical hospital utilization (new vs. returning patients) 
		to evaluate how prior inpatient visits compound the risk of 30-day readmissions.
========================================================================================================================================*/
SELECT
	CASE
		WHEN has_prior_inpatient = 0 THEN 'New Patients (0 prior visit)'
		ELSE 'Frequent Flyers (>0 prior visit)'
	END AS patient_segment,
	COUNT(encounter_id) AS total_patients,
	SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) AS readmitted_count,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(encounter_id), 2) AS readmission_rate_pct
FROM diabetic_data
GROUP BY patient_segment
ORDER BY readmission_rate_pct DESC;



/* ========================================================================================================================================
	Q7: Time & Risk - Length of Stay (LOS) vs Readmission Benchmark
		Group patient stays into logical clinical duration buckets (short, medium, long) to determine 
		if prolonged hospital stays correlate with elevated readmission penalties.
========================================================================================================================================*/
SELECT 
	CASE
		WHEN time_in_hospital BETWEEN 1 AND 4 THEN '1-4 Days stay'
		WHEN time_in_hospital BETWEEN 5 AND 8 THEN '5-8 Days stay'
		ELSE '9+ Days stay'
	END AS stay_time_group,
	COUNT(encounter_id) AS total_patients,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / count(encounter_id), 2) AS readmission_rate_pct
FROM diabetic_data
GROUP BY stay_time_group
ORDER BY stay_time_group;





/* ========================================================================================================================================
	Q8: Strategic Intervention - Medical Specialty Audit
		Evaluate clinical departments to identify the top three high-volume medical specialties (handling over 1,000 patient encounters) that 
		are currently operating above the baseline hospital readmission rate.
========================================================================================================================================*/
WITH hospital_avg AS (
	SELECT 
		ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(*), 2) AS overall_avg
	FROM diabetic_data
)
SELECT 
	medical_specialty,
	COUNT(encounter_id) AS total_patients,
	SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END) AS readmitted_count,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(encounter_id), 2) AS readmission_rate_pct
FROM diabetic_data
GROUP BY medical_specialty
HAVING total_patients > 1000
	AND readmission_rate_pct > (SELECT overall_avg FROM hospital_avg)
ORDER BY 
	readmission_rate_pct DESC 
	LIMIT 3;
    
    
    
/* ========================================================================================================================================
	Q9: Resource Allocation - The Cost of Clinical Complexity
		Develop a resource utilization matrix to compare the average consumption of clinical services (lab procedures, medications, and diagnoses) 
		across patient readmission outcomes, identifying if high-risk patients exhibit higher initial resource dependency.
========================================================================================================================================*/
SELECT 
	readmitted as readmission_status,
	COUNT(encounter_id) AS total_patients,
	ROUND(AVG(num_lab_procedures), 1) AS avg_lab_procedures,
	ROUND(AVG(num_medications), 1) AS avg_medications,
	ROUND(AVG(number_diagnoses), 1) AS avg_diagnoses
FROM diabetic_data
GROUP BY readmission_status
ORDER BY total_patients DESC;





/* ========================================================================================================================================
	Q10: Feature Engineering - The Clinical Severity Index
		Develop a custom clinical severity index by categorizing patients based on their total number of diagnoses, 
		and evaluate how this engineered metric correlates with 30-day readmission vulnerability.
========================================================================================================================================*/
SELECT 
	CASE 
		WHEN number_diagnoses < 5 THEN 'Low Severity (<5)'
		WHEN number_diagnoses BETWEEN 5 AND 8 THEN 'Medium Severity (5-8)'
		ELSE 'High Severity (>8)'
	END AS severity_score,
	COUNT(encounter_id) AS total_patients,
	ROUND((SUM(CASE WHEN readmitted = 'Within 30 Days' THEN 1 ELSE 0 END)*100.0) / COUNT(encounter_id), 2) AS readmission_rate_pct
FROM diabetic_data
GROUP BY severity_score
ORDER BY total_patients;