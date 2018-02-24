-- See tables
SELECT * FROM selim_application ORDER BY ID DESC;
SELECT * FROM selim_application_log ORDER BY log_id DESC ;
SELECT * FROM selim_application_conf;

-- Run procedures to create aritmetic operations and then launch calculator...
BEGIN
  application.i_Operations(pis_InsertUser => 'TEST_v3.0');
  dbms_lock.sleep(30);
  application.main(pis_ModifyUser => 'TEST_v3.0');
END;
/

-- See dbms_scheduler jobs
SELECT d.owner, d.job_name, d.job_type, d.job_action, d.start_date, d.repeat_interval,
       d.ENABLED, d.run_count, d.failure_count, d.retry_count,
       d.last_start_date, d.last_run_duration, d.comments, d.STATE, d.ENABLED
  FROM dba_scheduler_jobs d
 WHERE d.job_name IN ('SELIM_APPLICATION_JOB', 'SELIM_APPLICATION_INSERT_JOB');
